# Central de Documentação Técnica
## Conect Solutions TI — Autenticação Biométrica em Rede Local (Mobile Android ➔ Desktop VCL / Lazarus)

Bem-vindo à documentação oficial da solução de autenticação biométrica em dois fatores (2FA) e controle de acesso corporativo via rede local, integrando dispositivos Android (compilados via Lazarus / FPC com wrapper nativo AndroidX) a sistemas de gestão desktop (VCL e LCL / Lazarus).

---

### Estrutura dos Manuais e Guias Técnicos

| Documento | Descrição | Público-Alvo |
| :--- | :--- | :--- |
| 📘 [**Arquitetura Geral da Solução**](ARQUITETURA.md) | Visão de alto nível, diagramas de sequência, segurança e topologia de rede local (Wi-Fi e USB). | Arquitetos e Líderes Técnicos |
| 📱 [**Módulo 1: O Wrapper Android (Java / Gradle)**](MODULO_ANDROID.md) | Detalhes do `BiometricHelper.java`, dependências Gradle, permissões do `AndroidManifest.xml` e ciclo de vida. | Desenvolvedores Mobile / Android |
| 🧩 [**Módulo 2: O Componente Lazarus (`.lpk`)**](COMPONENTE_LAZARUS.md) | Passo a passo de instalação do pacote `NetworkBiometricAuthPkg.lpk`, propriedades e ponte JNI. | Desenvolvedores Pascal / Lazarus |
| 🖥️ [**Módulo 3: O Servidor HTTP no PC (VCL & LCL)**](SERVIDOR_PC_VCL.md) | Configuração do microsserviço no PC (`TFPHttpServer` e `TIdHTTPServer`), sincronização de threads e portas. | Desenvolvedores Desktop / VCL |
| 👥 [**Módulo 4: UserControl Biométrico (RBAC)**](USERCONTROL_BIOMETRICO.md) | Sistema de níveis de acesso, vinculação de aparelhos (`DeviceId`), elevação de privilégios (2FA) e persistência. | Engenheiros de Software / Segurança |
| ⚡ [**Guia Rápido de Execução e Testes**](GUIA_RAPIDO_EXECUCAO.md) | Como rodar a aplicação em 3 passos, comandos ADB e resolução rápida de problemas (Firewall, Wi-Fi). | Equipe de Suporte e QA |

---

### Visão Rápida dos Arquivos do Projeto

```text
c:\Projetos Antigrtavity\Biometria Lazarus\
├── docs/                                         # Pasta de documentação técnica completa
│   ├── INDEX.md                                  # Índice geral (este documento)
│   ├── ARQUITETURA.md                            # Visão de alto nível e diagramas
│   ├── MODULO_ANDROID.md                         # Wrapper Java / AndroidX
│   ├── COMPONENTE_LAZARUS.md                     # Componente .lpk e JNI
│   ├── SERVIDOR_PC_VCL.md                        # Servidor HTTP Indy e FPC
│   ├── USERCONTROL_BIOMETRICO.md                 # RBAC e Níveis de Usuário
│   └── GUIA_RAPIDO_EXECUCAO.md                   # Manual prático de operação
├── android/                                      # Projeto Android completo
│   ├── build.gradle                              # Configuração raiz Gradle
│   └── app/
│       ├── build.gradle                          # Dependências (androidx.biometric:1.1.0)
│       └── src/main/
│           ├── AndroidManifest.xml               # Permissões de rede e biometria
│           ├── java/com/conectsolutions/biometria/
│           │   ├── BiometricHelper.java          # Wrapper Java e hooks JNI
│           │   └── MainActivity.java             # Interface nativa Android de teste
│           └── res/                              # Layouts e temas visuais
├── lazarus_android/                              # Componente Free Pascal / Lazarus
│   ├── NetworkBiometricAuthPkg.lpk               # Pacote oficial de instalação na IDE
│   ├── UNetworkBiometricAuth.pas                 # Componente TComponent TNetworkBiometricAuth
│   ├── UFormMainAndroid.pas                      # Exemplo de formulário no celular
│   └── UFormMainAndroid.lfm                      # Layout do formulário móvel
└── pc_vcl_server/                                # Servidor Desktop no PC
    ├── ServerLazarus.lpi / .lpr                  # Projeto nativo Lazarus (FPC)
    ├── ULazarusWebServer.pas / .lfm              # Servidor FPC com TFPHttpServer e UserControl
    ├── ServerVCL.dpr                             # Projeto nativo Delphi Win64
    ├── UWebServerVCL.pas / .dfm                  # Servidor Delphi com Indy TIdHTTPServer
    └── UUserControlBiometria.pas                 # Núcleo de Permissões RBAC e Usuários
```
