# Arquitetura da Solução de Autenticação Biométrica
**Conect Solutions TI** — Engenharia de Sistemas Distribuídos e Mobile Cross-Platform

---

## 1. Visão Geral

A solução permite que um operador ou usuário corporativo utilize o sensor de impressão digital de seu smartphone Android para liberar instantaneamente o acesso ou aprovar operações restritas em um sistema Desktop Windows (desenvolvido em **Lazarus LCL** ou **Delphi VCL**).

A comunicação ocorre estritamente dentro da rede local da empresa (via Wi-Fi ou túnel USB/ADB), eliminando a dependência de servidores de nuvem externos e garantindo latência de milissegundos e soberania total dos dados.

```mermaid
graph TD
    subgraph Dispositivo_Mobile["Dispositivo Móvel (Android)"]
        Sensor["Sensor Biométrico (Digital)"] --> BP["AndroidX BiometricPrompt"]
        BP --> JavaHelper["BiometricHelper.java"]
        JavaHelper --> JNI["Ponte JNI (cdecl)"]
        JNI --> CompPascal["TNetworkBiometricAuth (FPC)"]
        CompPascal --> HttpWorker["Worker Thread Assíncrona (TThread)"]
    end

    subgraph Rede_Local["Rede Local / Wi-Fi Corporativo"]
        HttpWorker -- "POST /biometria-sucesso (JSON)" --> HttpEndpoint["Porta TCP :8080"]
    end

    subgraph Computador_Desktop["Computador Desktop (PC Windows)"]
        HttpEndpoint --> ServidorHTTP["Servidor HTTP (Lazarus / Indy)"]
        ServidorHTTP --> UserControl["UserControl (RBAC / DeviceID)"]
        UserControl --> SyncUI["TThread.Queue (Thread Principal)"]
        SyncUI --> TelaVCL["Interface Gráfica (Liberada!)"]
    end
```

---

## 2. Diagrama de Sequência Detalhado

```mermaid
sequenceDiagram
    autonumber
    actor Operador as Usuário / Operador
    participant App as App Android (Lazarus/Java)
    participant HW as Hardware Biométrico
    participant PCServer as Servidor HTTP PC (:8080)
    participant UC as Módulo UserControl (PC)
    participant VCLUI as Interface Desktop (Main Thread)

    Operador->>App: Clica em "Validar Biometria"
    App->>HW: BiometricHelper.showBiometricPrompt()
    HW->>Operador: Exibe diálogo de digital nativo
    Operador->>HW: Encosta a digital no sensor
    HW->>App: onAuthenticationSucceeded()
    Note over App: Inicia Worker Thread em background
    App->>PCServer: POST /biometria-sucesso<br/>Payload: {"user":"mauricio", "status":"approved", "device_id":"SM-G780G"}
    PCServer->>UC: ValidarAcesso("mauricio", "SM-G780G", naOperador)
    alt Usuário e Dispositivo Válidos
        UC-->>PCServer: Acesso Autorizado (Nível: Administrador)
        PCServer->>VCLUI: TThread.Queue(DoLiberarAcessoMainThread)
        VCLUI-->>Operador: Painel muda para VERDE (Acesso Liberado)
        PCServer-->>App: HTTP 200 OK {"result":"access_granted", "nivel":"Administrador"}
        App-->>Operador: Alerta sonoro e mensagem de sucesso
    else Dispositivo Não Autorizado ou Biometria Inválida
        UC-->>PCServer: Acesso Recusado
        PCServer-->>App: HTTP 403 Forbidden {"result":"denied"}
        App-->>Operador: Exibe erro no celular
    end
```

---

## 3. Topologia de Rede e Meios de Comunicação

A solução suporta dois canais de transporte de rede:

### 3.1. Rede Sem Fio (Wi-Fi Local)
* O celular Android e o PC Desktop conectam-se ao mesmo roteador ou switch corporativo na mesma sub-rede (ex: `192.168.15.x`).
* O app dispara as requisições diretamente para o IP local do computador:
  `http://192.168.15.119:8080/biometria-sucesso`.
* **Requisito:** A opção *AP Isolation* (Isolamento de Clientes) do ponto de acesso Wi-Fi deve estar desativada.

### 3.2. Cabo USB com Port Forwarding Reverso (Zero Wi-Fi / Alta Confiabilidade)
* Útil para terminais de caixa (PDV) onde o Wi-Fi não está disponível ou há restrições de segurança.
* O celular permanece conectado via cabo USB com Depuração USB ativada.
* O comando do ADB mapeia a porta:
  ```powershell
  adb reverse tcp:8080 tcp:8080
  ```
* O celular passa a se comunicar com o PC através de `http://127.0.0.1:8080/biometria-sucesso` com latência inferior a 5 milissegundos e imune a oscilações de sinal de rádio.

---

## 4. Segurança e Integridade

1. **Proteção contra travamento no Android (`NetworkOnMainThreadException`)**:
   Todas as requisições de rede no Android são executadas em threads secundárias dedicadas (`TThread` no Pascal ou `ExecutorService` no Java).
2. **Proteção contra corrupção visual no Windows (Thread Safety)**:
   Os componentes de interface da VCL e LCL não aceitam modificações de threads secundárias do socket. O envio de dados para a interface é enfileirado estritamente na Thread Principal via `TThread.Queue`.
3. **Tráfego HTTP sem SSL em Rede Local (`usesCleartextTraffic`)**:
   O `AndroidManifest.xml` foi configurado explicitamente para aceitar HTTP plano (`android:usesCleartextTraffic="true"`), dispensando a necessidade de instalar certificados SSL autoassinados em cada PC de desenvolvimento.

