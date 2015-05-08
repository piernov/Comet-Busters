unit Modem;
{$Q-}

interface

uses
  WinTypes, WinProcs, Objects, Strings,
  {$IFNDEF VER80}Win31, {$ENDIF}DynArr, GameSock;

type
  PCommStream = ^TCommStream;
  TCommStream = object(TGameSocket)
    {$IFDEF commfile}
    INF,OUTF : TBufStream;
    {$ENDIF}
    constructor Init(Port : byte; InQueue, OutQueue : word);
    destructor Done; virtual;
    function ReadBytes(var Buf; Count : word) : word; virtual;
    procedure Unread(Ch : char); virtual;
    procedure Write(var Buf; Count : word); virtual;
    procedure WriteText(Txt : PChar); virtual;
{    procedure SetNotify(Wnd : HWnd; NumRead, NumWrite : integer; EvtMask : word);}
  private
    Handle : integer;
    function CheckError : boolean;
  end;

  TIdleProc = function : boolean;

  PModemStream = ^TModemStream;
  TModemStream = object(TCommStream)
    Onhook : boolean;
    constructor Init(Port : byte);
    destructor Done; virtual;
    procedure SetParams(Params : PChar);
    function InitModem(InitString : PChar) : integer;
    function Dial(DialString : PChar) : integer;
    function Answer : boolean;
    function Connect : boolean;
    function Disconnect : boolean;
    function WaitFor(const Results : array of PChar; MSec : longint) : integer;
    procedure WriteTextSlowly(Txt : PChar; MSec : word);
  end;

  PModemPktStream = ^TModemPktStream;
  TModemPktStream = object(TModemStream)
    constructor Init(Port : byte);
    function ReadPacket(var Buf; Count: Word) : word; virtual;
    procedure WritePacket(var Buf; Count : word); virtual;
  private
    pktbuf : array[0..256] of byte;
    pktbufpos : integer;
  end;

implementation

