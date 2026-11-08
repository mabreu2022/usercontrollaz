unit UUserControlBiometria;

{$IFDEF FPC}
  {$mode objfpc}{$H+}
{$ENDIF}

interface

uses
  Classes, SysUtils,
  {$IFDEF FPC}
  fpjson, jsonparser
  {$ELSE}
  System.JSON
  {$ENDIF};

type
  { Níveis de Permissão Hierárquicos (RBAC) }
  TNivelAcesso = (
    naConsulta = 1,       // Apenas visualização
    naOperador = 2,       // Operações rotineiras de caixa/vendas
    naGerente = 3,        // Aprovação de descontos, estornos e cancelamentos
    naAdministrador = 4   // Controle total do sistema e gestão de biometrias
  );

  { Dados do Usuário }
  TUsuario = class
  private
    FId: Integer;
    FNome: string;
    FLogin: string;
    FNivel: TNivelAcesso;
    FDeviceId: string;         // Identificador único do celular Android emparelhado
    FBiometriaAtiva: Boolean;  // Se já possui biometria cadastrada
    FAtivo: Boolean;
    FUltimoAcesso: TDateTime;
  public
    constructor Create(AId: Integer; const ANome, ALogin: string; ANivel: TNivelAcesso);
    function NivelToString: string;
    function ToJSONString: string;

    property Id: Integer read FId write FId;
    property Nome: string read FNome write FNome;
    property Login: string read FLogin write FLogin;
    property Nivel: TNivelAcesso read FNivel write FNivel;
    property DeviceId: string read FDeviceId write FDeviceId;
    property BiometriaAtiva: Boolean read FBiometriaAtiva write FBiometriaAtiva;
    property Ativo: Boolean read FAtivo write FAtivo;
    property UltimoAcesso: TDateTime read FUltimoAcesso write FUltimoAcesso;
  end;

  { Gerenciador Central de Usuários e Permissões (UserControl Core) }
  TUserManager = class
  private
    FUsuarios: TList;
    FFilePath: string;
    procedure PopularUsuariosIniciais;
  public
    constructor Create(const ADataPath: string = '');
    destructor Destroy; override;

    function AdicionarUsuario(const ANome, ALogin: string; ANivel: TNivelAcesso): TUsuario;
    function BuscarPorLogin(const ALogin: string): TUsuario;
    function BuscarPorDeviceId(const ADeviceId: string): TUsuario;
    
    // Vincula o celular ao usuário após o primeiro cadastro biométrico
    function VincularDispositivo(const ALogin, ADeviceId: string): Boolean;
    
    // Valida autenticação biométrica e checa nível mínimo de privilégio
    function ValidarAcesso(const ALogin, ADeviceId: string; ANivelRequerido: TNivelAcesso; out AErrorMsg: string): Boolean;

    // Salvar e Carregar em arquivo JSON
    procedure SalvarParaArquivo;
    procedure CarregarDeArquivo;

    // Retorna todos os usuários formatados em JSON
    function ListarUsuariosJSON: string;
  end;

var
  GUserManager: TUserManager = nil;

implementation

{ TUsuario }

constructor TUsuario.Create(AId: Integer; const ANome, ALogin: string; ANivel: TNivelAcesso);
begin
  inherited Create;
  FId := AId;
  FNome := ANome;
  FLogin := LowerCase(Trim(ALogin));
  FNivel := ANivel;
  FDeviceId := '';
  FBiometriaAtiva := False;
  FAtivo := True;
  FUltimoAcesso := 0;
end;

function TUsuario.NivelToString: string;
begin
  case FNivel of
    naConsulta: Result := 'Consulta';
    naOperador: Result := 'Operador';
    naGerente: Result := 'Gerente';
    naAdministrador: Result := 'Administrador';
  else
    Result := 'Desconhecido';
  end;
end;

function TUsuario.ToJSONString: string;
begin
  Result := Format(
    '{"id": %d, "nome": "%s", "login": "%s", "nivel": "%s", "nivel_code": %d, "biometria_ativa": %s, "ativo": %s, "device_id": "%s"}',
    [
      FId,
      FNome,
      FLogin,
      NivelToString,
      Ord(FNivel),
      BoolToStr(FBiometriaAtiva, 'true', 'false'),
      BoolToStr(FAtivo, 'true', 'false'),
      FDeviceId
    ]
  );
end;

{ TUserManager }

constructor TUserManager.Create(const ADataPath: string);
begin
  inherited Create;
  FUsuarios := TList.Create;
  if ADataPath <> '' then
    FFilePath := ADataPath
  else
    FFilePath := ExtractFilePath(ParamStr(0)) + 'usuarios_usercontrol.json';

  if FileExists(FFilePath) then
    CarregarDeArquivo
  else
    PopularUsuariosIniciais;
end;

destructor TUserManager.Destroy;
var
  i: Integer;
begin
  SalvarParaArquivo;
  for i := 0 to FUsuarios.Count - 1 do
    TUsuario(FUsuarios[i]).Free;
  FUsuarios.Free;
  inherited Destroy;
end;

