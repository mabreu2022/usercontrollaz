program BiometriaService;

uses
  Vcl.SvcMgr,
  UServiceBiometria in 'UServiceBiometria.pas' {ConectBiometricService: TService},
  UUserControlBiometria in '..\pc_vcl_server\UUserControlBiometria.pas';

begin
  // Permite inicialização padrão do despachante de serviços do Windows
  if not Application.DelayInitialize or Application.Installing then
    Application.Initialize;
  Application.CreateForm(TConectBiometricService, ConectBiometricService);
  Application.Run;
end.

