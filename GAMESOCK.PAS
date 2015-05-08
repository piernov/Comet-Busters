unit GameSock;

interface

uses
  Objects, IMath, WinTypes, WinProcs, Win31, Messages;

const
  MaxBuffers = 16;
const
{ TStream error codes }

  stOk         =  0;              { No error }
  stError      = -1;              { Access error }
  stInitError  = -2;              { Cannot initialize stream }
  stReadError  = -3;              { Read beyond end of stream }
  stWriteError = -4;              { Cannot expand stream }
  stGetError   = -5;              { Get of unregistered object type }
  stPutError   = -6;              { Put of unregistered object type }

type
  TFOURCC = array[0..3] of char;

  TIdleProc = function : boolean;

  PGameSocket = ^TGameSocket;
  TGameSocket = object
    Status : integer;
    ErrorInfo : integer;
    MsgID : TFOURCC;
    PortNum : word;
    MaxDataSize : word;
    IdleFunc : TIdleProc;
    constructor Init(ASocketNum : word; const AMsgID : TFOURCC;
      AMaxDataSize : word);
    destructor Done; virtual;
    function ReadPacket(var Buf; Count: Word) : word; virtual;
    procedure WritePacket(var Buf; Count : word); virtual;
    procedure Read(var Buf; Count : word); virtual;
    procedure SetNotify(Wnd : HWnd; NumRead, NumWrite : integer; EvtMask : word);
    procedure Idle; virtual;
    function Cancelled : boolean; virtual;
    function Sleep(MSec : longint) : boolean;
    procedure Error(Code, Info: Integer);
  private
    NotifyWnd : THandle;
    procedure Notify;
  end;

implementation

procedure TGameSocket.Error(Code, Info: Integer);
begin
  Status := Code;
  ErrorInfo := Info;
end;

procedure TGameSocket.Read(var Buf; Count : word);
const
  ReadTimeOut = 60000;
var
  p : PChar;
  BytesRead : integer;
  Time : longint;
begin
  Time := GetTickCount;
  p := @Buf;
  while (Count > 0) and not Cancelled do begin
    BytesRead := ReadPacket(p^, Count);
    if not (Status = stOk) then
      Exit;
    dec(Count, BytesRead);
    inc(p, BytesRead);
    if (Count > 0) and (GetTickCount-Time > ReadTimeOut) then begin
      Status := stReadError;
      Exit;
    end;
  end;
end;

(*
function TGameSocket.ReadPacket(var Buf; Count: Word) : word;
begin
  Abstract;
end;

procedure TGameSocket.WritePacket(var Buf; Count: Word);
begin
  Abstract;
end;

procedure TGameSocket.Idle;
begin
  Abstract;
end;
*)

destructor TGameSocket.Done;
begin
end;

constructor TGameSocket.Init(ASocketNum : word; const AMsgID : TFOURCC;
  AMaxDataSize : word);
begin
  MsgID := AMsgID;
  PortNum := ASocketNum;
  MaxDataSize := AMaxDataSize;
  IdleFunc := nil;
end;

procedure TGameSocket.SetNotify(Wnd : HWnd; NumRead, NumWrite : integer;
  EvtMask : word);
begin
  NotifyWnd := Wnd;
end;

procedure TGameSocket.Notify;
begin
  PostMessage(NotifyWnd, WM_COMMNOTIFY, 0, 0);
end;

function TGameSocket.Cancelled : boolean;
begin
  if @IdleFunc = nil then
    Cancelled := false
  else begin
    Cancelled := IdleFunc;
    if Result and (Status = 0) then Status := -1;
  end;
end;

function TGameSocket.Sleep(MSec : longint) : boolean;
var
  ExitCond : boolean;
  Time : longint;
begin
  ExitCond := false;
  Time := GetTickCount;
  repeat
    ExitCond := Cancelled;
  until ExitCond or (GetTickCount-Time > MSec);
  Sleep := not ExitCond;
end;

function TGameSocket.ReadPacket(var Buf; Count: Word) : word;
begin
  RunError(211);
end;

procedure TGameSocket.WritePacket(var Buf; Count : word);
begin
  RunError(211);
end;

procedure TGameSocket.Idle;
begin
  RunError(211);
end;

end.
