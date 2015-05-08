(*********************************************************)
(**  NUCLWINT.PAS                                       **)
(**  Nuclear Winter                                     **)
(**                                                     **)
(**  Copyright (c) 1992 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

program NUCLWINT;

{$R NUCLWINT}
{$D Nuclear Winter - Copyright (c) 1992 HAMCO software}

uses
  Messages, WinTypes, WinProcs, Objects, OWindows, ODialogs,
  Strings, GameSnd, MMSystem;

const
  idm_Reset    = 100;
  idm_Stop     = 101;
  idm_About    = 102;
  idm_Pause    = 103;
  idm_Sound    = 104;
  idm_Quit     = 105;

  NumSounds = 6;
  MaxAbms = 7;
  MaxMissiles = 15;
  TimerTime = {100}55;
  VecScale = 32;

  CitySpac = 80;
  CityOfs = 64;

  MaxCities = 5;
  NumSilos = 1;
  WinGameLevel = 10;

  WinGame = 1;
  LoseGame = 2;

  scoMissile = 50;
  scoPlane = 250;
  scoExtraABM = 10;
  scoExtraCity = 100;

  sampSILOEXPLODE = (1);
  sampEXPLODE1    = (2);
  sampEXPLODE2    = (3);
  sampCITYEXPLODE = (4);
  sampLAUNCH      = (5);
  sampNEWLEVEL    = (6);

  sound_None = 0;
  sound_Spkr = 1;
  sound_Wave = 2;
  sound_NoHardware = 2;

var
  YSize : integer;

type
  GameModeType =
    (isAttract1, isAttract2,
     isGameMode, isPaused,
     isBeginLevel, isEndLevel, isWinGame, isLoseGame);
const
  GameModeTimes : array[GameModeType] of word =
    (6000, 12000,
     TimerTime, 0,
     4000, 5000, 30000, 8000);

type
  TApp = object(TApplication)
    procedure InitMainWindow; virtual;
  end;

  MissileRec = object
    Start, Pos, Vector : TPoint;
    Exists : boolean;
    procedure Update(DC : HDC);
    procedure Paint(DC : HDC);
    procedure Kill(HWindow : THandle; DC : HDC);
  end;
  AbmRec = object(MissileRec)
    Dest : TPoint;
    ExplodeState : byte;
  end;

  PGameWindow = ^TGameWindow;
  TGameWindow = object(TWindow)
    constructor Init(AParent: PWindowsObject; Title: PChar);
    destructor Done; virtual;
    procedure About(var Message: TMessage); virtual cm_First + idm_About;
    procedure ClearWindow;
    procedure DrawBMP(DC : HDC; X, Y : integer; BitMap : HBitMap);
    procedure DrawCity(DC : HDC; n : integer);
    procedure FireAbm(n : integer; var Message: TMessage);
    procedure GetWindowClass(var WndClass: TWndClass); virtual;
    procedure InitSounds;
    procedure NewLevel;
    procedure NewMissile;
    procedure Paint(PaintDC: HDC; var PaintInfo: TPaintStruct); virtual;
    procedure Pause(var Message: TMessage); virtual cm_First + idm_Pause;
    procedure QuitGame(var Message: TMessage); virtual cm_First + idm_Quit;
    procedure ResetGame(var Message: TMessage); virtual cm_First + idm_Reset;
    procedure SetMode(AMode : GameModeType);
    function SetSound(state : word) : boolean;
    procedure SetUpWindow; virtual;
    procedure StartTimer(Time : longint);
    procedure StopTimer;
    procedure Stop(var Message: TMessage); virtual cm_First + idm_Stop;
    procedure StopGame;
    procedure ToggleSound(var Message: TMessage); virtual cm_First + idm_Sound;
    procedure WriteScore(PaintDC : HDC);
    procedure WMDestroy(var Message: TMessage); virtual wm_Destroy;
    procedure WMLButtonDown(var Message: TMessage); virtual wm_LButtonDown;
    procedure WMRButtonDown(var Message: TMessage); virtual wm_RButtonDown;
    procedure WMTimer(var Message: TMessage); virtual wm_Timer + wm_First;
    procedure WMSize(var Message: TMessage); virtual wm_Size;
    procedure MMWomDone(var Message: TMessage); virtual MM_WOM_DONE;
  end;

var
  Gunsight : HCursor;
  Cities : array[0..MaxCities] of HBitMap;
  Silo, SiloDead, SiloAbm : HBitMap;
  Planes : array[0..0] of HBitMap;
  GndBrush : HBrush;
  MissilePen, AbmPen, ErasePen : HPen;
  GameFont : HFont;

  Mode : GameModeType;
  SoundOn : integer;
  SoundType : integer;
  Sounds : array[1..NumSounds] of PSound;
  Score : longint;

  Missiles : array[0..MaxMissiles] of MissileRec;
  Abms : array[0..MaxAbms] of AbmRec;

  CitiesLeft : byte;
  CityState : array[0..MaxCities] of byte;
  CityExploding : array[0..MaxCities] of boolean;
  Silos : array[0..NumSilos] of shortint;
  PlaneX, PlaneY : integer;
  Frame : longint;
  EndLevelTime : integer;

  Level, MissilesToGo : integer;
  ABMspeed : integer;

  TimerOn : boolean;
  CurTimerTime : word;
  SndInst : THandle;

function NotBlack(DC : HDC; ref : TColorRef) : TColorRef;
var r : longint;
begin
  r := GetNearestColor(DC, ref);
  if r and $FFFFFF = 0 then NotBlack := $FFFFFF
  else NotBlack := ref;
end;

{--------------- TGameWindow -----------------}

procedure TGameWindow.MMWomDone(var Message: TMessage);
begin
  DoneWaveChannel(Message.wParam);
end;

constructor TGameWindow.Init(AParent: PWindowsObject; Title: PChar);
begin
  inherited Init(AParent, Title);
  YSize := 400;
  Attr.W := 600;
  Attr.H := YSize+GetSystemMetrics(sm_CYSize)+40;
  Attr.Style := WS_Caption or WS_SysMenu or WS_MinimizeBox;
  Randomize;
  TimerOn := false;
end;

destructor TGameWindow.Done;
var
 i : integer;
begin
  if SoundType = sound_Wave then begin
    { for WAVEMIX, gotta dispose the sounds before closing device }
    if SoundType = sound_Wave then
      CloseWaveChannels;
    for i := 1 to NumSounds do
      if Sounds[i] <> nil then Dispose(Sounds[i], Done);
    case SoundType of
      sound_Wave : DoneWaveSound;
      sound_Spkr : DoneSpkrSound;
    end;
  end;
  inherited Done;
end;

procedure TGameWindow.About(var Message: TMessage);
var
  Dialog: TDialog;
begin
  Dialog.Init(@Self, 'About');
  Dialog.Execute;
  Dialog.Done;
end;

procedure TGameWindow.ClearWindow;
begin
  InvalidateRect(HWindow, nil, true);
end;

procedure TGameWindow.GetWindowClass(var WndClass: TWndClass);
begin
  TWindow.GetWindowClass(WndClass);
  WndClass.Style := 0;
  WndClass.hCursor := LoadCursor(hInstance, 'Gunsight');
  WndClass.hbrBackGround := GetStockObject(Black_Brush);
  WndClass.lpszMenuName := 'Menu';
  WndClass.hIcon := LoadIcon(hInstance, 'MAINICON');
end;

procedure TGameWindow.DrawBMP(DC : HDC; X, Y : integer; BitMap : HBitMap);
var
  MemDC : HDC;
  MadeDC : boolean;
  BitInfo : TBitMap;
begin
  if DC = 0 then
  begin
    DC := GetDC(HWindow);
    MadeDC := True;
  end else
    MadeDC := False;

  if GetObject(BitMap, sizeof(BitInfo), @BitInfo) > 0 then begin
    MemDC := CreateCompatibleDC(DC);
    SelectObject(MemDC, BitMap);
    BitBlt(DC, X, Y, BitInfo.bmWidth, BitInfo.bmHeight, MemDC, 0, 0,
      SRCCopy);
    DeleteDC(MemDC);
  end;

  if MadeDC then ReleaseDC(HWindow, DC);
end;

procedure TGameWindow.DrawCity(DC : HDC; n : integer);
var x,y,state,height : integer;
    R : TRect;
const CityHeight : array[0..MaxCities] of byte =
  (12, 48, 48, 48, 48, 24);
begin
  x := n*CitySpac+CityOfs;
  state := CityState[n];
  height := CityHeight[state];
  y := Ysize-height;
  if state = 0 then begin
    SetRect(R, x, Ysize-48, x+64, y);
    FillRect(DC, R, GetStockObject(Black_Brush));
  end;
  DrawBMP(DC, x, y, Cities[state]);
end;

procedure MissileRec.Paint;
begin
  if Exists then begin
    with Start do MoveTo(DC, X div VecScale, Y div VecScale);
    with Pos do LineTo(DC, X div VecScale, Y div VecScale);
  end;
end;

procedure FixRect(var R : TRect);
var a : integer;
begin
  with R do begin
    if left > right then begin
      a := left; left := right; right := a;
    end;
    if top > bottom then begin
      a := top; top := bottom; bottom := a;
    end;
  end;
end;

procedure MissileRec.Kill;
var
  x1,y1,x2,y2 : integer;
  R : TRect;
begin
  Exists := false;
{  SetRect(R, Start.X div VecScale, Start.Y div VecScale,
    Pos.X div VecScale, Pos.Y div VecScale);
  FixRect(R);
  InvalidateRect(HWindow, @R, true);}
  x1 := Start.X div VecScale;
  y1 := Start.Y div VecScale;
  x2 := Pos.X div VecScale;
  y2 := Pos.Y div VecScale;
  MoveTo(DC, x1, y1); LineTo(DC, x2, y2);
  MoveTo(DC, x1+1, y1); LineTo(DC, x2+1, y2);
  MoveTo(DC, x1-1, y1); LineTo(DC, x2-1, y2);
  MoveTo(DC, x1, y1-1); LineTo(DC, x2, y2-1);
  MoveTo(DC, x1, y1+1); LineTo(DC, x2, y2+1);
  with Start do MoveTo(DC, X div VecScale, Y div VecScale);
  with Pos do LineTo(DC, X div VecScale, Y div VecScale);
end;

procedure MissileRec.Update;
var OldPos : TPoint;
    CityNum : integer;
begin
  if Exists then begin
    OldPos := Pos;
    inc(Pos.X, Vector.X);
    inc(Pos.Y, Vector.Y);
    with OldPos do MoveTo(DC, X div VecScale, Y div VecScale);
    with Pos do LineTo(DC, X div VecScale, Y div VecScale);
    with Pos do SetPixel(DC, X div VecScale, Y div VecScale, $FFFFFF);
  end;
end;

procedure TGameWindow.WriteScore(PaintDC : HDC);
var s : array[0..20] of char;
begin
  SetBkColor(PaintDC, RGB(0, 0, 0));
  SetTextColor(PaintDC, NotBlack(PaintDC, RGB(64, 64, 255)));
  SelectObject(PaintDC, GetStockObject(System_Font));
  TextOut(PaintDC, 20, 8, '1UP', 3);
  Str(Score, s);
  TextOut(PaintDC, 20, 24, s, StrLen(s));
end;

function ABMxpos(n, silonum : integer) : integer;
begin
  case silonum of
    0 : ABMxpos := n*12-6;
    1 : ABMxpos := 600-6-n*12;
  end;
end;

procedure TGameWindow.Paint(PaintDC: HDC; var PaintInfo: TPaintStruct);
var
  I,x,pts,yp : Integer;
  BMP : HBitMap;
  LogFont : TLogFont;
  TitleFnt : HFont;
  R : TRect;
  Buf : array[0..10] of char;
const
  NumTitleLines = 3;
  TitleText : array[0..NumTitleLines-1] of Pchar =
    ('NUCLEAR WINTER', 'By Steven E. Hugg',
     { #169' 1992}'HAMCO Software');
  Screen2Text =
    'Instructions: Left button fires left silo,'+#13+
    'Right button fires right silo.'+#13+
    'Game over after level 10.'+#13+#13+
    'Programming and design:'+#13+
    'Steven E. Hugg'+#13+#13+
    'Nuclear explosions drawn by:'+#13+
    'Andrew Hugg'+#13+#13+
    'Written in Turbo Pascal for Windows';
{  Screen2Info =
    'This program is shareware. Which means it isn''t worth '+#13+
    'a durn penny. But if you have any questions, the address is:';
  Screen2Addr =
    'HAMCO Software'+#13+'2500 Greenview Drive'+#13+
    'Gulfport MS 39507';}

procedure DrawWinGame;
var BMP : HBitMap;
    R : TRect;
    i : integer;
const
  WinGameString =
   'World War III is over! You have saved the United States from destruction. '+
   'You have the thanks of the President and the free world. The nation may '+
   'rest, for now...';
begin
  BMP := LoadBitMap(hInstance, 'BUSH');
  DrawBMP(PaintDC, 30, YSize shr 1-120, BMP);
  DeleteObject(BMP);
  SelectObject(PaintDC, GetStockObject(System_Font));
  SetTextColor(PaintDC, RGB(255, 255, 255));
  SetRect(R, 170, 100, 550, 300);
  DrawText(PaintDC, WinGameString, -1, R, dt_WordBreak or dt_VCenter);
  if SoundOn = 0 then begin
    DoneMidiSound;
    InitMidiSound(HWindow, 'NUCLWIN.MID');
    PlayMidiFile;
  end;
{  PlaySongRes('POMPCIRC');}
end;

procedure DrawLoseGame;
var BMP : HBitMap;
    R : TRect;
    i : integer;
const
  LoseGameString : PChar =
    'World War III is over. The new Soviet Republic has crushed the United States '+
    'with its nuclear arsenal. As nuclear winter looms, all hope for the '+
    'future is lost...';
begin
  BMP := LoadBitMap(hInstance, 'GORBY');
  DrawBMP(PaintDC, 30, YSize shr 1-120, BMP);
  DeleteObject(BMP);
  SelectObject(PaintDC, GetStockObject(System_Font));
  SetTextColor(PaintDC, RGB(255, 255, 255));
  SetRect(R, 170, 100, 550, 300);
  DrawText(PaintDC, LoseGameString, -1, R, dt_WordBreak or dt_VCenter);
  if SoundOn = 0 then begin
    DoneMidiSound;
    InitMidiSound(HWindow, 'NUCLLOSE.MID');
    PlayMidiFile;
  end;
{  PlaySongRes('RUSSIANS');}
end;

begin
  SetBkColor(PaintDC, 0);
  if (PaintInfo.rcPaint.bottom >= Ysize-32) then begin
    SetRect(R, 0, YSize, 600, YSize+24);
    FillRect(PaintDC, R, GndBrush);
    for i := 0 to NumSilos do begin
      if Silos[i] >= 0 then begin
        BMP := Silo; yp := 32;
      end else begin
        BMP := SiloDead; yp := 16{32};
      end;
      DrawBMP(PaintDC, i*(600-48), Ysize-yp{ +5 }, BMP);
    end;
    for i := 0 to MaxCities do
      DrawCity(PaintDC, i);
  end;
  case Mode of
    isGameMode, isPaused : begin
      SelectObject(PaintDC, MissilePen);
      for I := 0 to MaxMissiles do
        Missiles[i].Paint(PaintDC);
      SelectObject(PaintDC, ABMPen);
      for I := 0 to MaxAbms do
        Abms[i].Paint(PaintDC);
      if (PaintInfo.rcPaint.bottom > Ysize) then begin
        for x := 0 to NumSilos do
          if Silos[x] > 0 then for i := 1 to Silos[x] do
            DrawBMP(PaintDC, ABMxpos(i, x), Ysize+5, SiloAbm);
      end;
    end;
    isAttract1 : begin
      SelectObject(PaintDC, GameFont);
      SetTextColor(PaintDC, RGB(255, 255, 127));
      GetClientRect(HWindow, R);
      for i := 0 to NumTitleLines-1 do
       TextOut(PaintDC, 50+i*40, 80+i*50, TitleText[i],
        StrLen(TitleText[i]));
    end;
    isAttract2 : begin
      GetClientRect(Hwindow, R);
      SetTextColor(PaintDC, NotBlack(PaintDC, RGB(0, 63, 255)));
      DrawText(PaintDC, Screen2Text, -1, R, dt_WordBreak or dt_Center
        or dt_VCenter);
      R.top := (R.top+R.bottom) div 2;
      SetTextColor(PaintDC, RGB(255, 255, 0));
{      DrawText(PaintDC, Screen2Info, -1, R, dt_WordBreak or dt_Center
        or dt_VCenter);
      R.top := (R.top+R.bottom) div 2;
      R.left := (R.right div 3);
      DrawText(PaintDC, Screen2Addr, -1, R, dt_WordBreak);}
    end;
    isWinGame : DrawWinGame;
    isLoseGame : DrawLoseGame;
    isBeginLevel : begin
      SelectObject(PaintDC, GameFont);
      SetTextColor(PaintDC, NotBlack(PaintDC, RGB(64, 255, 64)));
      GetClientRect(HWindow, R);
      DrawText(PaintDC, buf, wvsprintf(buf, 'Level %u', level), R,
        dt_VCenter or dt_Center);
    end;
    isEndLevel : begin
      if SoundOn = 0 then begin
        DoneMidiSound;
        InitMidiSound(HWindow, 'NUCLLEVL.MID');
        PlayMidiFile;
      end;
      SelectObject(PaintDC, GameFont);
      SetTextColor(PaintDC, NotBlack(PaintDC, RGB(255, 64, 64)));
      pts := 0;
      for i := 0 to 1 do
        if Silos[i] > 0 then inc(pts, Silos[i]);
      if pts > 0 then for i := 1 to pts do
        DrawBMP(PaintDC, 100+i*12, YSize div 3, SiloAbm);
      pts := pts * scoExtraABM;
      inc(score, pts);
      TextOut(PaintDC, 50, YSize div 3, buf, wvsprintf(buf, '%u', pts));
      pts := CitiesLeft*scoExtraCity;
      inc(score, pts);
      for i := 1 to CitiesLeft do begin
        DrawBMP(PaintDC, 30+i*76, YSize*2 div 3, Cities[5]);
      end;
      TextOut(PaintDC, 50, YSize*2 div 3, buf, wvsprintf(buf, '%u', pts));
    end;
  end;
  WriteScore(PaintDC);
end;

procedure TGameWindow.StartTimer;
begin
  if SetTimer(HWindow, 1, Time, nil) = 0 then
  begin
    MessageBox(HWindow, 'No Timers Left', 'Error', mb_Ok);
    Done;
    Halt(1);
  end;
  TimerOn := true;
  CurTimerTime := Time;
end;

procedure TGameWindow.StopTimer;
begin
  if TimerOn then begin
    KillTimer(HWindow, 1);
    TimerOn := false;
  end;
end;

procedure TGameWindow.SetMode(AMode : GameModeType);
var n : integer;
begin
  Mode := AMode;
  n := GameModeTimes[AMode];
  if n = 0 then StopTimer else StartTimer(n);
end;

procedure TGameWindow.Pause(var Message: TMessage);
begin
 case Mode of
  isPaused : begin
    ModifyMenu(GetMenu(HWindow), idm_Pause, mf_ByCommand,
      idm_Pause, '&Pause');
    DrawMenuBar(hWindow);
    SetMode(isGameMode);
  end;
  isGameMode : begin
    SetMode(isPaused);
    ModifyMenu(GetMenu(HWindow), idm_Pause, mf_ByCommand,
      idm_Pause, '&Continue');
    DrawMenuBar(hWindow);
  end;
 end;
end;

function TGameWindow.SetSound(state : word) : boolean;
begin
  SetSound := true;
  if (SoundOn = 0) xor (state = 0) then begin 
    SoundOn := state;
    if SoundOn = 0 then begin
      case SoundType of
        sound_Wave :
          PauseWaveSound(False);
        sound_Spkr :
          SetSound := InitSpkrSound(512);
      end;
    end else begin
      case SoundType of
        sound_Wave : PauseWaveSound(True);
        sound_Spkr : DoneSpkrSound;
      end;
    end;
  end;
end;

procedure TGameWindow.ToggleSound(var Message: TMessage);
const SoundMenuArr : array[boolean] of PChar =
  ('&Sound on','&Sound off');
begin
  SetSound(SoundOn xor 1);
  ModifyMenu(GetMenu(HWindow), idm_Sound, mf_ByCommand,
    idm_Sound, SoundMenuArr[SoundOn = 0]);
  DrawMenuBar(hWindow);
end;

procedure TGameWindow.NewLevel;
var i : integer;
begin
  FillChar(Missiles, sizeof(Missiles), 0);
  FillChar(Abms, sizeof(Abms), 0);
  FillChar(Silos, sizeof(Silos), 30 div (NumSilos+1));
  Frame := 0; EndLevelTime := 0;
  PlaneY := -1;
  for i := 0 to level shr 1+3 do NewMissile;
  planey := 50; planex := -100;
  FillChar(CityExploding, sizeof(CityExploding), 0);
  MissilesToGo := Level*3+12;
  ABMspeed := (Level+14)*VecScale;
  ClearWindow;
  SetMode(isBeginLevel);
  Sounds[sampNEWLEVEL]^.Play;
end;

procedure TGameWindow.NewMissile;
var i : integer;
    intx : integer;
begin
  for i := 0 to MaxMissiles do with Missiles[i] do begin
    if not Exists then begin
     repeat
      if (PlaneY >= 0) and (PlaneX < 500) then begin
        Start.Y := (PlaneY+45)*VecScale;
        Start.X := (PlaneX+80)*VecScale;
      end else begin
        Start.Y := 0; Start.X := random(600*VecScale);
      end;
      intx := VecScale+level;
      Vector.X := integer(random(2*intx))-intx;
      Vector.Y := (VecScale*(level+3)) shr 1+random(VecScale shr 1);
      intx := Start.X+LongDiv(LongMul((Ysize*VecScale-Start.Y), Vector.X), Vector.Y);
     until (intx >= 0) and (intx <= 600*VecScale);
      Pos := Start;
      Exists := true;
      Exit;
    end;
  end;
end;

procedure TGameWindow.QuitGame(var Message: TMessage);
begin
  SendMessage(HWindow, wm_Close, 0, 0);
end;

procedure TGameWindow.ResetGame(var Message: TMessage);
var
  i : integer;
begin
  ModifyMenu(GetMenu(HWindow), idm_Pause, mf_ByCommand,
    idm_Pause, '&Pause');
  ModifyMenu(GetMenu(HWindow), idm_Stop, mf_ByCommand,
    idm_Stop, '&Stop');
  DrawMenuBar(HWindow);
  Level := 1;
  Score := 0;
  FillChar(CityState, sizeof(CityState), 5);
  CitiesLeft := MaxCities+1;
  ModifyMenu(GetMenu(HWindow), idm_Pause, mf_ByCommand,
    idm_Pause, '&Pause');
  DrawMenuBar(hWindow);
  NewLevel;
end;

procedure TGameWindow.InitSounds;
const
  SndPriorty : array[1..NumSounds] of byte =
    (20, 5, 6, 15, 5, 30);
var i : integer;
begin
  SoundType := sound_None;
  SoundOn := 0;
  if InitWaveSound(HWindow, WAVE_FORMAT_1M08, 0, false) then begin
    { setup for wave sounds }
    SndInst := LoadLibrary('NUCLSNDS.DLL');
    if SndInst < 32 then SndInst := 0;
    for i := 1 to NumSounds do
      Sounds[i] := New(PWave, LoadRes(SndInst, PChar(i), SndPriorty[i]));
    PWave(Sounds[sampNEWLEVEL])^.NumLoops := 2;
    SoundType := sound_Wave;
    FreeLibrary(SndInst);
  end else begin
    if InitSpkrSound(512) then begin
      { setup for speaker sounds }
      Sounds[sampSILOEXPLODE] := New(PNoise, Init(200, 2, 2200, -4, 500));
      Sounds[sampEXPLODE1] := New(PNoise, Init(100, 0, 200, 1, 150));
      Sounds[sampEXPLODE2] := New(PNoise, Init(300, -1, 500, 2, 250));
      Sounds[sampCITYEXPLODE] := New(PNoise, Init(100, 0, 500, -1, 400));
      Sounds[sampLAUNCH] := New(PNoise, Init(1500, -10, 300, 10, 320));
      Sounds[sampNEWLEVEL] := New(PNoise, Init(200, 1, 0, 0, 320));
      SoundType := sound_Spkr;
    end else begin
      for i := 1 to NumSounds do
        Sounds[i] := New(PSound, Init);
      ModifyMenu(GetMenu(HWindow), idm_Sound, mf_ByCommand+mf_Grayed,
        idm_Sound, '&Sound on');
        { no sound available }
      SoundOn := sound_NoHardware;
    end;
  end;
  SetSound(1);
end;

procedure TGameWindow.SetUpWindow;
var i : integer;
    LogFont : TLogFont;
    DC : HDC;
begin
  Cities[5] := LoadBitMap(hInstance, 'City');
  Cities[0] := LoadBitMap(hInstance, 'CityDead');
  Cities[4] := LoadBitMap(hInstance, 'Nuke1');
  Cities[3] := LoadBitMap(hInstance, 'Nuke2');
  Cities[2] := LoadBitMap(hInstance, 'Nuke3');
  Cities[1] := LoadBitMap(hInstance, 'Nuke4');
  Silo := LoadBitMap(hInstance, 'Silo');
  SiloDead := LoadBitMap(hInstance, 'SiloBlown');
  SiloAbm := LoadBitMap(hInstance, 'Anum');
  Planes[0] := LoadBitMap(hInstance, 'RPlane');
  DC := GetDC(HWindow);
  AbmPen := CreatePen(ps_Solid, 1, NotBlack(DC, RGB(0, 0, 255)));
  MissilePen := CreatePen(ps_Solid, 1, NotBlack(DC, RGB(255, 0, 0)));
  GndBrush := CreateSolidBrush(RGB(255, 128, 32));
  ReleaseDC(HWindow, DC);
  ErasePen := GetStockObject(Black_Pen);
  FillChar(LogFont, sizeof(LogFont), 0);
  with LogFont do begin
    lfHeight := 40;
    lfQuality := Proof_Quality;
    lfPitchAndFamily := ff_Swiss;
  end;
  GameFont := CreateFontIndirect(LogFont);

  InitSounds;
  Score := 0;
  FillChar(CityState, sizeof(CityState), 5);
  FillChar(Silos, sizeof(Silos), 0);
  SetMode(isAttract1);
end;

procedure TGameWindow.StopGame;
begin
  StopTimer;
  ModifyMenu(GetMenu(HWindow), idm_Pause, mf_ByCommand or mf_Grayed,
    idm_Pause, '&Pause');
  ModifyMenu(GetMenu(HWindow), idm_Stop, mf_ByCommand or mf_Grayed,
    idm_Stop, '&Stop');
  DrawMenuBar(HWindow);
  ClearWindow;
end;

procedure TGameWindow.Stop(var Message: TMessage);
begin
  StopGame;
  SetMode(isAttract1);
end;

procedure TGameWindow.WMDestroy(var Message : TMessage);
var i : integer;
begin
  StopTimer;
  for i := 0 to 5 do DeleteObject(Cities[i]);
  DeleteObject(Silo);
  DeleteObject(SiloAbm);
  DeleteObject(SiloDead);
  DeleteObject(MissilePen);
  DeleteObject(AbmPen);
  DeleteObject(GndBrush);
  DeleteObject(Planes[0]);
  DeleteObject(GameFont);
  inherited WMDestroy(Message);
end;

procedure TGameWindow.FireAbm;
var
  i : integer;
  dx,dy : integer;
  rad : integer;
  Point : TPoint;
  R : TRect;
  DC : HDC;
begin
  if Mode <> isGameMode then Exit;
  if Silos[n] <= 0 then begin
    if SoundOn = 0 then
      MessageBeep(MB_ICONEXCLAMATION);
    Exit;
  end;
  if EndLevelTime > 0 then Exit;
  with Point do begin
    X := LoWord(Message.lParam)*VecScale;
    Y := HiWord(Message.lParam)*VecScale;
    if Y > (Ysize-48)*VecScale then Y := (Ysize-48)*VecScale;
  end;
  for i := 0 to MaxAbms do with Abms[i] do begin
    if not Exists and (ExplodeState = 0) then begin
      case n of
        0 : Start.X := 24*VecScale;
        1 : Start.X := (600-24)*VecScale;
      end;
      Start.Y := (Ysize-36)*VecScale;
      Pos := Start;
      dx := (Point.X-Start.X);
      dy := (Point.Y-Start.Y);
      rad := round(sqrt(LongMul(dx, dx)+LongMul(dy, dy)));
      Vector.X := LongDiv(LongMul(ABMspeed, dx), rad);
      Vector.Y := LongDiv(LongMul(ABMspeed, dy), rad);
      Dest := Point;
      Exists := true;
      i := ABMxpos(Silos[n], n);
      SetRect(R, i, ysize+5, i+8, ysize+10);
      DC := GetDC(HWindow);
      FillRect(DC, R, GndBrush);
      ReleaseDC(HWindow, DC);
      dec(Silos[n]);
{      SoundNoise(1500, -10, 300, 10, 320);}
      Sounds[sampLAUNCH]^.Play;
      Exit;
    end;
  end;
end;

procedure TGameWindow.WMLButtonDown(var Message: TMessage);
begin
  FireAbm(0, Message);
end;

procedure TGameWindow.WMRButtonDown(var Message: TMessage);
begin
  FireAbm(1, Message);
end;

const
  ExplodeSize : array[1..8] of byte =
    (64, 64, 56, 48, 32, 24, 16, 8);

procedure TGameWindow.WMTimer(var Message: TMessage);
var
  R: TRect;
  DC : HDC;
  xp,I,j,CityNum,CircSize : Integer;
  OldPos : TPoint;
  MissilesLeft : boolean;

{ See if explosions hit missiles }
procedure CheckMissiles;
var j : integer;
    AbmPos : TPoint;
    CircLimit : longint;
begin
  CircLimit := sqr(longint(CircSize shr 1*VecScale));
  AbmPos := Abms[i].Dest;
  for j := 0 to MaxMissiles do with Missiles[j] do begin
    if Exists then begin
      if sqr(longint(AbmPos.X-Pos.X))+sqr(longint(
        AbmPos.Y-Pos.Y)) < CircLimit then begin
         SelectObject(DC, ErasePen);
         Kill(Hwindow, DC);
         inc(Score, scoMissile);
         WriteScore(DC);
{         SoundNoise(300, -1, 500, 2, 250);}
         Sounds[sampEXPLODE2]^.Play;
         SelectObject(DC, AbmPen);
      end;
    end;
  end;
 { see if missiles hit the plane }
 if PlaneY >= 0 then
  if sqr(longint(AbmPos.X-(PlaneX+60)*VecScale))+sqr(longint(
   AbmPos.Y-(PlaneY+16)*VecScale)) < CircLimit then begin
{    SoundNoise(100, 0, 200, 1, 450);}
    Sounds[sampEXPLODE1]^.Play;
    SetRect(R, PlaneX-10, PlaneY, PlaneX+120, PlaneY+45);
    InvalidateRect(HWindow, @R, true);
    PlaneY := -1;
    inc(Score, scoPlane);
    WriteScore(DC);
  end;
end;

begin
  case Mode of
    isAttract1 : begin
      SetMode(succ(Mode));
      ClearWindow;
      Exit;
    end;
    isAttract2 : begin
      SetMode(isAttract1);
      ClearWindow;
      Exit;
    end;
    isLoseGame, isWinGame : begin
      SetMode(isAttract1);
      ClearWindow;
      Exit;
    end;
    isEndLevel : begin
      if level >= WinGameLevel then begin
        StopGame;
        SetMode(isWinGame);
      end else begin
        if CitiesLeft <= 0 then begin
          StopGame;
          SetMode(isLoseGame);
        end else begin
          inc(Level);
          NewLevel;
        end;
      end;
      Exit;
    end;
    isBeginLevel : begin
      SetMode(isGameMode);
      ClearWindow;
      Exit;
    end;
  end;

  if (Random(20-Level) = 0) and (MissilesToGo > 0) then begin
    NewMissile; dec(MissilesToGo);
  end;
  inc(Frame);
  if (Frame = 500 div level) and (PlaneY < 0) then begin
    PlaneX := -100;
    PlaneY := level*15+random(100);
  end;
  DC := GetDC(HWindow);
  SelectObject(DC, MissilePen);

  { Animate city explosions }
  for i := 0 to 5 do
    if CityExploding[i] then begin
      dec(CityState[i]);
      if CityState[i] = 0 then CityExploding[i] := false;
      DrawCity(DC, i);
    end;

  { Update missiles }
  MissilesLeft := false;
  for i := 0 to MaxMissiles do
    with Missiles[i] do if Exists then begin
      MissilesLeft := true;
      Update(DC);
      if Pos.Y > (Ysize-5)*VecScale then begin
        { See if missiles hit cities }
        if Pos.X >= CityOfs*VecScale then begin
          CityNum := (Pos.X div VecScale-CityOfs) div CitySpac;
          if (CityNum <= MaxCities) and (CityState[CityNum] > 0) and
            not CityExploding[CityNum] and
            ((Pos.X div VecScale-CityOfs) mod CitySpac < 64) then begin
              CityExploding[CityNum] := true;
              dec(CitiesLeft);
{              SoundNoise(100, 0, 500, -1, 400);}
              Sounds[sampCITYEXPLODE]^.Play;
            end;
        end;
        { See if missiles hit silos }
        for j := 0 to 1 do begin
          xp := j*(600-48);
          if (Pos.X div Vecscale >= xp) and (Pos.X div Vecscale <= xp+48) and
           (Silos[j] >= 0) then begin
            Silos[j] := -1;
            SetRect(R, xp, Ysize-36, xp+48, Ysize);
            InvalidateRect(HWindow, @R, true);
{            SoundNoise(200, 2, 2200, -4, 500);}
            Sounds[sampSILOEXPLODE]^.Play;
          end;
        end;
        { Kill the missile, regardless }
        SelectObject(DC, ErasePen);
        Kill(Hwindow, DC);
        SelectObject(DC, MissilePen);
      end;
    end;

  SelectObject(DC, AbmPen);
  for i := 0 to MaxAbms do
    with Abms[i] do begin
      if Exists then begin
        Abms[i].Update(DC);
        if Pos.Y < Dest.Y then begin
          SelectObject(DC, ErasePen);
          Kill(HWindow, DC);
          SelectObject(DC, AbmPen);
          ExplodeState := 8;
{          SoundNoise(200, -1, 300, 3, 160);}
          Sounds[sampEXPLODE1]^.Play;
        end;
     end;
     if ExplodeState > 0 then begin
       CircSize := ExplodeSize[ExplodeState];
       with R do begin
         left := Dest.X div VecScale-CircSize shr 1;
         top := Dest.Y div VecScale-CircSize shr 1;
         right := left+CircSize;
         bottom := top+CircSize;
         if ExplodeState > 1 then begin
           SelectObject(DC, GetStockObject(Null_Pen));
           with R do Ellipse(DC, left, top, right, bottom);
           SelectObject(DC, AbmPen);
           CheckMissiles;
         end else begin
           InvalidateRect(HWindow, @R, True);
         end;
       end;
       Dec(ExplodeState);
     end;
    end;

  { Move airplane across screen }
  if PlaneY > 0 then begin
    SetRect(R, PlaneX-10, PlaneY, PlaneX, PlaneY+45);
    InvalidateRect(HWindow, @R, true);
    DrawBMP(DC, PlaneX, PlaneY, Planes[0]);
    inc(PlaneX, 6+level div 3);
    if PlaneX > 620 then PlaneY := -1;
  end;

  ReleaseDC(HWindow, DC);
  if EndLevelTime = 0 then begin
    if not MissilesLeft and (MissilesToGo = 0) and (PlaneY < 0) then
      EndLevelTime := 8;
  end else begin
    dec(EndLevelTime);
    if EndLevelTime = 0 then begin
      SetMode(isEndLevel);
      ClearWindow;
    end;
  end;
end;

procedure TGameWindow.WMSize(var Message: TMessage);
begin
  if IsIconic(HWindow) then begin
    if TimerOn then StopTimer
    else CurTimerTime := 0;
  end else
    if CurTimerTime > 0 then StartTimer(CurTimerTime);
end;

{--------------- TApp ------------------------}

procedure TApp.InitMainWindow;
begin
  MainWindow := New(PGameWindow, Init(nil, 'Nuclear Winter'));
end;

{-------------Main Program--------------------}

var
  App: TApp;
begin
  if (GetSystemMetrics(sm_CXscreen) < 640) or
    (GetSystemMetrics(sm_CYscreen) < 400) then begin
      MessageBox(0, 'Sorry, you need a screen display '+
       'of at least 640 x 400 to run this program.',
       'Nuclear Winter', mb_Ok or mb_IconExclamation);
      Halt;
    end;

  App.Init('Nuclear Winter');
  App.Run;
  App.Done;
end.
