unit ULazarusWebServer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  fphttpserver, fpjson, jsonparser,
  UUserControlBiometria;

type
  { TAuthSyncRecord }
  TAuthSyncRecord = record
    UserName: string;
    FullName: string;
    UserLevel: string;
    LevelCode: Integer;
    Status: string;
    ClientIP: string;
    DeviceId: string;
    Timestamp: TDateTime;
  end;

  { TServerThread: Roda o TFPHttpServer em background sem travar o loop de eventos da interface LCL }
  TServerThread = class(TThread)
  private
    FServer: TFPHttpServer;
    FPort: Integer;
    procedure HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  protected
    procedure Execute; override;
  public
    constructor Create(APort: Integer);
    destructor Destroy; override;
    procedure StopServer;
  end;

  { TfrmBiometricServerLazarus }
  TfrmBiometricServerLazarus = class(TForm)
    pnlHeader: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    pnlStatus: TPanel;
    lblStatusAcesso: TLabel;
    lblUsuarioAutenticado: TLabel;
    lblIPPorta: TLabel;
    mmoLogs: TMemo;
    btnIniciarServidor: TButton;
    btnPararServidor: TButton;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnIniciarServidorClick(Sender: TObject);
    procedure btnPararServidorClick(Sender: TObject);

  private
    FServerThread: TServerThread;
    FCurrentSyncData: TAuthSyncRecord;

    procedure DoLiberarAcessoMainThread;
  public
    procedure IniciarServidor(const APorta: Integer = 8080);
    procedure PararServidor;
    procedure NotificarAutenticacao(const AUser, AFullName, ALevel: string; ALevelCode: Integer;
      const AStatus, AIP, ADeviceId: string);
  end;

var
  frmBiometricServerLazarus: TfrmBiometricServerLazarus;

implementation

{$R *.lfm}

{ TServerThread }

