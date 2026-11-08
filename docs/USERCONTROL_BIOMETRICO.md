# Módulo 4: UserControl Biométrico e Controle de Acessos (RBAC)
**Conect Solutions TI** — Engenharia de Sistemas Distribuídos e Mobile Cross-Platform

A unit [UUserControlBiometria.pas](../pc_vcl_server/UUserControlBiometria.pas) implementa um controle de usuários corporativo moderno com controle de acesso baseado em papéis (**RBAC - Role-Based Access Control**), vínculo criptográfico de aparelho móvel (`DeviceId`) e aprovação remota de privilégios em tempo real.

---

## 1. Níveis de Acesso Hierárquicos (`TNivelAcesso`)

O sistema define quatro patamares operacionais:

```pascal
type
  TNivelAcesso = (
    naConsulta = 1,       // Apenas leitura e emissão de relatórios
    naOperador = 2,       // Vendas normais, abertura/fechamento de caixa
    naGerente = 3,        // Descontos acima do limite, estornos e cancelamentos
    naAdministrador = 4   // Gestão total de usuários, biometrias e configurações
  );
```

A hierarquia é aritmética (`naAdministrador > naGerente > naOperador > naConsulta`):
Um usuário de nível `naGerente` (3) possui autorização automática para todas as operações de nível `naOperador` (2) e `naConsulta` (1), mas é bloqueado em tarefas que exigem `naAdministrador` (4).

---

## 2. Vínculo de Hardware Seguro (`DeviceId`)

Para evitar fraudes (por exemplo, um funcionário usar as credenciais de login de um gerente em seu próprio celular), cada usuário possui uma amarração com o identificador exclusivo do aparelho:

* **No Android:** Obtido a partir de `Settings.Secure.ANDROID_ID` ou do identificador persistente do dispositivo.
* **No PC (UserControl):** O método `ValidarAcesso` compara se o `DeviceId` enviado na requisição HTTP confere com o registrado no cadastro:

```pascal
if (U.DeviceId <> '') and (ADeviceId <> '') and not SameText(U.DeviceId, ADeviceId) then
begin
  AErrorMsg := 'Acesso negado: Dispositivo mobile não autorizado para este usuário.';
  Exit(False);
end;
```

---

## 3. Fluxo de Emparelhamento de Nova Biometria

Quando um novo funcionário é admitido ou troca de smartphone:

1. O Administrador acessa a tela de usuários no PC e clica em **"Cadastrar Nova Biometria"**.
2. O sistema gera um **PIN temporário de 6 dígitos** (com validade de 2 minutos).
3. O funcionário abre o app no celular, digita o seu login e o PIN gerado, e encosta o dedo no sensor de digital.
4. O app envia o POST HTTP:
   ```json
   {
     "user": "ana.caixa",
     "pin": "748921",
     "device_id": "SM-G780G-9A283B",
     "status": "approved"
   }
   ```
5. O servidor valida o PIN e chama `GUserManager.VincularDispositivo('ana.caixa', 'SM-G780G-9A283B')`.
6. O celular fica definitivamente registrado e pronto para liberar o sistema no dia a dia.

---

## 4. Elevação de Privilégios (2FA On-Demand para Caixa/PDV)

Além da liberação do login inicial do sistema, o UserControl atende ao caso de uso clássico de supermercados, farmácias e lojas de varejo: **aprovação remota de supervisor**.

### Cenário de Uso:
1. O operador de caixa tenta registrar um **desconto de 30%** ou **cancelar um item já bipado**.
2. O sistema do caixa bloqueia a ação e exibe: *"Aguardando aprovação biométrica do Gerente"*.
3. O Gerente recebe uma notificação ou seleciona a opção no seu celular corporativo e encosta a digital.
4. O servidor recebe o POST, valida que `U.Nivel >= naGerente` e libera o desconto na tela do caixa imediatamente.
5. O gerente **não precisou ir fisicamente até o caixa** nem digitar senhas vulneráveis que poderiam ser visualizadas por clientes.

---

## 5. Estrutura de Persistência em JSON (`usuarios_usercontrol.json`)

Os usuários são mantidos em formato JSON desacoplado, permitindo que a solução seja plugada em qualquer banco de dados existente (PostgreSQL, Firebird, MySQL, SQL Server ou SQLite):

```json
[
  {
    "id": 1,
    "nome": "Maurício Oliveira",
    "login": "mauricio",
    "nivel": "Administrador",
    "nivel_code": 4,
    "biometria_ativa": true,
    "ativo": true,
    "device_id": "SM-G780G"
  },
  {
    "id": 2,
    "nome": "Carlos Gerência",
    "login": "carlos.gerente",
    "nivel": "Gerente",
    "nivel_code": 3,
    "biometria_ativa": true,
    "ativo": true,
    "device_id": ""
  },
  {
    "id": 3,
    "nome": "Ana Operadora Caixa",
    "login": "ana.caixa",
    "nivel": "Operador",
    "nivel_code": 2,
    "biometria_ativa": false,
    "ativo": true,
    "device_id": ""
  }
]
```
