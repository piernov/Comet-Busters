unit Mmtimer;
{$R-,S-,Q-}
{$C FIXED PRELOAD PERMANENT}

interface

uses
  WinTypes, WinProcs, Objects, MMSystem;

type
  TTickerNum = 0..7;

  TMMTimer = object(TObject)
    constructor Init;
    destructor Done; virtual;
  private
    { Private declarations }
    Caps : TTIMECAPS;
    TimerID : word;
    FPeriod : longint;
    FActive : boolean;
    procedure CheckError(uError : word);
  protected
    { Protected declarations }
  public
    OneShot : boolean;
    TickerNum : TTickerNum;
    { Public declarations }
    function GetTickerAndReset : word;
    procedure SetActive(AActive : boolean);
    procedure SetPeriod(APeriod : longint);
  end;

implementation

type
  WordPtr = ^Word;

var
  TickerCounters : array[TTickerNum] of word;

procedure TimerCallback(wTimerID, uMessage : word; dwUser, dw1, dw2 : longint);
export;
begin 
(****** WARNING: DO NOT SET A BREAKPOINT HERE!!!!!! *****)
   inc(WordPtr(dwUser)^);
(********************************************************)
end;

procedure TMMTimer.CheckError(uError : word);
var
  buf : array[0..255] of char;
begin
  if uError <> 0 then begin
{    midiOutGetErrorText(uError, buf, sizeof(buf));
    raise ETimerDevError.Create('Timer error: '+StrPas(buf));}
    RunError(255);
  end;
end;

constructor TMMTimer.Init;
begin
  inherited Init;
  timeGetDevCaps(@Caps, sizeof(Caps));
  FPeriod := 1000;
end;

destructor TMMTimer.Done;
begin
  SetActive(false);
  inherited Done;
end;

procedure TMMTimer.SetActive(AActive : boolean);
begin
  if (AActive <> FActive) then
  begin
    if AActive then begin
      CheckError(timeBeginPeriod(Caps.wPeriodMin));
      FActive := true;
      SetPeriod(FPeriod);
    end else begin
      SetPeriod(0);
      CheckError(timeEndPeriod(Caps.wPeriodMin));
    end;
  end;
  FActive := AActive;
end;

procedure TMMTimer.SetPeriod(APeriod : longint);
const
  perflags : array[boolean] of word = (TIME_PERIODIC, TIME_ONESHOT);
begin
  FPeriod := APeriod;
  if not FActive then
    Exit;
  if TimerID <> 0 then
    timeKillEvent(TimerID);
  if FPeriod <> 0 then
  begin
    TickerCounters[TickerNum] := 0;
    TimerID :=
      timeSetEvent(FPeriod, Caps.wPeriodMin, TimerCallback,
        longint(@TickerCounters[TickerNum]), perflags[OneShot]);
  end;
end;

function TMMTimer.GetTickerAndReset : word;
var
  i : TTickerNum;
begin
  i := TickerNum;
  asm
    xor  ax,ax
    mov  bl,i
    mov  bh,0
    shl  bx,1
    xchg word ptr [bx+TickerCounters],ax
    mov  Result,ax
  end;
end;

end.