const
  ReadTimeOut = 5000;
  CRLF = #13;
  ModemResults : array[0..7] of PChar =
    ('OK'+#13,'RING'+#13,'CONNECT',
     'ERROR'+#13,'NO CARRIER'+#13,'VOICE'+#13,'BUSY'+#13, 'NO DIALTONE'+#13);

constructor TCommStream.Init(Port : byte; InQueue, OutQueue : word);
const
  Buf : PChar = 'COMx';
begin
  inherited Init(0, 'COMx', 0);
  Status := 0;
  ErrorInfo := 0;
  Buf[3] := chr(Port+ord('0'));
  Handle := OpenComm(Buf, InQueue, OutQueue);
  if Handle < 0 then begin
    Error(stInitError, 25000-Handle);
  end;
  {$IFDEF commfile}
  INF.Init('com.in', stCreate, $800);
  OUTF.Init('com.out', stCreate, $800);
  {$ENDIF}
end;

destructor TCommStream.Done;
begin
  if Handle >= 0 then begin
    EnableCommNotification(Handle, 0, -1, -1);
    FlushComm(Handle, 0);
    FlushComm(Handle, 1);
    CloseComm(Handle);
  end;
  {$IFDEF commfile}
  INF.Done; OUTF.Done;
  {$ENDIF}
  inherited Done;
end;

function TCommStream.ReadBytes(var Buf; Count : word) : word;
var
  BytesRead : integer;
begin
  if Status = stOk then begin
    BytesRead := ReadComm(Handle, @Buf, Count);
    if (BytesRead <= 0) and CheckError then
      BytesRead := 0;
    ReadBytes := abs(BytesRead);
    {$IFDEF commfile} INF.Write(Buf, BytesRead); {$ENDIF}
  end else
    ReadBytes := 0;
end;

procedure TCommStream.Unread(Ch : char);
begin
  if UngetCommChar(Handle, Ch) < 0 then
    CheckError;
end;

procedure TCommStream.Write(var Buf; Count : word);
begin
  if Status = stOk then begin
    if WriteComm(Handle, @Buf, Count) <= 0 then
      CheckError;
    {$IFDEF commfile} OUTF.Write(Buf, Count); {$ENDIF}
  end;
end;

procedure TCommStream.WriteText(Txt : PChar);
begin
  Write(Txt^, StrLen(Txt));
end;
{
procedure TCommStream.SetNotify(Wnd : HWnd; NumRead, NumWrite : integer; EvtMask : word);
begin
  if Status = stOk then begin
    EnableCommNotification(Handle, Wnd, NumRead, NumWrite);
    SetCommEventMask(Handle, EvtMask);
  end;
end;
}
function TCommStream.CheckError : boolean;
var
  Stat : WinTypes.TComStat;
  i,res : integer;
begin
  res := GetCommError(Handle, Stat);
  if (res = 0) then begin
    CheckError := false;
    Exit;
  end;
  CheckError := true;
  for i := 0 to 15 do
    if res and (1 shl i) > 0 then
    begin
      Error(stError, 24000+i);
      Exit;
    end;
  Error(stError, 0);
end;

constructor TModemStream.Init(Port : byte);
begin
  inherited Init(Port, 4096, 4096);
  Onhook := false;
end;

destructor TModemStream.Done;
begin
  if OnHook then Disconnect;
  inherited Done;
end;

procedure TModemStream.SetParams(Params : PChar);
var
  DCB : TDCB;
  res : integer;
begin
  if Status <> stOk then
    Exit;
  if (BuildCommDCB(Params, DCB) = 0) then begin
    DCB.ID := Handle;
    DCB.Flags := dcb_Binary; { no flow control }
    res := SetCommState(DCB);
    if res < 0 then
      Error(stError, 0);
    { do modem voodoo -- isn't Windows crap? }
    repeat Sleep(200);
    until (FlushComm(Handle, 1) = 0) or Cancelled;
    repeat Sleep(200);
    until (FlushComm(Handle, 1) = 0) or Cancelled;
    repeat Sleep(200);
    until (FlushComm(Handle, 1) = 0) or Cancelled;
  end else
    Error(stError, 0);
end;

function TModemStream.WaitFor(const Results : array of PChar; MSec : longint) : integer;
var
  c,ch : char;
  Last : array[0..63] of char;
  l,i : integer;
  Time : longint;
  a : longint;
begin
  {$IFDEF commfile} OUTF.StrWrite('{W}'); {$ENDIF}
  Time := GetTickCount;
  FillChar(Last, sizeof(Last), 0);
  WaitFor := -1;
  repeat
    if (TCommStream.ReadBytes(ch, 1) > 0) and (ch <> #10) then begin
      {$IFDEF commfile} OUTF.Write(ch, 1); {$ENDIF}
      Move(Last[1], Last[0], sizeof(Last)-1);
      Last[High(Last)] := ch;
      for i := 0 to High(Results) do begin
        l := StrLen(Results[i]);
        if StrLComp(Results[i], @Last[High(Last)+1-l], l) = 0 then begin
          WaitFor := i;
          {$IFDEF commfile} OUTF.StrWrite('{Found:'); OUTF.Write(i,1); OUTF.StrWrite('}'); {$ENDIF}
          Exit;
        end;
      end;
    end;
    a := GetTickCount;
  until Cancelled or (GetTickCount-Time > MSec) or (Status <> stOk);
  {$IFDEF commfile} OUTF.StrWrite('{N}'); {$ENDIF}
end;

const
  TimeDelay = 50;

function TModemStream.InitModem(InitString : PChar) : integer;
begin
  WriteTextSlowly(CRLF, Timedelay);
  WriteTextSlowly(InitString, Timedelay);
  WriteTextSlowly(CRLF, Timedelay);
  { wait for OK }
  InitModem := WaitFor(ModemResults, 5000);
  Sleep(500);
end;

function TModemStream.Dial(DialString : PChar) : integer;
begin
end;

function TModemStream.Answer : boolean;
begin
  {$IFNDEF modemtest}
  case WaitFor(ModemResults, 5*60000) of
    1 : begin { RING }
  {$ENDIF}
      { send ATA }
      Sleep(500);
      WriteTextSlowly(CRLF+'ATA'+CRLF, TimeDelay);
      Answer := true;
  {$IFNDEF modemtest}
    end;
  else
    Answer := false;
  end;
  {$ENDIF}
end;

function TModemStream.Connect : boolean;
var
  res : integer;
begin
  { wait for CONNECT }
  if not Onhook then begin
    res := WaitFor(ModemResults, 120000);
    if res = 2 then begin { connected }
      Onhook := true;
    end else
      WriteText(CRLF);
    Sleep(500);
  end;
  Connect := Onhook;
end;

function TModemStream.Disconnect : boolean;
var
  res : integer;
begin
  Disconnect :=
    EscapeCommFunction(Handle, CLRDTR) = 0;
  (*
  if Onhook then begin
    Disconnect := false;
    Sleep(1000);
    WriteText('+++');
    Sleep(1000);
    if WaitFor(ModemResults, 3000) <> 0 then Exit;
    Sleep(500);
    WriteText(CRLF+'ATH0'+CRLF);
    res := WaitFor(ModemResults, 5000);
    Onhook := not ((res = 0) or (res = 4));
    Disconnect := not Onhook;
    Sleep(500);
  end else
    Disconnect := true;
  *)
end;

procedure TModemStream.WriteTextSlowly(Txt : PChar; MSec : word);
begin
  while (Txt^ <> #0) do begin
    TCommStream.Write(Txt^, 1);
    inc(Txt);
    Sleep(MSec);
  end;
end;

constructor TModemPktStream.Init(Port : byte);
begin
  inherited Init(Port);
  pktbufpos := 0;
end;

function TModemPktStream.ReadPacket(var Buf; Count: Word) : word;
var
  a : word;
begin
  ReadPacket := 0;
  a := ReadBytes(pktbuf[pktbufpos], 1);
  if a > 0 then begin
    { have we filled up a packet yet? }
    if pktbufpos = pktbuf[0] then
    begin
      ReadPacket := pktbuf[0];
      Move(pktbuf[1], Buf, pktbuf[0]);
      pktbufpos := 0;
    end else
      inc(pktbufpos);
  end;
end;

procedure TModemPktStream.WritePacket(var Buf; Count : word);
begin
  if Count > 255 then Count := 255;
  Write(Count, 1);
  Write(Buf, Count);
end;

end.
