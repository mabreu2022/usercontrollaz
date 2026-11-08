unit UNetworkBiometricAuth;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // Dependências Indy para transporte HTTP em FPC
  IdHTTP, IdComponent, IdSSLOpenSSL,
  // Se estiver compilando para Android, use a unit JNI nativa do FPC
  {$IFDEF ANDROID}
  jni
  {$ELSE}
  // Definições mock/compatibilidade para permitir compilação ou testes no ambiente desktop
  {$ENDIF}
  ;

{$IFNDEF ANDROID}
// Tipos auxiliares de emulação JNI para compilação multiplataforma/design-time
type
  jint = LongInt;
  jboolean = ByteBool;
  jobject = Pointer;
  jclass = Pointer;
  jstring = Pointer;
  jmethodID = Pointer;
  PJNIEnv = Pointer;
{$ENDIF}

type
  // Eventos do componente
  TBiometricSuccessEvent = procedure(Sender: TObject; const AUser: string) of object;
  TBiometricErrorEvent = procedure(Sender: TObject; AErrorCode: Integer; const AErrorMsg: string) of object;
  TBiometricHttpSuccessEvent = procedure(Sender: TObject; const AResponse: string) of object;
  TBiometricHttpErrorEvent = procedure(Sender: TObject; const AErrorMsg: string) of object;

  { Forward declaration da Thread de Envio HTTP }
  TBiometricHttpWorkerThread = class;

  { TNetworkBiometricAuth }
  TNetworkBiometricAuth = class(TComponent)
  private
    FPCServerIP: string;
    FPort: Integer;
    FRoute: string;
    FUserName: string;
    FAutoSendOnSuccess: Boolean;
    FTimeout: Integer;

    // Referências Android / JNI
    FCurrentActivity: jobject;
    FEnv: PJNIEnv;

    // Ponteiros de Eventos
    FOnAuthSuccess: TBiometricSuccessEvent;
    FOnAuthError: TBiometricErrorEvent;
    FOnHttpSuccess: TBiometricHttpSuccessEvent;
    FOnHttpError: TBiometricHttpErrorEvent;

    procedure SetPCServerIP(const AValue: string);
    procedure SetPort(const AValue: Integer);

  protected
    // Handlers invocados pelas funções CDECL da JNI
    procedure DoInternalBiometricSuccess(const AUser: string); virtual;
    procedure DoInternalBiometricError(AErrorCode: Integer; const AErrorMsg: string); virtual;

    // Handlers de sincronização do envio HTTP
    procedure DoHttpSuccess(const AResponse: string); virtual;
    procedure DoHttpError(const AErrorMsg: string); virtual;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Define a referência da Activity Android corrente (necessária para BiometricPrompt)
    procedure SetAndroidActivity(AEnv: PJNIEnv; AActivity: jobject);

    // Dispara a janela nativa do Android BiometricPrompt
    procedure Authenticate;

    // Dispara manualmente o POST HTTP para o PC (chamado automaticamente se AutoSendOnSuccess=True)
    procedure SendAuthorizationToPC(const AUser: string);

  published
    // Propriedades configuráveis exigidas
    property PCServerIP: string read FPCServerIP write SetPCServerIP;
    property Port: Integer read FPort write SetPort default 8080;
    property Route: string read FRoute write FRoute;
    property UserName: string read FUserName write FUserName;
    property AutoSendOnSuccess: Boolean read FAutoSendOnSuccess write FAutoSendOnSuccess default True;
    property Timeout: Integer read FTimeout write FTimeout default 5000;

    // Eventos
    property OnAuthSuccess: TBiometricSuccessEvent read FOnAuthSuccess write FOnAuthSuccess;
    property OnAuthError: TBiometricErrorEvent read FOnAuthError write FOnAuthError;
    property OnHttpSuccess: TBiometricHttpSuccessEvent read FOnHttpSuccess write FOnHttpSuccess;
    property OnHttpError: TBiometricHttpErrorEvent read FOnHttpError write FOnHttpError;
  end;

  { TBiometricHttpWorkerThread }
  { Executa o POST HTTP em segundo plano para não bloquear a UI Thread do Android (evita NetworkOnMainThreadException) }
  TBiometricHttpWorkerThread = class(TThread)
  private
    FOwner: TNetworkBiometricAuth;
    FURL: string;
    FJsonPayload: string;
    FTimeout: Integer;
    FResponseContent: string;
    FErrorMessage: string;
    FSuccess: Boolean;

    procedure SyncResult;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TNetworkBiometricAuth; const AURL, AJsonPayload: string; ATimeout: Integer);
  end;

