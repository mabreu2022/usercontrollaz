object frmBiometricServer: TfrmBiometricServer
  Left = 0
  Top = 0
  Caption = 'Conect Solutions TI - Servidor Biométrico VCL'
  ClientHeight = 480
  ClientWidth = 640
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlHeader: TPanel
    Left = 0
    Top = 0
    Width = 640
    Height = 70
    Align = alTop
    BevelOuter = bvNone
    Color = 2960685
    ParentBackground = False
    TabOrder = 0
    object lblTitulo: TLabel
      Left = 20
      Top = 12
      Width = 371
      Height = 25
      Caption = 'Autentica'#231#227'o Biom'#233'trica Mobile -> VCL'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -19
      Font.Name = 'Segoe UI Semibold'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblSubtitulo: TLabel
      Left = 20
      Top = 40
      Width = 384
      Height = 15
      Caption = 'Recep'#231#227'o de credenciais biom'#233'tricas Android em rede local via Indy HTTP'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 13816530
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object pnlStatus: TPanel
    Left = 20
    Top = 85
    Width = 600
    Height = 100
    BevelOuter = bvNone
    Color = 2829270
    ParentBackground = False
    TabOrder = 1
    object lblStatusAcesso: TLabel
      Left = 16
      Top = 18
      Width = 359
      Height = 20
      Caption = 'SISTEMA BLOQUEADO - AGUARDANDO BIOMETRIA'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -15
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object lblUsuarioAutenticado: TLabel
      Left = 16
      Top = 46
      Width = 230
      Height = 15
      Caption = 'Nenhum usu'#225'rio autenticado no momento'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clSilver
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblIPPorta: TLabel
      Left = 16
      Top = 70
      Width = 205
      Height = 15
      Caption = 'Servidor Inicializando na Porta 8080...'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 14474460
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
  end
  object mmoLogs: TMemo
    Left = 20
    Top = 200
    Width = 600
    Height = 220
    Color = 1973790
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 10354425
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object btnIniciarServidor: TButton
    Left = 20
    Top = 435
    Width = 140
    Height = 32
    Caption = 'Reiniciar Servidor'
    TabOrder = 3
    OnClick = btnIniciarServidorClick
  end
  object btnPararServidor: TButton
    Left = 175
    Top = 435
    Width = 140
    Height = 32
    Caption = 'Parar Servidor'
    TabOrder = 4
    OnClick = btnPararServidorClick
  end
  object IdHTTPServer: TIdHTTPServer
    Bindings = <>
    DefaultPort = 8080
    OnCommandGet = IdHTTPServerCommandGet
    Left = 560
    Top = 430
  end
end

