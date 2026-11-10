unit ULazarusWebServer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Grids,
  fphttpserver, fpjson, jsonparser,
  UUserControlBiometria;

type
  { Dados transitórios passados do socket HTTP para a Thread Principal }
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

  { TServerThread: Roda o TFPHttpServer em background para não travar a interface LCL }
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
    PageControl1: TPageControl;
    tabStatus: TTabSheet;
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

    tabUserControl: TTabSheet;
    gridUsuarios: TStringGrid;
    pnlAlterarNivel: TPanel;
    lblTituloAlterar: TLabel;
    lblUsuarioSelecionado: TLabel;
    lblAlterarNivel: TLabel;
    cboAlterarNivel: TComboBox;
    btnSalvarNivel: TButton;
    btnExcluirUsuario: TButton;
    pnlNovoUsuario: TPanel;
    lblNovoNome: TLabel;
    edtNovoNome: TEdit;
    lblNovoLogin: TLabel;
    edtNovoLogin: TEdit;
    lblNovoNivel: TLabel;
    cboNovoNivel: TComboBox;
    btnCadastrarUsuario: TButton;
    btnVincularAparelho: TButton;
    btnAtualizarGrade: TButton;
    lblDicaUserControl: TLabel;

    tabSimuladorPDV: TTabSheet;
    pnlPDVHeader: TPanel;
    lblPDVTitulo: TLabel;
    lblPDVDescricao: TLabel;
    lblPDVRequisito: TLabel;
    pnlPDVStatus: TPanel;
    lblPDVStatus: TLabel;
    lblPDVDetalhe: TLabel;
    btnSimularDesconto: TButton;
    btnResetarSimulacao: TButton;
    mmoPDVLogs: TMemo;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnIniciarServidorClick(Sender: TObject);
    procedure btnPararServidorClick(Sender: TObject);
    procedure gridUsuariosClick(Sender: TObject);
    procedure btnSalvarNivelClick(Sender: TObject);
    procedure btnExcluirUsuarioClick(Sender: TObject);
    procedure btnCadastrarUsuarioClick(Sender: TObject);
    procedure btnVincularAparelhoClick(Sender: TObject);
    procedure btnAtualizarGradeClick(Sender: TObject);
    procedure btnSimularDescontoClick(Sender: TObject);
    procedure btnResetarSimulacaoClick(Sender: TObject);

  private
    FServerThread: TServerThread;
    FCurrentSyncData: TAuthSyncRecord;
    FAguardandoAprovacaoPDV: Boolean;
    FSelectedUserLogin: string;

    procedure DoLiberarAcessoMainThread;
    procedure AtualizarGradeUsuarios;
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
      // Encerramento limpo do socket
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
  // 2. Rota para sincronizar lista de usuários com o celular
  else if SameText(ARequest.PathInfo, '/usuarios') or SameText(ARequest.URL, '/usuarios') then
  begin
    AResponse.Code := 200;
    AResponse.ContentType := 'application/json; charset=utf-8';
    if Assigned(GUserManager) then
      AResponse.Content := GUserManager.ListarUsuariosJSON
    else
      AResponse.Content := '[]';
  end
  else
  begin
    AResponse.Code := 404;
    AResponse.ContentType := 'text/plain; charset=utf-8';
    AResponse.Content := 'Rota nao encontrada. Use POST /biometria-sucesso ou GET /usuarios';
  end;
end;

{ TfrmBiometricServerLazarus }

procedure TfrmBiometricServerLazarus.FormCreate(Sender: TObject);
begin
  FAguardandoAprovacaoPDV := False;
  AtualizarGradeUsuarios;
  IniciarServidor(8080);
end;

procedure TfrmBiometricServerLazarus.FormDestroy(Sender: TObject);
begin
  PararServidor;
end;

procedure TfrmBiometricServerLazarus.IniciarServidor(const APorta: Integer);
begin
  if FServerThread <> nil then
    PararServidor;

  FServerThread := TServerThread.Create(APorta);
  lblIPPorta.Caption := Format('Servidor Ativo na Porta: %d (Aguardando Biometria Android...)', [APorta]);
  lblStatusAcesso.Caption := 'SISTEMA BLOQUEADO - AGUARDANDO BIOMETRIA';
  pnlStatus.Color := $002B2BD6; // Vermelho de bloqueio
  lblStatusAcesso.Font.Color := clWhite;

  mmoLogs.Lines.Add(Format('[%s] Servidor HTTP nativo FPC iniciado com sucesso na porta %d.', [TimeToStr(Now), APorta]));
  mmoLogs.Lines.Add('Aguardando conexoes em: POST http://<IP_DO_PC>:' + IntToStr(APorta) + '/biometria-sucesso');
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

procedure TfrmBiometricServerLazarus.AtualizarGradeUsuarios;
var
  i: Integer;
  U: TUsuario;