// Instância ativa global para redirecionamento das callbacks JNI estáticas
var
  GBiometricAuthInstance: TNetworkBiometricAuth = nil;

// Declarações CDECL acessadas diretamente pela VM Java (JNI)
{$IFDEF ANDROID}
procedure Java_com_conectsolutions_biometria_BiometricHelper_onNativeBiometricSuccess(
  env: PJNIEnv; this: jobject; jUser: jstring); cdecl;
procedure Java_com_conectsolutions_biometria_BiometricHelper_onNativeBiometricError(
  env: PJNIEnv; this: jobject; errCode: jint; jErrMsg: jstring); cdecl;
{$ENDIF}

procedure Register;

implementation

{$IFDEF ANDROID}
// Função auxiliar para converter jstring da JVM em Pascal string
function JStringToString(AEnv: PJNIEnv; AJStr: jstring): string;
var
  IsCopy: jboolean;
  Chars: PChar;
begin
  Result := '';
  if (AEnv = nil) or (AJStr = nil) then Exit;
  Chars := AEnv^^.GetStringUTFChars(AEnv, AJStr, @IsCopy);
  if Chars <> nil then
  begin
    Result := StrPas(Chars);
    AEnv^^.ReleaseStringUTFChars(AEnv, AJStr, Chars);
  end;
end;

// =============================================================================
// Implementação dos Callbacks Nativos JNI
// =============================================================================
procedure Java_com_conectsolutions_biometria_BiometricHelper_onNativeBiometricSuccess(
  env: PJNIEnv; this: jobject; jUser: jstring); cdecl;
var
  LUser: string;
begin
  LUser := JStringToString(env, jUser);
  if Assigned(GBiometricAuthInstance) then
  begin
    GBiometricAuthInstance.DoInternalBiometricSuccess(LUser);
  end;
end;

procedure Java_com_conectsolutions_biometria_BiometricHelper_onNativeBiometricError(
  env: PJNIEnv; this: jobject; errCode: jint; jErrMsg: jstring); cdecl;
var
  LMsg: string;
begin
  LMsg := JStringToString(env, jErrMsg);
  if Assigned(GBiometricAuthInstance) then
  begin
    GBiometricAuthInstance.DoInternalBiometricError(Integer(errCode), LMsg);
  end;
end;
{$ENDIF}

{ TBiometricHttpWorkerThread }

constructor TBiometricHttpWorkerThread.Create(AOwner: TNetworkBiometricAuth; const AURL, AJsonPayload: string; ATimeout: Integer);
begin
  inherited Create(True); // Cria suspenso
  FreeOnTerminate := True;
  FOwner := AOwner;
  FURL := AURL;
  FJsonPayload := AJsonPayload;
  FTimeout := ATimeout;
  FSuccess := False;
  Resume;
end;

procedure TBiometricHttpWorkerThread.Execute;
var
  HTTPClient: TIdHTTP;
  RequestBody: TStringStream;
begin
  HTTPClient := TIdHTTP.Create(nil);
  RequestBody := TStringStream.Create(FJsonPayload, TEncoding.UTF8);
  try
    try
      HTTPClient.ConnectTimeout := FTimeout;
      HTTPClient.ReadTimeout := FTimeout;
      HTTPClient.Request.ContentType := 'application/json';
      HTTPClient.Request.CharSet := 'utf-8';
      HTTPClient.Request.UserAgent := 'ConectSolutions-Android-Biometric/1.0';

      // Executa o POST HTTP para o microserviço VCL no PC
      FResponseContent := HTTPClient.Post(FURL, RequestBody);
      FSuccess := True;
    except
      on E: Exception do
      begin
        FSuccess := False;
        FErrorMessage := E.Message;
      end;
    end;
  finally
    RequestBody.Free;
    HTTPClient.Free;
  end;

  // Sincroniza o resultado de volta para a Thread principal
  Synchronize(@SyncResult);
end;

procedure TBiometricHttpWorkerThread.SyncResult;
begin
  if not Assigned(FOwner) then Exit;

  if FSuccess then
    FOwner.DoHttpSuccess(FResponseContent)
  else
    FOwner.DoHttpError(FErrorMessage);
end;

{ TNetworkBiometricAuth }

constructor TNetworkBiometricAuth.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPCServerIP := '192.168.1.100'; // IP local padrão para configuração
  FPort := 8080;
  FRoute := '/biometria-sucesso';
  FUserName := 'mauricio';
  FAutoSendOnSuccess := True;
  FTimeout := 5000;
  FCurrentActivity := nil;
  FEnv := nil;

  // Registra a instância singleton para direcionar as callbacks nativas
  GBiometricAuthInstance := Self;
