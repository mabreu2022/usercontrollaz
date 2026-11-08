object ConectBiometricService: TConectBiometricService
  OldCreateOrder = False
  DisplayName = 'Conect Solutions - Servidor de Autentica'#231#227'o Biom'#233'trica'
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 215
  object IdHTTPServer: TIdHTTPServer
    Bindings = <>
    DefaultPort = 8080
    OnCommandGet = IdHTTPServerCommandGet
    Left = 80
    Top = 48
  end
end

