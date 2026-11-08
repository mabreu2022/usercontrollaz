-- =============================================================================
-- Conect Solutions TI - Script DDL do UserControl com Biometria Móvel
-- Compatível com: PostgreSQL, Firebird (3.0+), MySQL/MariaDB e SQLite
-- =============================================================================

-- 1. TABELA DE USUÁRIOS E VÍNCULO DE HARDWARE MOBILE (RBAC)
CREATE TABLE tb_usuarios (
    id INTEGER NOT NULL PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    login VARCHAR(50) NOT NULL UNIQUE,
    senha_hash VARCHAR(128),                    -- Hash SHA-256 para contingência
    nivel_acesso INTEGER NOT NULL DEFAULT 2,     -- 1: Consulta, 2: Operador, 3: Gerente, 4: Admin
    device_id VARCHAR(150),                     -- UUID exclusivo do smartphone emparelhado
    biometria_ativa CHAR(1) DEFAULT 'N',        -- 'S' ou 'N'
    ativo CHAR(1) DEFAULT 'S',                  -- 'S' ou 'N'
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_ultimo_acesso TIMESTAMP
);

-- 2. TABELA DE AUDITORIA E LOGS DE EVENTOS BIOMÉTRICOS (COMPLIANCE / LGPD)
CREATE TABLE tb_biometria_logs (
    id INTEGER NOT NULL PRIMARY KEY,
    usuario_id INTEGER NOT NULL,
    login VARCHAR(50) NOT NULL,
    data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    operacao VARCHAR(50) NOT NULL,              -- 'login', 'aprovacao_pdv', 'desconto', 'estorno'
    resultado VARCHAR(20) NOT NULL,             -- 'approved', 'denied', 'error'
    ip_origem VARCHAR(45) NOT NULL,             -- IPv4 ou IPv6 do smartphone
    device_id VARCHAR(150),                     -- Identificador do aparelho que validou a digital
    detalhes VARCHAR(255),                      -- Ex: 'Desconto de 25% no Caixa 01'
    CONSTRAINT fk_bio_usuario FOREIGN KEY (usuario_id) REFERENCES tb_usuarios(id)
);

-- 3. TABELA DE SOLICITAÇÕES PENDENTES (2FA REMOTO / PDV)
CREATE TABLE tb_solicitacoes_pendentes (
    token_desafio VARCHAR(64) NOT NULL PRIMARY KEY, -- Token de uso único (UUID/Nonce)
    terminal_origem VARCHAR(50) NOT NULL,           -- Ex: 'CAIXA_01'
    descricao_operacao VARCHAR(200) NOT NULL,       -- Ex: 'Desconto R$ 150,00'
    nivel_minimo INTEGER NOT NULL DEFAULT 3,         -- Exige Gerente (3) ou Admin (4)
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_expiracao TIMESTAMP NOT NULL,              -- Validade de 60 segundos
    status VARCHAR(20) DEFAULT 'PENDENTE',          -- 'PENDENTE', 'APROVADO', 'EXPIRADO', 'RECUSADO'
    aprovado_por_usuario VARCHAR(50)
);

-- ÍNDICES DE PERFORMANCE PARA CONSULTAS EM TEMPO REAL
CREATE INDEX idx_tb_usuarios_login ON tb_usuarios(login);
CREATE INDEX idx_tb_usuarios_device ON tb_usuarios(device_id);
CREATE INDEX idx_tb_biometria_logs_data ON tb_biometria_logs(data_hora);
CREATE INDEX idx_tb_solicitacoes_status ON tb_solicitacoes_pendentes(status, data_expiracao);

-- DADOS INICIAIS PADRÃO PARA IMPLANTAÇÃO IMEDIATA
INSERT INTO tb_usuarios (id, nome, login, nivel_acesso, device_id, biometria_ativa, ativo) 
VALUES (1, 'Maurício Oliveira', 'mauricio', 4, 'SM-G780G', 'S', 'S');

INSERT INTO tb_usuarios (id, nome, login, nivel_acesso, device_id, biometria_ativa, ativo) 
VALUES (2, 'Carlos Gerência', 'carlos.gerente', 3, NULL, 'N', 'S');

INSERT INTO tb_usuarios (id, nome, login, nivel_acesso, device_id, biometria_ativa, ativo) 
VALUES (3, 'Ana Operadora Caixa', 'ana.caixa', 2, NULL, 'N', 'S');

