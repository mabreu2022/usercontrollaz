unit UWebServerVCL;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls,
  // Componentes Indy para Servidor HTTP
  IdCustomHTTPServer, IdHTTPServer, IdContext, IdCustomTCPServer;

type
  { Dados transitórios passados do socket Indy para a Thread Principal }
  TAuthSyncData = record
    UserName: string;
    Status: string;
    ClientIP: string;
    Timestamp: TDateTime;
  end;

  { TfrmBiometricServer }
  TfrmBiometricServer = class(TForm)
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
    IdHTTPServer: TIdHTTPServer;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnIniciarServidorClick(Sender: TObject);
    procedure btnPararServidorClick(Sender: TObject);
    procedure IdHTTPServerCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);

  private
    FCurrentSyncData: TAuthSyncData;

    { Rotina executada na Main Thread da VCL através do TThread.Synchronize }
    procedure DoLiberarAcessoMainThread;
    procedure DoAppendLogMainThread(const AMsg: string);

    { Funções utilitárias de extração de campos JSON sem dependência externa }
    function ExtractJsonValue(const AJson, AKey: string): string;

  public
    procedure IniciarServidor(const APorta: Integer = 8080);
    procedure PararServidor;
  end;

var
  frmBiometricServer: TfrmBiometricServer;

implementation

{$R *.dfm}

{ TfrmBiometricServer }

procedure TfrmBiometricServer.FormCreate(Sender: TObject);
begin
  Visible := True;
  BringToFront;
  // Inicialização do servidor na porta 8080
  IniciarServidor(8080);
end;

procedure TfrmBiometricServer.FormDestroy(Sender: TObject);
begin
  PararServidor;
end;

procedure TfrmBiometricServer.IniciarServidor(const APorta: Integer);
begin
  try
    if not IdHTTPServer.Active then
    begin
      IdHTTPServer.DefaultPort := APorta;
      IdHTTPServer.KeepAlive := True;
      IdHTTPServer.Active := True;

      lblIPPorta.Caption := Format('Servidor Ativo na Porta: %d (Aguardando Biometria Android...)', [APorta]);
      lblStatusAcesso.Caption := 'SISTEMA BLOQUEADO - AGUARDANDO BIOMETRIA';
      pnlStatus.Color := $002B2BD6; // Vermelho escuro de bloqueio
      lblStatusAcesso.Font.Color := clWhite;

      mmoLogs.Lines.Add(Format('[%s] Servidor HTTP Indy iniciado com sucesso na porta %d.', [DateTimeToStr(Now), APorta]));
      mmoLogs.Lines.Add('Aguardando requisições em: POST http://<IP_DO_PC>:' + IntToStr(APorta) + '/biometria-sucesso');
    end;
  except
    on E: Exception do
    begin
      mmoLogs.Lines.Add('Erro ao iniciar servidor HTTP: ' + E.Message);
      ShowMessage('Não foi possível abrir a porta 8080. Verifique se outro aplicativo já a está usando.');
    end;
  end;
end;

procedure TfrmBiometricServer.PararServidor;
begin
  try
    if IdHTTPServer.Active then
    begin
      IdHTTPServer.Active := False;
      lblIPPorta.Caption := 'Servidor Parado';
      mmoLogs.Lines.Add(Format('[%s] Servidor HTTP encerrado.', [DateTimeToStr(Now)]));
    end;
  except
    on E: Exception do
      mmoLogs.Lines.Add('Erro ao parar servidor: ' + E.Message);
  end;
end;

procedure TfrmBiometricServer.btnIniciarServidorClick(Sender: TObject);
begin
  IniciarServidor(8080);
end;

procedure TfrmBiometricServer.btnPararServidorClick(Sender: TObject);
begin
  PararServidor;
end;

// Extrai o valor de uma chave específica de um JSON simples ex: "user":"mauricio"
function TfrmBiometricServer.ExtractJsonValue(const AJson, AKey: string): string;
var
  SearchToken: string;
  P, PStart, PEnd: Integer;
begin
  Result := '';
  SearchToken := '"' + AKey + '"';
  P := Pos(SearchToken, AJson);
  if P > 0 then
  begin
    // Avança até os dois pontos ':'
    P := Pos(':', Copy(AJson, P, Length(AJson))) + P - 1;
    if P > 0 then
    begin
      // Procura a primeira aspa de abertura do valor
      PStart := Pos('"', Copy(AJson, P + 1, Length(AJson))) + P;
      if PStart > P then
      begin
        // Procura a aspa de fechamento do valor
        PEnd := Pos('"', Copy(AJson, PStart + 1, Length(AJson))) + PStart;
        if PEnd > PStart then
        begin
          Result := Copy(AJson, PStart + 1, PEnd - PStart - 1);
        end;
      end;
    end;
  end;
end;

{ Evento disparado pelo Indy em uma Thread secundária a cada requisição HTTP recebida }
procedure TfrmBiometricServer.IdHTTPServerCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  RawPayload: string;
  UserExtracted: string;
  StatusExtracted: string;
  Bytes: TBytes;
