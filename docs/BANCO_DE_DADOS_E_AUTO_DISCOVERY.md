# Banco de Dados & Descoberta Automática de Rede (Zero-Config)
**Conect Solutions TI** — Engenharia de Sistemas Distribuídos e Mobile Cross-Platform

Este documento detalha o modelo relacional de banco de dados para sistemas ERP/PDV e o protocolo de autodescoberta de IP via UDP Broadcast.

---

## 1. Modelo de Banco de Dados Relacional (SQL DDL)

O arquivo [schema_usercontrol.sql](../pc_vcl_server/schema_usercontrol.sql) fornece as tabelas prontas para integração em bancos de dados corporativos (PostgreSQL, Firebird, MySQL, SQL Server ou SQLite).

### 1.1. Tabela `tb_usuarios`
Armazena as credenciais de login, nível hierárquico (RBAC) e o identificador do smartphone emparelhado:
* `id`: Chave primária inteira.
* `nome`: Nome completo do colaborador.
* `login`: Login de acesso único (ex: `'mauricio'`).
* `nivel_acesso`: Nível operacional (1: Consulta, 2: Operador, 3: Gerente, 4: Administrador).
* `device_id`: Identificador único do smartphone (ex: `'SM-G780G-9A283B'`).
* `biometria_ativa`: Flag indicando se a digital já foi cadastrada (`'S'` ou `'N'`).

### 1.2. Tabela `tb_biometria_logs` (Auditoria e Compliance LGPD)
Registra cada tentativa de liberação biométrica no sistema para fins de auditoria de caixa e segurança:
* Data e hora exata com precisão de milissegundos.
* Login e ID do colaborador.
* Tipo de operação: `'login'`, `'aprovacao_pdv'`, `'desconto'`, `'estorno'`.
* Resultado: `'approved'` ou `'denied'`.
* IP de origem e `device_id` do smartphone que assinou a operação.

### 1.3. Tabela `tb_solicitacoes_pendentes` (2FA para PDV)
Controla os desafios de segurança gerados pelos caixas:
* `token_desafio`: Nonce / UUID de uso único gerado pelo PDV.
* `terminal_origem`: Identificador do caixa (ex: `'CAIXA_01'`).
* `descricao_operacao`: Ex: `'Desconto de 25% (R$ 150,00)'`.
* `nivel_minimo`: Nível exigido para aprovar (ex: `3` para Gerente).
* `data_expiracao`: Timestamp com validade máxima de 60 segundos (previne ataques de repetição).

---

## 2. Protocolo de Descoberta Automática (UDP Broadcast)

Em ambientes de varejo ou escritórios com roteadores DHCP, o endereço IP do PC pode mudar. Para que o operador não precise digitar o IP manualmente:

### Fluxo do Handshake UDP:
1. O PC mantém uma thread ouvindo a porta UDP `8082` ([`UDiscoveryService.pas`](../pc_vcl_server/UDiscoveryService.pas)).
2. O aplicativo Android dispara um pacote UDP Broadcast na sub-rede (`255.255.255.255:8082`) com a mensagem:
   `CONECT_BIOMETRIC_DISCOVERY_PING`
3. O servidor no PC recebe o ping e responde diretamente ao IP do smartphone com:
   `CONECT_BIOMETRIC_DISCOVERY_PONG|8080|ConectBiometricServer`
4. O smartphone extrai automaticamente o IP de origem do pacote UDP e preenche o campo de IP sem nenhuma digitação manual do usuário.

