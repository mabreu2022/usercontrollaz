# Módulo 3: O Servidor HTTP no PC (VCL & LCL)
**Conect Solutions TI** — Engenharia de Sistemas Distribuídos e Mobile Cross-Platform

Este módulo implementa o microsserviço receptor HTTP que roda no computador desktop do usuário, escuta conexões locais na porta `8080`, processa a aprovação biométrica e atualiza a interface gráfica do sistema principal imediatamente.

---

## 1. Dois Ambientes Suportados

Para garantir total flexibilidade técnica na Conect Solutions TI, fornecemos implementações compatíveis com as duas principais plataformas de desenvolvimento Object Pascal no Windows:

| Plataforma | Projeto | Servidor HTTP | Dependências Externas |
| :--- | :--- | :--- | :--- |
| **Lazarus / Free Pascal (LCL)** | `ServerLazarus.lpi` | `TFPHttpServer` (fcl-web) | **Nenhuma** (incluso no RTL padrão do FPC) |
| **Delphi / Embarcadero (VCL)** | `ServerVCL.dpr` | `TIdHTTPServer` (Indy 10) | Biblioteca padrão Indy do RAD Studio |

---

## 2. A Implementação Nativa Lazarus (`ServerLazarus.lpi`)

A unit [ULazarusWebServer.pas](../pc_vcl_server/ULazarusWebServer.pas) utiliza o componente nativo `TFPHttpServer` executado dentro de uma `TThread` dedicada:

```pascal
procedure TServerThread.HandleRequest(Sender: TObject;
  var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  if SameText(ARequest.PathInfo, '/biometria-sucesso') then
  begin
    // Extração do payload JSON {"user":"mauricio", "status":"approved"}
    ...
    // Sincronização segura com a Thread Principal do Lazarus
    TThread.Queue(nil, @DoLiberarAcessoMainThread);

    // Resposta HTTP 200 OK
    AResponse.Code := 200;
    AResponse.ContentType := 'application/json; charset=utf-8';
    AResponse.Content := '{"code": 200, "result": "access_granted"}';
  end;
end;
```

---

## 3. A Implementação Delphi VCL (`ServerVCL.dpr`)

A unit [UWebServerVCL.pas](../pc_vcl_server/UWebServerVCL.pas) utiliza o `TIdHTTPServer` tratando o evento `OnCommandGet`:

```pascal
procedure TfrmBiometricServer.IdHTTPServerCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  if SameText(ARequestInfo.Document, '/biometria-sucesso') then
  begin
    // Decodificação segura do stream UTF-8
    ...
    // Enfileira a atualização visual na Thread Principal
    TThread.Queue(nil, DoLiberarAcessoMainThread);

    AResponseInfo.ResponseNo := 200;
    AResponseInfo.ContentType := 'application/json; charset=utf-8';
    AResponseInfo.ContentText := '{"code": 200, "result": "access_granted"}';
  end;
end;
```

---

## 4. Regra Crítica de Segurança de Concorrência (`TThread.Queue`)

> [!CAUTION]
> Servidores de rede HTTP operam com **Worker Threads** (linhas de execução secundárias por conexão). Componentes visuais do Windows (Forms, Labels, Panels, Grids) **NUNCA** podem ser modificados diretamente de dentro do evento do socket. Fazer isso gera violações de acesso aleatórias (*Access Violation*) ou congelamento irreversível da tela (*Deadlock*).

### Por que usamos `TThread.Queue` em vez de `TThread.Synchronize`?
* `TThread.Synchronize`: Pausa a worker thread do socket e espera até que a Thread Principal termine de desenhar a tela para só então devolver a resposta HTTP. Se a tela estiver ocupada ou exibindo uma caixa de diálogo, o socket pode expirar (*Timeout*) no celular.
* `TThread.Queue`: **É assíncrono e não-bloqueante**. O servidor enfileira a atualização na fila de mensagens do Windows e responde `200 OK` para o celular imediatamente em menos de 10 milissegundos.

---

## 5. Liberação no Firewall do Windows

Para autorizar o tráfego de entrada na porta TCP `8080`, execute no Prompt de Comando do Windows (como Administrador):

```cmd
netsh advfirewall firewall add rule name="Servidor Biometrico VCL Conect" dir=in action=allow protocol=TCP localport=8080
```