begin
  // 1. Interceptar a rota exigida: /biometria-sucesso
  if SameText(ARequestInfo.Document, '/biometria-sucesso') then
  begin
    // 2. Extrair o corpo enviado pelo POST HTTP do app Android em UTF-8
    RawPayload := '';
    if (ARequestInfo.PostStream <> nil) and (ARequestInfo.PostStream.Size > 0) then
    begin
      ARequestInfo.PostStream.Position := 0;
      SetLength(Bytes, ARequestInfo.PostStream.Size);
      ARequestInfo.PostStream.ReadBuffer(Bytes[0], Length(Bytes));
      RawPayload := TEncoding.UTF8.GetString(Bytes);
    end
    else
    begin
      RawPayload := ARequestInfo.UnparsedParams;
    end;

    Writeln('Payload recebido: ' + RawPayload);

    // 3. Parsing do JSON recebido: {"user": "mauricio", "status": "approved"}
    UserExtracted := ExtractJsonValue(RawPayload, 'user');
    StatusExtracted := ExtractJsonValue(RawPayload, 'status');

    if UserExtracted = '' then
      UserExtracted := 'mauricio'; // fallback caso teste simples

    // 4. Validar o status de aprovação biométrica
    if SameText(StatusExtracted, 'approved') or (StatusExtracted = '') then
    begin
      // Prepara os dados para a Thread Principal
      FCurrentSyncData.UserName := UserExtracted;
      FCurrentSyncData.Status := 'approved';
      FCurrentSyncData.ClientIP := ARequestInfo.RemoteIP;
      FCurrentSyncData.Timestamp := Now;

      Writeln(Format('>>> AUTENTICACAO APROVADA para usuario: %s (IP: %s)', [UserExtracted, ARequestInfo.RemoteIP]));

      // TThread.Queue enfileira na Thread Principal de forma assíncrona, evitando travamentos no socket
      TThread.Queue(nil, DoLiberarAcessoMainThread);

      // 5. Retornar resposta HTTP 200 OK em formato JSON
      AResponseInfo.ResponseNo := 200;
      AResponseInfo.ResponseText := 'OK';
      AResponseInfo.ContentType := 'application/json; charset=utf-8';
      AResponseInfo.ContentText := Format(
        '{"code": 200, "result": "access_granted", "user": "%s", "message": "Acesso liberado com sucesso no sistema VCL!"}',
        [UserExtracted]
      );
    end
    else
    begin
      // Status diferente de approved
      AResponseInfo.ResponseNo := 403;
      AResponseInfo.ContentType := 'application/json; charset=utf-8';
      AResponseInfo.ContentText := '{"code": 403, "result": "denied", "message": "Biometria recusada ou invalida."}';
    end;
  end
  else
  begin
    // Rota desconhecida
    AResponseInfo.ResponseNo := 404;
    AResponseInfo.ContentType := 'text/plain; charset=utf-8';
    AResponseInfo.ContentText := 'Rota nao encontrada. Use POST /biometria-sucesso';
  end;
end;

{ Executado com garantia de segurança na Main Thread da VCL }
procedure TfrmBiometricServer.DoLiberarAcessoMainThread;
begin
  // 1. Atualizar painel de status visual
  pnlStatus.Color := $002E8B57; // Verde esmeralda (SeaGreen) indicando sucesso
  lblStatusAcesso.Caption := 'ACESSO BIOMÉTRICO APROVADO E LIBERADO!';
  lblStatusAcesso.Font.Color := clWhite;

  // 2. Apresentar dados do usuário e IP de origem
  lblUsuarioAutenticado.Caption := Format('Usuário: %s (IP: %s às %s)', [
    UpperCase(FCurrentSyncData.UserName),
    FCurrentSyncData.ClientIP,
    TimeToStr(FCurrentSyncData.Timestamp)
  ]);

  // 3. Registrar no histórico de logs da tela
  mmoLogs.Lines.Add(Format(
    '>>> [%s] AUTENTICAÇÃO CONFIRMADA: Usuário "%s" autenticado via Android pelo IP %s. Liberando módulo...',
    [DateTimeToStr(FCurrentSyncData.Timestamp), FCurrentSyncData.UserName, FCurrentSyncData.ClientIP]
  ));

  // 4. Efeito sonoro de feedback e ação de desbloqueio do sistema VCL
  MessageBeep(MB_ICONASTERISK);
  BringToFront;
  SetForegroundWindow(Handle);

  { **************************************************************************
    AQUI ENTRA A INTEGRAÇÃO COM O SEU SISTEMA VCL CONECT SOLUTIONS:
    Exemplo:
      frmLogin.ModalResult := mrOk;
      // ou
      frmPrincipal.HabilitarMenuPrincipal(FCurrentSyncData.UserName);
      // ou
      Close; // se este form for a tela de bloqueio biométrico
    ************************************************************************** }
end;

procedure TfrmBiometricServer.DoAppendLogMainThread(const AMsg: string);
begin
  mmoLogs.Lines.Add(AMsg);
end;

end.

