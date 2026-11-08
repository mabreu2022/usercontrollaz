program ServerVCL;

uses
  Vcl.Forms,
  UWebServerVCL in 'UWebServerVCL.pas' {frmBiometricServer};

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Conect Solutions - Servidor Biometrico VCL';
  Application.CreateForm(TfrmBiometricServer, frmBiometricServer);
  Application.Run;
end.

