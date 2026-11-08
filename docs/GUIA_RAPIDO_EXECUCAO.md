# Guia Rápido de Execução e Resolução de Problemas
**Conect Solutions TI** — Engenharia de Sistemas Distribuídos e Mobile Cross-Platform

Este guia rápido explica como executar a solução passo a passo e resolver eventuais problemas de rede local, USB ou permissões.

---

## 1. Execução em 3 Passos

### Passo 1: Iniciar o Servidor no PC
Abra a pasta `c:\Projetos Antigrtavity\Biometria Lazarus\pc_vcl_server\` e execute:
* Dê duplo clique em **`ServerLazarus.exe`** (ou abra o projeto `ServerLazarus.lpi` no Lazarus e aperte **F9**).
* A janela do servidor será exibida com o painel em **Vermelho** (*"SISTEMA BLOQUEADO - AGUARDANDO BIOMETRIA"*), escutando na porta **8080**.

### Passo 2: Abrir o App no Smartphone
* Desbloqueie o celular Android conectado à mesma rede Wi-Fi (ou via cabo USB).
* Abra o aplicativo **"Biometria Conect"**.
* O app já virá pré-configurado com o IP local do seu computador (ex: `192.168.15.119` ou `127.0.0.1`) e o usuário `mauricio`.

### Passo 3: Tocar na Digital e Confirmar o Acesso
* Toque no botão **`VALIDAR BIOMETRIA E LIBERAR VCL`**.
* O diálogo nativo da Samsung / Android aparecerá na tela.
* Encoste o dedo cadastrado no leitor biométrico.
* **Resultado:**
  - O celular exibirá status **Verde** (*"ACESSO LIBERADO NO SISTEMA VCL COM SUCESSO!"*).
  - A janela do PC mudará instantaneamente para **Verde Esmeralda** com som de confirmação e registrará o log do usuário e do IP de origem.

---

## 2. Resolução de Problemas Comuns (Troubleshooting)

### A. "Falha de conexão / Connection Timed Out"
* **Causa 1 (Firewall do Windows bloqueando a porta 8080):**
  Abra o Prompt de Comando como Administrador e execute:
  ```cmd
  netsh advfirewall firewall add rule name="Servidor Biometrico VCL Conect" dir=in action=allow protocol=TCP localport=8080
  ```
* **Causa 2 (Isolamento de Ponto de Acesso no Wi-Fi - AP Isolation):**
  Alguns roteadores Wi-Fi corporativos impedem que dois dispositivos sem fio conversem entre si.
  * *Solução rápida:* Conecte o celular via cabo USB e execute no terminal do PC:
    ```powershell
    adb reverse tcp:8080 tcp:8080
    ```
    No campo IP do aplicativo no celular, digite `127.0.0.1`. A conexão passará pelo cabo USB com latência zero.

### B. "Nenhuma digital cadastrada no aparelho (Código: 11)"
* O Android acusa que não há biometrias configuradas no sistema operacional.
* Acesse as **Configurações do Android ➔ Tela de Bloqueio e Segurança ➔ Impressões Digitais** e cadastre ao menos uma digital.

### C. "Dispositivo não possui sensor biométrico (Código: 12)"
* O aparelho não dispõe de hardware leitor de impressão digital ou reconhecimento facial compatível com `BiometricPrompt`.

---

## 3. Teste Rápido via Linha de Comando (Sem o celular em mãos)

Para simular o disparo biométrico e testar o servidor do PC a qualquer momento, abra o PowerShell no PC e rode:

```powershell
Invoke-RestMethod -Uri "http://localhost:8080/biometria-sucesso" `
  -Method POST `
  -Headers @{ "Content-Type" = "application/json; charset=utf-8" } `
  -Body '{"user": "mauricio", "status": "approved", "device_id": "TESTE-PC"}'
```

O servidor registrará a autenticação do usuário "Maurício Oliveira" com nível Administrador e liberará a interface imediatamente.

