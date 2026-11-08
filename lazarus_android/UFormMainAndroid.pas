unit UFormMainAndroid;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  UNetworkBiometricAuth;

type
  { TfrmMainAndroid }
  TfrmMainAndroid = class(TForm)
    pnlTopo: TPanel;
    lblTitulo: TLabel;
    lblSubtitulo: TLabel;
    pnlConfig: TPanel;
    lblIP: TLabel;
    edtPCServerIP: TEdit;
    lblPorta: TLabel;
    edtPorta: TEdit;
    lblUsuario: TLabel;
    edtUsuario: TEdit;
    btnAutenticar: TButton;
    pnlFeedback: TPanel;
    lblStatus: TLabel;
    mmoConsole: TMemo;
    BiometricAuth: TNetworkBiometricAuth;

    procedure FormCreate(Sender: TObject);
    procedure btnAutenticarClick(Sender: TObject);
    procedure BiometricAuthAuthSuccess(Sender: TObject; const AUser: string);
    procedure BiometricAuthAuthError(Sender: TObject; AErrorCode: Integer; const AErrorMsg: string);
    procedure BiometricAuthHttpSuccess(Sender: TObject; const AResponse: string);
    procedure BiometricAuthHttpError(Sender: TObject; const AErrorMsg: string);
  private
    procedure LogMessage(const AMsg: string);
  public
  end;

var
  frmMainAndroid: TfrmMainAndroid;

implementation

{$R *.lfm}

{ TfrmMainAndroid }

procedure TfrmMainAndroid.FormCreate(Sender: TObject);
begin
  // Configuração padrão dos parâmetros de rede
  edtPCServerIP.Text := '192.168.1.100';
  edtPorta.Text := '8080';
  edtUsuario.Text := 'mauricio';

  LogMessage('Pronto. Configure o IP do seu PC e clique em "Autenticar com Digital".');
end;

procedure TfrmMainAndroid.btnAutenticarClick(Sender: TObject);
begin
  // Atualiza as propriedades dinâmicas do componente com base na UI
  BiometricAuth.PCServerIP := Trim(edtPCServerIP.Text);
  BiometricAuth.Port := StrToIntDef(Trim(edtPorta.Text), 8080);
  BiometricAuth.UserName := Trim(edtUsuario.Text);
  BiometricAuth.AutoSendOnSuccess := True;

  LogMessage(Format('Invocando BiometricPrompt para usuário: "%s"...', [BiometricAuth.UserName]));
  lblStatus.Caption := 'Aguardando validação da digital...';

  // Aciona a API nativa via JNI
  BiometricAuth.Authenticate;
end;

procedure TfrmMainAndroid.BiometricAuthAuthSuccess(Sender: TObject; const AUser: string);
begin
  LogMessage(Format('[LOCAL] Digital validada com sucesso no dispositivo para: %s', [AUser]));
  lblStatus.Caption := 'Digital aprovada! Enviando autorização para o PC...';
end;

procedure TfrmMainAndroid.BiometricAuthAuthError(Sender: TObject; AErrorCode: Integer; const AErrorMsg: string);
begin
  LogMessage(Format('[ERRO BIOMETRIA] Código %d: %s', [AErrorCode, AErrorMsg]));
  lblStatus.Caption := 'Falha na leitura biométrica: ' + AErrorMsg;
end;

procedure TfrmMainAndroid.BiometricAuthHttpSuccess(Sender: TObject; const AResponse: string);
begin
  LogMessage(Format('[REDE] Notificação entregue ao PC com sucesso! Resposta: %s', [AResponse]));
  lblStatus.Caption := 'ACESSO LIBERADO NO SISTEMA VCL COM SUCESSO!';
end;

procedure TfrmMainAndroid.BiometricAuthHttpError(Sender: TObject; const AErrorMsg: string);
begin
  LogMessage(Format('[ERRO REDE] Falha ao comunicar com o PC: %s', [AErrorMsg]));
  lblStatus.Caption := 'Erro de comunicação de rede: ' + AErrorMsg;
end;

procedure TfrmMainAndroid.LogMessage(const AMsg: string);
begin
  mmoConsole.Lines.Add(Format('[%s] %s', [TimeToStr(Now), AMsg]));
end;

end.

