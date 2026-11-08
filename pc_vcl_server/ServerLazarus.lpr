program ServerLazarus;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // LCL widgetset
  Forms,
  ULazarusWebServer in 'ULazarusWebServer.pas' {frmBiometricServerLazarus};

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TfrmBiometricServerLazarus, frmBiometricServerLazarus);
  Application.Run;
end.

