unit UDiscoveryService;

{$IFDEF FPC}
  {$mode objfpc}{$H+}
{$ENDIF}

interface

uses
  Classes, SysUtils,
  {$IFDEF FPC}
  sockets
  {$ELSE}
  Winapi.Winsock2, Winapi.Windows
  {$ENDIF};

const
  DISCOVERY_BROADCAST_PORT = 8082;
  DISCOVERY_REQUEST_MAGIC  = 'CONECT_BIOMETRIC_DISCOVERY_PING';
  DISCOVERY_RESPONSE_MAGIC = 'CONECT_BIOMETRIC_DISCOVERY_PONG';

type
  { Thread de Descoberta Automática de IP via UDP Broadcast }
  TDiscoveryServerThread = class(TThread)
  private
    FHttpPort: Integer;
    FRunning: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AHttpPort: Integer);
    procedure StopDiscovery;
  end;

implementation

constructor TDiscoveryServerThread.Create(AHttpPort: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FHttpPort := AHttpPort;
  FRunning := True;
  Resume;
end;

procedure TDiscoveryServerThread.StopDiscovery;
begin
  FRunning := False;
  Terminate;
end;

procedure TDiscoveryServerThread.Execute;
{$IFDEF MSWINDOWS}
var
  WSAData: TWSAData;
  Sock: TSocket;
  Addr, ClientAddr: TSockAddrIn;
  ClientAddrLen, BytesRead: Integer;
  Buffer: array[0..512] of AnsiChar;
  ResponseMsg: AnsiString;
begin
  if WSAStartup(MAKEWORD(2, 2), WSAData) <> 0 then Exit;

  Sock := socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if Sock = INVALID_SOCKET then
  begin
    WSACleanup;
    Exit;
  end;

  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(DISCOVERY_BROADCAST_PORT);
  Addr.sin_addr.s_addr := INADDR_ANY;

  if bind(Sock, TSockAddr(Addr), SizeOf(Addr)) = SOCKET_ERROR then
  begin
    closesocket(Sock);
    WSACleanup;
    Exit;
  end;

  while not Terminated and FRunning do
  begin
    ClientAddrLen := SizeOf(ClientAddr);
    BytesRead := recvfrom(Sock, Buffer[0], SizeOf(Buffer) - 1, 0, TSockAddr(ClientAddr), ClientAddrLen);
    if BytesRead > 0 then
    begin
      Buffer[BytesRead] := #0;
      if Pos(DISCOVERY_REQUEST_MAGIC, string(Buffer)) > 0 then
      begin
        // Responde ao celular com a porta HTTP ativa
        ResponseMsg := AnsiString(Format('%s|%d|ConectBiometricServer', [DISCOVERY_RESPONSE_MAGIC, FHttpPort]));
        sendto(Sock, ResponseMsg[1], Length(ResponseMsg), 0, TSockAddr(ClientAddr), ClientAddrLen);
      end;
    end;
    Sleep(50);
  end;

  closesocket(Sock);
  WSACleanup;
end;
{$ELSE}
begin
  // Em Linux / Posix, usa sockets padrão
end;
{$ENDIF}

end.

