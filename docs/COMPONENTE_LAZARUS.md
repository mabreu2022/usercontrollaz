# Módulo 2: O Componente Lazarus (`TNetworkBiometricAuth`)
**Conect Solutions TI** — Engenharia de Sistemas Distribuídos e Mobile Cross-Platform

Este módulo contém a implementação do componente não-visual `TNetworkBiometricAuth` em Object Pascal para o Lazarus / Free Pascal, encapsulado no pacote oficial `.lpk` para instalação na IDE.

---

## 1. Localização dos Arquivos

* 📦 **Pacote de Instalação na IDE:** `lazarus_android/NetworkBiometricAuthPkg.lpk`
* 📄 **Unit do Componente:** `lazarus_android/UNetworkBiometricAuth.pas`
* 📱 **Exemplo de Formulário:** `lazarus_android/UFormMainAndroid.pas` e `.lfm`

---

## 2. Passo a Passo de Instalação no Lazarus

1. Abra a IDE do Lazarus.
2. Acesse o menu principal: **Pacote (Package)** ➔ **Abrir Arquivo de Pacote (.lpk)...**
3. Selecione o arquivo:
   `c:\Projetos Antigrtavity\Biometria Lazarus\lazarus_android\NetworkBiometricAuthPkg.lpk`
4. Na janela do gerenciador de pacotes que se abre, clique em:
   **Usar (Use)** ➔ **Instalar (Install)**.
5. O Lazarus solicitará confirmação para recompilar a IDE. Clique em **Sim (Yes)**.
6. Após a reinicialização automática do Lazarus, o componente estará registrado na sua paleta de componentes sob a aba **"ConectSolutions"**.

---

## 3. Propriedades e Eventos Publicados

| Propriedade / Evento | Tipo | Padrão | Descrição |
| :--- | :--- | :--- | :--- |
| `PCServerIP` | `string` | `'192.168.1.100'` | Endereço IP do computador na rede local ou `'127.0.0.1'` se via USB. |
| `Port` | `Integer` | `8080` | Porta TCP onde o serviço desktop está escutando. |
| `Route` | `string` | `'/biometria-sucesso'` | Endpoint HTTP interceptado pelo servidor desktop. |
| `UserName` | `string` | `'mauricio'` | Nome de usuário vinculado à autenticação atual. |
| `AutoSendOnSuccess` | `Boolean` | `True` | Se `True`, dispara o envio HTTP automaticamente após a leitura da digital. |
| `Timeout` | `Integer` | `5000` | Tempo limite em milissegundos para a conexão de rede. |
| `OnAuthSuccess` | `TBiometricSuccessEvent` | `nil` | Disparado quando a digital é validada localmente pelo sensor do celular. |
| `OnAuthError` | `TBiometricErrorEvent` | `nil` | Disparado quando o sensor recusa a digital ou o usuário cancela o diálogo. |
| `OnHttpSuccess` | `TBiometricHttpSuccessEvent`| `nil` | Disparado quando o PC responde com sucesso (código 200 OK). |
| `OnHttpError` | `TBiometricHttpErrorEvent` | `nil` | Disparado se houver falha de rota, IP incorreto ou recusa do firewall. |

---

## 4. Como Usar no seu Formulário Pascal

```pascal
unit UFormExemplo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls,
  UNetworkBiometricAuth;

type
  TfrmExemplo = class(TForm)
    btnAutenticar: TButton;
    BiometricAuth: TNetworkBiometricAuth;
    procedure btnAutenticarClick(Sender: TObject);
    procedure BiometricAuthAuthSuccess(Sender: TObject; const AUser: string);
    procedure BiometricAuthHttpSuccess(Sender: TObject; const AResponse: string);
    procedure BiometricAuthHttpError(Sender: TObject; const AErrorMsg: string);
  end;

implementation

{$R *.lfm}

procedure TfrmExemplo.btnAutenticarClick(Sender: TObject);
begin
  // Configura os parâmetros de conexão
  BiometricAuth.PCServerIP := '192.168.15.119';
  BiometricAuth.Port := 8080;
  BiometricAuth.UserName := 'mauricio';
  
  // Aciona a API nativa via JNI
  BiometricAuth.Authenticate;
end;

procedure TfrmExemplo.BiometricAuthAuthSuccess(Sender: TObject; const AUser: string);
begin
  ShowMessage('Digital aprovada no celular para: ' + AUser);
end;

procedure TfrmExemplo.BiometricAuthHttpSuccess(Sender: TObject; const AResponse: string);
begin
  ShowMessage('Acesso liberado no sistema Desktop! Servidor respondeu: ' + AResponse);
end;

procedure TfrmExemplo.BiometricAuthHttpError(Sender: TObject; const AErrorMsg: string);
begin
  ShowMessage('Falha ao comunicar com o PC: ' + AErrorMsg);
end;

end.
```

---

## 5. Ponte JNI e Concorrência

* A função nativa `Java_com_conectsolutions_biometria_BiometricHelper_onNativeBiometricSuccess` utiliza a convenção `cdecl`.
* Quando o Java confirma a digital, a procedure converte o `jstring` para string nativa Pascal e invoca a worker thread `TBiometricHttpWorkerThread`.
* A worker thread executa o transporte HTTP fora da thread de interface, evitando travamentos visuais ou o encerramento do processo pelo watchdog do Android.