end;

destructor TNetworkBiometricAuth.Destroy;
begin
  if GBiometricAuthInstance = Self then
    GBiometricAuthInstance := nil;
  inherited Destroy;
end;

procedure TNetworkBiometricAuth.SetPCServerIP(const AValue: string);
begin
  if FPCServerIP <> AValue then
    FPCServerIP := Trim(AValue);
end;

procedure TNetworkBiometricAuth.SetPort(const AValue: Integer);
begin
  if (AValue > 0) and (AValue <= 65535) then
    FPort := AValue
  else
    FPort := 8080;
end;

procedure TNetworkBiometricAuth.SetAndroidActivity(AEnv: PJNIEnv; AActivity: jobject);
begin
  FEnv := AEnv;
  FCurrentActivity := AActivity;
end;

procedure TNetworkBiometricAuth.Authenticate;
{$IFDEF ANDROID}
var
  JHelperClass: jclass;
  MethodID: jmethodID;
  JUserStr: jstring;
{$ENDIF}
begin
  {$IFDEF ANDROID}
  if (FEnv = nil) or (FCurrentActivity = nil) then
  begin
    DoInternalBiometricError(-99, 'Ambiente JNI ou FragmentActivity não inicializados.');
    Exit;
  end;

  // Localiza a classe Java BiometricHelper compilada no pacote
  JHelperClass := FEnv^^.FindClass(FEnv, 'com/conectsolutions/biometria/BiometricHelper');
  if JHelperClass = nil then
  begin
    DoInternalBiometricError(-100, 'Classe com.conectsolutions.biometria.BiometricHelper não encontrada.');
    Exit;
  end;

  // Obtém o método estático: authenticateNative(FragmentActivity, String)
  MethodID := FEnv^^.GetStaticMethodID(
    FEnv,
    JHelperClass,
    'authenticateNative',
    '(Landroidx/fragment/app/FragmentActivity;Ljava/lang/String;)V'
  );

  if MethodID = nil then
  begin
    DoInternalBiometricError(-101, 'Método authenticateNative não encontrado na classe Java.');
    Exit;
  end;

  // Converte a string do usuário para jstring
  JUserStr := FEnv^^.NewStringUTF(FEnv, PChar(FUserName));

  // Executa o método estático Java que abrirá o BiometricPrompt
  FEnv^^.CallStaticVoidMethod(FEnv, JHelperClass, MethodID, [FCurrentActivity, JUserStr]);
  {$ELSE}
  // Simulação de teste em ambiente Windows / Linux Desktop
  DoInternalBiometricSuccess(FUserName);
  {$ENDIF}
end;

procedure TNetworkBiometricAuth.DoInternalBiometricSuccess(const AUser: string);
begin
  if Assigned(FOnAuthSuccess) then
    FOnAuthSuccess(Self, AUser);

  // Se auto-envio estiver ativo, despacha o POST HTTP imediatamente para o PC
  if FAutoSendOnSuccess then
    SendAuthorizationToPC(AUser);
end;

procedure TNetworkBiometricAuth.DoInternalBiometricError(AErrorCode: Integer; const AErrorMsg: string);
begin
  if Assigned(FOnAuthError) then
    FOnAuthError(Self, AErrorCode, AErrorMsg);
end;

procedure TNetworkBiometricAuth.SendAuthorizationToPC(const AUser: string);
var
  TargetURL: string;
  JsonBody: string;
begin
  if FPCServerIP = '' then
  begin
    DoHttpError('IP do servidor PC não foi definido.');
    Exit;
  end;

  // Monta a URL do serviço HTTP VCL no PC
  TargetURL := Format('http://%s:%d%s', [FPCServerIP, FPort, FRoute]);

  // Monta o payload JSON exatamente no formato exigido: {"user": "mauricio", "status": "approved"}
  JsonBody := Format('{"user": "%s", "status": "approved"}', [AUser]);

  // Executa o envio na worker thread para não travar o Android nem disparar NetworkOnMainThreadException
  TBiometricHttpWorkerThread.Create(Self, TargetURL, JsonBody, FTimeout);
end;

procedure TNetworkBiometricAuth.DoHttpSuccess(const AResponse: string);
begin
  if Assigned(FOnHttpSuccess) then
    FOnHttpSuccess(Self, AResponse);
end;

procedure TNetworkBiometricAuth.DoHttpError(const AErrorMsg: string);
begin
  if Assigned(FOnHttpError) then
    FOnHttpError(Self, AErrorMsg);
end;

procedure Register;
begin
  RegisterComponents('ConectSolutions', [TNetworkBiometricAuth]);
end;

end.