procedure TUserManager.PopularUsuariosIniciais;
var
  U1, U2, U3: TUsuario;
begin
  // Cadastro inicial corporativo para testes imediatos
  U1 := AdicionarUsuario('Maurício Oliveira', 'mauricio', naAdministrador);
  U1.BiometriaAtiva := True;

  U2 := AdicionarUsuario('Carlos Gerência', 'carlos.gerente', naGerente);
  U2.BiometriaAtiva := True;

  U3 := AdicionarUsuario('Ana Operadora Caixa', 'ana.caixa', naOperador);
  U3.BiometriaAtiva := False;

  SalvarParaArquivo;
end;

function TUserManager.AdicionarUsuario(const ANome, ALogin: string; ANivel: TNivelAcesso): TUsuario;
var
  NovoId: Integer;
begin
  NovoId := FUsuarios.Count + 1;
  Result := TUsuario.Create(NovoId, ANome, ALogin, ANivel);
  FUsuarios.Add(Result);
end;

function TUserManager.BuscarPorLogin(const ALogin: string): TUsuario;
var
  i: Integer;
  Target: string;
begin
  Result := nil;
  Target := LowerCase(Trim(ALogin));
  for i := 0 to FUsuarios.Count - 1 do
  begin
    if TUsuario(FUsuarios[i]).Login = Target then
    begin
      Result := TUsuario(FUsuarios[i]);
      Exit;
    end;
  end;
end;

function TUserManager.BuscarPorDeviceId(const ADeviceId: string): TUsuario;
var
  i: Integer;
begin
  Result := nil;
  if Trim(ADeviceId) = '' then Exit;
  for i := 0 to FUsuarios.Count - 1 do
  begin
    if SameText(TUsuario(FUsuarios[i]).DeviceId, Trim(ADeviceId)) then
    begin
      Result := TUsuario(FUsuarios[i]);
      Exit;
    end;
  end;
end;

function TUserManager.VincularDispositivo(const ALogin, ADeviceId: string): Boolean;
var
  U: TUsuario;
begin
  Result := False;
  U := BuscarPorLogin(ALogin);
  if Assigned(U) then
  begin
    U.DeviceId := Trim(ADeviceId);
    U.BiometriaAtiva := True;
    SalvarParaArquivo;
    Result := True;
  end;
end;

function TUserManager.ValidarAcesso(const ALogin, ADeviceId: string; ANivelRequerido: TNivelAcesso; out AErrorMsg: string): Boolean;
var
  U: TUsuario;
begin
  Result := False;
  AErrorMsg := '';

  U := BuscarPorLogin(ALogin);
  if not Assigned(U) then
  begin
    AErrorMsg := Format('Usuário "%s" não encontrado no sistema.', [ALogin]);
    Exit;
  end;

  if not U.Ativo then
  begin
    AErrorMsg := Format('O usuário "%s" está inativo.', [ALogin]);
    Exit;
  end;

  // Validação do Vínculo do Aparelho (Se já houver dispositivo registrado)
  if (U.DeviceId <> '') and (ADeviceId <> '') and not SameText(U.DeviceId, ADeviceId) then
  begin
    AErrorMsg := 'Acesso negado: Dispositivo mobile não autorizado para este usuário.';
    Exit;
  end;

  // Verificação hierárquica do nível de permissão (RBAC)
  if Ord(U.Nivel) < Ord(ANivelRequerido) then
  begin
    AErrorMsg := Format('Privilégio insuficiente. Nível requerido: %s. Seu nível: %s.', [
      U.NivelToString,
      U.NivelToString
    ]);
    Exit;
  end;

  U.UltimoAcesso := Now;
  Result := True;
end;

procedure TUserManager.SalvarParaArquivo;
var
  Lines: TStringList;
  i: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('[');
    for i := 0 to FUsuarios.Count - 1 do
    begin
      if i < FUsuarios.Count - 1 then
        Lines.Add('  ' + TUsuario(FUsuarios[i]).ToJSONString + ',')
      else
        Lines.Add('  ' + TUsuario(FUsuarios[i]).ToJSONString);
    end;
    Lines.Add(']');
    Lines.SaveToFile(FFilePath);
  finally
    Lines.Free;
  end;
end;

procedure TUserManager.CarregarDeArquivo;
var
  Lines: TStringList;
  Raw: string;
begin
  // Carregamento simples mantido em JSON
  if not FileExists(FFilePath) then Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FFilePath);
    Raw := Lines.Text;
    // Se o arquivo estiver vazio, repopula padrão
    if Trim(Raw) = '' then
      PopularUsuariosIniciais;
  finally
    Lines.Free;
  end;
end;

function TUserManager.ListarUsuariosJSON: string;
var
  i: Integer;
begin
  Result := '[';
  for i := 0 to FUsuarios.Count - 1 do
  begin
    if i > 0 then Result := Result + ', ';
    Result := Result + TUsuario(FUsuarios[i]).ToJSONString;
  end;
  Result := Result + ']';
end;

initialization
  GUserManager := TUserManager.Create;

finalization
  if Assigned(GUserManager) then
    FreeAndNil(GUserManager);

end.