begin
  gridUsuarios.RowCount := 1;
  gridUsuarios.Cells[0, 0] := 'ID';
  gridUsuarios.Cells[1, 0] := 'Nome Completo';
  gridUsuarios.Cells[2, 0] := 'Login';
  gridUsuarios.Cells[3, 0] := 'Nível de Acesso';
  gridUsuarios.Cells[4, 0] := 'Dispositivo Mobile';
  gridUsuarios.Cells[5, 0] := 'Biometria';

  gridUsuarios.ColWidths[0] := 35;
  gridUsuarios.ColWidths[1] := 180;
  gridUsuarios.ColWidths[2] := 100;
  gridUsuarios.ColWidths[3] := 120;
  gridUsuarios.ColWidths[4] := 140;
  gridUsuarios.ColWidths[5] := 90;

  if Assigned(GUserManager) then
  begin
    for i := 0 to GUserManager.Count - 1 do
    begin
      U := GUserManager[i];
      gridUsuarios.RowCount := gridUsuarios.RowCount + 1;
      gridUsuarios.Cells[0, i + 1] := IntToStr(U.Id);
      gridUsuarios.Cells[1, i + 1] := U.Nome;
      gridUsuarios.Cells[2, i + 1] := U.Login;
      gridUsuarios.Cells[3, i + 1] := U.NivelToString;
      if U.DeviceId <> '' then
        gridUsuarios.Cells[4, i + 1] := U.DeviceId
      else
        gridUsuarios.Cells[4, i + 1] := '(Pendente)';

      if U.BiometriaAtiva then
        gridUsuarios.Cells[5, i + 1] := 'Sim'
      else
        gridUsuarios.Cells[5, i + 1] := 'Nao';
    end;
  end;
end;

procedure TfrmBiometricServerLazarus.gridUsuariosClick(Sender: TObject);
var
  RowIndex: Integer;
  LoginCell: string;
  U: TUsuario;
begin
  RowIndex := gridUsuarios.Row;
  if (RowIndex > 0) and (RowIndex < gridUsuarios.RowCount) then
  begin
    LoginCell := Trim(gridUsuarios.Cells[2, RowIndex]); // Coluna 2 = Login
    if (LoginCell <> '') and Assigned(GUserManager) then
    begin
      U := GUserManager.BuscarPorLogin(LoginCell);
      if Assigned(U) then
      begin
        FSelectedUserLogin := U.Login;
        lblUsuarioSelecionado.Caption := Format('Usuário Selecionado: %s (Login: %s) — Nível Atual: %s', [
          U.Nome, U.Login, U.NivelToString
        ]);
        case U.Nivel of
          naConsulta: cboAlterarNivel.ItemIndex := 0;
          naOperador: cboAlterarNivel.ItemIndex := 1;
          naGerente: cboAlterarNivel.ItemIndex := 2;
          naAdministrador: cboAlterarNivel.ItemIndex := 3;
        else
          cboAlterarNivel.ItemIndex := 1;
        end;
      end;
    end;
  end;
end;

procedure TfrmBiometricServerLazarus.btnSalvarNivelClick(Sender: TObject);
var
  NovoNivel: TNivelAcesso;
  NivelStr: string;
begin
  if FSelectedUserLogin = '' then
  begin
    ShowMessage('Por favor, clique em um usuário na grade antes de salvar a alteração.');
    Exit;
  end;

  case cboAlterarNivel.ItemIndex of
    0: begin NovoNivel := naConsulta; NivelStr := 'Consulta'; end;
    1: begin NovoNivel := naOperador; NivelStr := 'Operador'; end;
    2: begin NovoNivel := naGerente; NivelStr := 'Gerente'; end;
    3: begin NovoNivel := naAdministrador; NivelStr := 'Administrador'; end;
  else
    NovoNivel := naOperador;
    NivelStr := 'Operador';
  end;

  if Assigned(GUserManager) then
  begin
    if GUserManager.AlterarNivel(FSelectedUserLogin, NovoNivel) then
    begin
      AtualizarGradeUsuarios;
      lblUsuarioSelecionado.Caption := Format('Usuário Selecionado: %s — Nível Atualizado para: %s', [
        FSelectedUserLogin, NivelStr
      ]);
      mmoLogs.Lines.Add(Format('[%s] UserControl: Nível do usuário "%s" alterado para %s com sucesso.', [
        TimeToStr(Now), FSelectedUserLogin, NivelStr
      ]));
      ShowMessage(Format('Sucesso! O nível do usuário "%s" agora é "%s".', [
        FSelectedUserLogin, NivelStr
      ]));
    end
    else
      ShowMessage('Erro: Não foi possível alterar o nível do usuário.');
  end;
end;

