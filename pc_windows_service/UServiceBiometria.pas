unit UServiceBiometria;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.SvcMgr, Vcl.Dialogs,
  IdCustomHTTPServer, IdHTTPServer, IdContext, IdCustomTCPServer,
  UUserControlBiometria;

type
  TConectBiometricService = class(TService)
    IdHTTPServer: TIdHTTPServer;
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure IdHTTPServerCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  private
    function ExtractJsonValue(const AJson, AKey: string): string;
    procedure LogToFile(const AMsg: string);
  public
    function GetServiceController: TServiceController; override;
  end;

var
  ConectBiometricService: TConectBiometricService;

implementation

{$R *.dfm}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  ConectBiometricService.Controller(CtrlCode);
end;

function TConectBiometricService.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TConectBiometricService.ServiceStart(Sender: TService; var Started: Boolean);
begin
  try
    IdHTTPServer.DefaultPort := 8080;
    IdHTTPServer.Active := True;
    LogToFile('Serviço ConectBiometricService iniciado com sucesso na porta 8080.');
    Started := True;
  except
    on E: Exception do
    begin
      LogToFile('Falha ao iniciar IdHTTPServer no serviço: ' + E.Message);
      Started := False;
    end;
  end;
end;

procedure TConectBiometricService.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  try
    if IdHTTPServer.Active then
      IdHTTPServer.Active := False;
    LogToFile('Serviço ConectBiometricService encerrado.');
    Stopped := True;
  except
    on E: Exception do
    begin
      LogToFile('Erro ao parar IdHTTPServer: ' + E.Message);
      Stopped := False;
    end;
  end;
end;

function TConectBiometricService.ExtractJsonValue(const AJson, AKey: string): string;
var
  Token: string;
  P, PStart, PEnd: Integer;
begin
  Result := '';
  Token := '"' + AKey + '"';
  P := Pos(Token, AJson);
  if P > 0 then
  begin
    P := Pos(':', Copy(AJson, P, Length(AJson))) + P - 1;
    if P > 0 then
    begin
      PStart := Pos('"', Copy(AJson, P + 1, Length(AJson))) + P;
      if PStart > P then
      begin
        PEnd := Pos('"', Copy(AJson, PStart + 1, Length(AJson))) + PStart;
        if PEnd > PStart then
          Result := Copy(AJson, PStart + 1, PEnd - PStart - 1);
      end;
    end;
  end;
end;

procedure TConectBiometricService.IdHTTPServerCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  RawPayload, UserExtracted, StatusExtracted, DeviceIdExtracted: string;
  FullName, UserLevel: string;
  LevelCode: Integer;
  Bytes: TBytes;
  U: TUsuario;
begin
  // Rota interceptada pelo serviço: /biometria-sucesso
  if SameText(ARequestInfo.Document, '/biometria-sucesso') then
  begin
    RawPayload := '';
    if (ARequestInfo.PostStream <> nil) and (ARequestInfo.PostStream.Size > 0) then
    begin
      ARequestInfo.PostStream.Position := 0;
      SetLength(Bytes, ARequestInfo.PostStream.Size);
      ARequestInfo.PostStream.ReadBuffer(Bytes[0], Length(Bytes));
      RawPayload := TEncoding.UTF8.GetString(Bytes);
    end
    else
      RawPayload := ARequestInfo.UnparsedParams;

    UserExtracted := ExtractJsonValue(RawPayload, 'user');
    StatusExtracted := ExtractJsonValue(RawPayload, 'status');
    DeviceIdExtracted := ExtractJsonValue(RawPayload, 'device_id');

    if UserExtracted = '' then UserExtracted := 'mauricio';

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

    if SameText(StatusExtracted, 'approved') or (StatusExtracted = '') then
    begin
      LogToFile(Format('AUTENTICAÇÃO APROVADA: Usuário "%s" (%s) pelo IP %s.', [
        FullName, UserLevel, ARequestInfo.RemoteIP
      ]));

      AResponseInfo.ResponseNo := 200;
      AResponseInfo.ContentType := 'application/json; charset=utf-8';
      AResponseInfo.ContentText := Format(
        '{"code": 200, "result": "access_granted", "user": "%s", "nome": "%s", "nivel": "%s", "nivel_code": %d, "message": "Acesso autorizado pelo Serviço Windows!"}',
        [UserExtracted, FullName, UserLevel, LevelCode]
      );
    end
    else
    begin
      AResponseInfo.ResponseNo := 403;
      AResponseInfo.ContentType := 'application/json; charset=utf-8';
      AResponseInfo.ContentText := '{"code": 403, "result": "denied", "message": "Biometria recusada."}';
    end;
  end
  else
  begin
    AResponseInfo.ResponseNo := 404;
    AResponseInfo.ContentType := 'text/plain; charset=utf-8';
    AResponseInfo.ContentText := 'Rota nao encontrada. Use POST /biometria-sucesso';
  end;
end;

procedure TConectBiometricService.LogToFile(const AMsg: string);
var
  LogFile: string;
  F: TextFile;
begin
  try
    LogFile := ExtractFilePath(ParamStr(0)) + 'servico_biometria.log';
    AssignFile(F, LogFile);
    if FileExists(LogFile) then
      Append(F)
    else
      Rewrite(F);
    Writeln(F, Format('[%s] %s', [DateTimeToStr(Now), AMsg]));
    CloseFile(F);
  except
    // Não interrompe o serviço caso o arquivo esteja temporariamente bloqueado
  end;
end;

end.