constructor TServerThread.Create(APort: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPort := APort;
  FServer := TFPHttpServer.Create(nil);
  FServer.Port := FPort;
  FServer.OnRequest := @HandleRequest;
  Resume;
end;

destructor TServerThread.Destroy;
begin
  StopServer;
  FServer.Free;
  inherited Destroy;
end;

procedure TServerThread.StopServer;
begin
  if Assigned(FServer) and FServer.Active then
    FServer.Active := False;
  Terminate;
end;

procedure TServerThread.Execute;
begin
  try
    FServer.Active := True;
  except
    on E: Exception do
      // Ignora encerramento forçado do socket
  end;
end;

procedure TServerThread.HandleRequest(Sender: TObject;
  var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
var
  RawJson: string;
  JsonData: TJSONData;
  UserExtracted, StatusExtracted, DeviceIdExtracted: string;
  FullName, UserLevel: string;
  LevelCode: Integer;
  U: TUsuario;
begin
  // 1. Interceptar a rota /biometria-sucesso
  if SameText(ARequest.PathInfo, '/biometria-sucesso') or SameText(ARequest.URL, '/biometria-sucesso') then
  begin
    RawJson := ARequest.Content;
    UserExtracted := 'mauricio';
    StatusExtracted := 'approved';
    DeviceIdExtracted := '';

    // Parsing do JSON recebido do Android
    try
      JsonData := GetJSON(RawJson);
      try
        if JsonData is TJSONObject then
        begin
          if TJSONObject(JsonData).Find('user') <> nil then
            UserExtracted := TJSONObject(JsonData).Get('user', 'mauricio');
          if TJSONObject(JsonData).Find('status') <> nil then
            StatusExtracted := TJSONObject(JsonData).Get('status', 'approved');
          if TJSONObject(JsonData).Find('device_id') <> nil then
            DeviceIdExtracted := TJSONObject(JsonData).Get('device_id', '');
        end;
      finally
        JsonData.Free;
      end;
    except
      // Se não for JSON estruturado, utiliza os padrões
    end;

    // Consulta e validação de perfil no UserControl
    FullName := UserExtracted;
    UserLevel := 'Operador';
    LevelCode := 2;

    if Assigned(GUserManager) then
    begin
      U := GUserManager.BuscarPorLogin(UserExtracted);
      if Assigned(U) then
      begin
        FullName := U.Nome;
        UserLevel := U.NivelToString;
        LevelCode := Ord(U.Nivel);
        U.UltimoAcesso := Now;
        if (U.DeviceId = '') and (DeviceIdExtracted <> '') then
          GUserManager.VincularDispositivo(U.Login, DeviceIdExtracted);
      end;
    end;

    if SameText(StatusExtracted, 'approved') then
    begin
      // Notifica a tela do Lazarus de forma síncrona/segura
      if Assigned(frmBiometricServerLazarus) then
        frmBiometricServerLazarus.NotificarAutenticacao(
          UserExtracted, FullName, UserLevel, LevelCode,
          StatusExtracted, ARequest.RemoteAddress, DeviceIdExtracted
        );

      // Resposta HTTP 200 OK com os dados do perfil do UserControl
      AResponse.Code := 200;
      AResponse.ContentType := 'application/json; charset=utf-8';
      AResponse.Content := Format(
        '{"code": 200, "result": "access_granted", "user": "%s", "nome": "%s", "nivel": "%s", "nivel_code": %d, "message": "Acesso autorizado com perfil %s!"}',
        [UserExtracted, FullName, UserLevel, LevelCode, UserLevel]
      );
    end
    else
    begin
      AResponse.Code := 403;
      AResponse.ContentType := 'application/json; charset=utf-8';
      AResponse.Content := '{"code": 403, "result": "denied", "message": "Biometria recusada pelo dispositivo."}';
    end;
  end
  else
  begin
    AResponse.Code := 404;
    AResponse.ContentType := 'text/plain; charset=utf-8';
    AResponse.Content := 'Rota nao encontrada. Use POST /biometria-sucesso';
  end;
end;

{ TfrmBiometricServerLazarus }

procedure TfrmBiometricServerLazarus.FormCreate(Sender: TObject);
begin
  IniciarServidor(8080);
end;

procedure TfrmBiometricServerLazarus.FormDestroy(Sender: TObject);
begin
  PararServidor;
end;

procedure TfrmBiometricServerLazarus.IniciarServidor(const APorta: Integer);
begin
  if FServerThread = nil then
  begin
    FServerThread := TServerThread.Create(APorta);
    lblIPPorta.Caption := Format('Servidor Ativo na Porta: %d (Aguardando Biometria Android...)', [APorta]);
    lblStatusAcesso.Caption := 'SISTEMA BLOQUEADO - AGUARDANDO BIOMETRIA';
    pnlStatus.Color := $002B2BD6; // Vermelho
    lblStatusAcesso.Font.Color := clWhite;

    mmoLogs.Lines.Add(Format('[%s] Servidor HTTP nativo FPC iniciado com sucesso na porta %d.', [TimeToStr(Now), APorta]));
    mmoLogs.Lines.Add('Aguardando conexoes em: POST http://<IP_DO_PC>:' + IntToStr(APorta) + '/biometria-sucesso');
  end;
end;

procedure TfrmBiometricServerLazarus.PararServidor;
begin
  if FServerThread <> nil then
  begin
    FServerThread.StopServer;
    FServerThread.WaitFor;
    FreeAndNil(FServerThread);
    lblIPPorta.Caption := 'Servidor Parado';
    mmoLogs.Lines.Add(Format('[%s] Servidor HTTP encerrado.', [TimeToStr(Now)]));
  end;
end;

procedure TfrmBiometricServerLazarus.btnIniciarServidorClick(Sender: TObject);
begin
  IniciarServidor(8080);
end;

procedure TfrmBiometricServerLazarus.btnPararServidorClick(Sender: TObject);
begin
  PararServidor;
end;

procedure TfrmBiometricServerLazarus.NotificarAutenticacao(const AUser, AFullName, ALevel: string; ALevelCode: Integer;
  const AStatus, AIP, ADeviceId: string);
begin
  FCurrentSyncData.UserName := AUser;
  FCurrentSyncData.FullName := AFullName;
  FCurrentSyncData.UserLevel := ALevel;
  FCurrentSyncData.LevelCode := ALevelCode;
  FCurrentSyncData.Status := AStatus;
  FCurrentSyncData.ClientIP := AIP;
  FCurrentSyncData.DeviceId := ADeviceId;
  FCurrentSyncData.Timestamp := Now;

  // Atualiza na Main Thread do Lazarus
  TThread.Queue(nil, @DoLiberarAcessoMainThread);
end;

procedure TfrmBiometricServerLazarus.DoLiberarAcessoMainThread;
begin
  pnlStatus.Color := $002E8B57; // Verde esmeralda (Liberado)
  lblStatusAcesso.Caption := Format('ACESSO LIBERADO: %s (%s)', [UpperCase(FCurrentSyncData.FullName), FCurrentSyncData.UserLevel]);
  lblStatusAcesso.Font.Color := clWhite;

  lblUsuarioAutenticado.Caption := Format('Login: %s | Nível: %s | IP: %s às %s', [
    FCurrentSyncData.UserName,
    FCurrentSyncData.UserLevel,
    FCurrentSyncData.ClientIP,
    TimeToStr(FCurrentSyncData.Timestamp)
  ]);

  mmoLogs.Lines.Add(Format(
    '>>> [%s] AUTENTICAÇÃO CONFIRMADA: Usuário "%s" (%s) autenticado pelo Android (IP: %s). Módulo VCL Liberado!',
    [DateTimeToStr(FCurrentSyncData.Timestamp), FCurrentSyncData.FullName, FCurrentSyncData.UserLevel, FCurrentSyncData.ClientIP]
  ));

  BringToFront;
end;

end.