procedure TfrmBiometricServerLazarus.btnExcluirUsuarioClick(Sender: TObject);
begin
  if FSelectedUserLogin = '' then
  begin
    ShowMessage('Clique em um usuário na grade para selecioná-lo antes de excluir.');
    Exit;
  end;

  if MessageDlg('Confirmação', Format('Deseja realmente excluir o usuário "%s"?', [FSelectedUserLogin]),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    if Assigned(GUserManager) then
    begin
      if GUserManager.ExcluirUsuario(FSelectedUserLogin) then
      begin
        mmoLogs.Lines.Add(Format('[%s] UserControl: Usuário "%s" removido.', [TimeToStr(Now), FSelectedUserLogin]));
        FSelectedUserLogin := '';
        lblUsuarioSelecionado.Caption := 'Usuário: (Nenhum selecionado. Clique em uma linha da tabela acima)';
        AtualizarGradeUsuarios;
        ShowMessage('Usuário excluído com sucesso!');
      end;
    end;
  end;
end;

procedure TfrmBiometricServerLazarus.btnCadastrarUsuarioClick(Sender: TObject);
var
  NNome, NLogin: string;
  Nivel: TNivelAcesso;
begin
  NNome := Trim(edtNovoNome.Text);
  NLogin := Trim(edtNovoLogin.Text);

  if (NNome = '') or (NLogin = '') then
  begin
    ShowMessage('Informe o Nome e o Login do novo usuário.');
    Exit;
  end;

  case cboNovoNivel.ItemIndex of
    0: Nivel := naConsulta;
    1: Nivel := naOperador;
    2: Nivel := naGerente;
    3: Nivel := naAdministrador;
  else
    Nivel := naOperador;
  end;

  if Assigned(GUserManager) then
  begin
    GUserManager.AdicionarUsuario(NNome, NLogin, Nivel);
    GUserManager.SalvarParaArquivo;
    AtualizarGradeUsuarios;
    ShowMessage(Format('Usuário "%s" cadastrado com sucesso!', [NNome]));
  end;
end;

procedure TfrmBiometricServerLazarus.btnVincularAparelhoClick(Sender: TObject);
begin
  if FCurrentSyncData.DeviceId <> '' then
  begin
    if Assigned(GUserManager) then
    begin
      GUserManager.VincularDispositivo(FCurrentSyncData.UserName, FCurrentSyncData.DeviceId);
      AtualizarGradeUsuarios;
      ShowMessage(Format('Dispositivo "%s" vinculado com sucesso ao usuário "%s"!', [
        FCurrentSyncData.DeviceId, FCurrentSyncData.UserName
      ]));
    end;
  end
  else
    ShowMessage('Nenhum aparelho enviou biometria recentemente para ser vinculado.');
end;

procedure TfrmBiometricServerLazarus.btnAtualizarGradeClick(Sender: TObject);
begin
  AtualizarGradeUsuarios;
end;

procedure TfrmBiometricServerLazarus.btnSimularDescontoClick(Sender: TObject);
begin
  FAguardandoAprovacaoPDV := True;
  pnlPDVStatus.Color := $002B2BD6; // Vermelho
  lblPDVStatus.Caption := 'AGUARDANDO APROVAÇÃO BIOMÉTRICA DO GERENTE...';
  lblPDVDetalhe.Caption := 'O Gerente deve validar a digital no smartphone para autorizar o desconto.';
  mmoPDVLogs.Lines.Add(Format('[%s] SOLICITAÇÃO ABERTA: Desconto de 25% (R$ 150,00) aguardando biometria...', [TimeToStr(Now)]));
end;

procedure TfrmBiometricServerLazarus.btnResetarSimulacaoClick(Sender: TObject);
begin
  FAguardandoAprovacaoPDV := False;
  pnlPDVStatus.Color := 2829270;
  lblPDVStatus.Caption := 'VENDA EM ABERTO - NENHUMA EXCEÇÃO SOLICITADA';
  lblPDVDetalhe.Caption := 'Clique em "SOLICITAR LIBERAÇÃO NO CELULAR" para testar a aprovação remota.';
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
  // 1. Atualizar painel da Aba 1 (Login / Desbloqueio Geral)
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

  // 2. Se a simulação de PDV da Aba 3 estiver ativa, verifica nível gerencial
  if FAguardandoAprovacaoPDV then
  begin
    if FCurrentSyncData.LevelCode >= 3 then // Nível Gerente (3) ou Admin (4)
    begin
      pnlPDVStatus.Color := $002E8B57; // Verde
      lblPDVStatus.Caption := 'DESCONTO DE 25% APROVADO COM SUCESSO!';
      lblPDVDetalhe.Caption := Format('Autorizado remotamente por %s (%s) às %s.', [
        FCurrentSyncData.FullName, FCurrentSyncData.UserLevel, TimeToStr(Now)
      ]);
      mmoPDVLogs.Lines.Add(Format('>>> [%s] OPERAÇÃO LIBERADA: Gerente %s autorizou o desconto!', [
        TimeToStr(Now), FCurrentSyncData.FullName
      ]));
      FAguardandoAprovacaoPDV := False;
    end
    else
    begin
      lblPDVStatus.Caption := 'RECUSADO: NÍVEL DE PRIVILÉGIO INSUFICIENTE!';
      lblPDVDetalhe.Caption := Format('O usuário %s possui nível "%s". Exigido: Gerente ou Administrador.', [
        FCurrentSyncData.FullName, FCurrentSyncData.UserLevel
      ]);
      mmoPDVLogs.Lines.Add(Format('>>> [%s] RECUSA: %s tentou aprovar com nível insuficiente (%s)', [
        TimeToStr(Now), FCurrentSyncData.FullName, FCurrentSyncData.UserLevel
      ]));
    end;
  end;

  AtualizarGradeUsuarios;
  BringToFront;
end;

end.
