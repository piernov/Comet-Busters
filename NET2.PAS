unit Net2;

interface

uses
  WinTypes, WinProcs, Objects, Strings,
  {$IFNDEF VER80}Win31, {$ENDIF}DynArr, GameSock, WinSock, Messages;

type
  PNetStream = ^TNetStream;
  TNetStream = object(TGameSocket)
    constructor Init(Name : PChar);
    destructor Done; virtual;
    function ReadPacket(var Buf; Count: Word) : word; virtual;
    procedure Write(var Buf; Count : word); virtual;
    procedure SetNotify(Wnd : HWnd; NumRead, NumWrite : integer; EvtMask : word);
    procedure Idle; virtual;
  private
    HSlot : THandle;
  end;

implementation

function DosMakeMailSlot(Name : PChar; Size, Flags : word; var HSlot : THandle)
  : integer; far; external 'NETAPI';
procedure DosDeleteMailSlot(HSlot : THandle); far; external 'NETAPI';
function DosReadAsyncNMPipe(HSlot : THandle; Callback : pointer; var Count : word;
  Buf : pointer; MaxSize : word; var Count2 : word) : word;
  far; external 'NETAPI';
procedure NetMessageBufferSend(Callback : pointer; Buf : pointer; Dest : PChar;
  HSlot : THandle; Count : word); far; external 'NETAPI';

constructor TNetStream.Init(Name : PChar);
begin
  inherited Init(0, 'SOCK', $FA0);
  HSlot := 0;
  DosMakeMailSlot(Name, $FA0, 0, HSlot);
  if HSlot = 0 then Status := -1;
end;

destructor TNetStream.Done;
begin
  DosDeleteMailSlot(HSlot);
  inherited Done;
end;

function TNetStream.ReadPacket(var Buf; Count: Word) : word;
begin
  if HSlot <> 0 then begin
    Result := DosReadAsyncNMPipe(HSlot, nil, Count, @Buf, Count, Count);
    if Result = $FFFF then Result := 0;
  end else
    ReadPacket := 0;
end;

procedure TNetStream.Write(var Buf; Count : word);
begin
  if HSlot <> 0 then
{    _lwrite(HSlot, @Buf, Count);}
    NetMessageBufferSend(nil, @Buf, nil, HSlot, Count);
end;

procedure TNetStream.SetNotify(Wnd : HWnd; NumRead, NumWrite : integer; EvtMask : word);
begin
end;

procedure TNetStream.Idle;
begin
end;

end.
