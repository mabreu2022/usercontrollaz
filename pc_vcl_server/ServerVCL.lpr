program ServerVCL;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  UWebServerVCL in 'UWebServerVCL.pas' {frmBiometricServer};

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TfrmBiometricServer, frmBiometricServer);
  Application.Run;
end.

