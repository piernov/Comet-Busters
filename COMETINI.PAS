(*********************************************************)
(**  COMETINI.PAS                                       **)
(**  Comet Busters! initialization routines             **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit CometIni;

{$C PRELOAD DISCARDABLE}

interface

uses
  WinTypes, WinProcs, Win31;

procedure ReadINIFile;
procedure WriteINIFile;
procedure ReadHiScores;
procedure WriteHiScores;
procedure PreInitApplication;
procedure LoadLanguageLib;
procedure ShowInitDialog;
procedure HideInitDialog;
procedure LoadHiScores;
procedure Setup;
procedure Cleanup;
procedure UserExitProc;
procedure CheckRegistration;

var
  INIFileName : PChar;

implementation

uses
  Objects, SysUtils, CometLib, GameLib, GameSnd, GameXtra, IMath, HiScore, BtnBar, MMSystem,
  GameCtrl, CometDlg
  {$IFNDEF nocomm},CometRem, Net{$ENDIF}
  {$IFDEF wing}, WinG, Sprite24{$ENDIF}
  {$IFDEF leak}, LeakFind{$ENDIF}
  ;

const
  DefaultGameSong = 'comet.mid';
  DefaultDeathSong = 'comet1.mid';
  DefaultHighScoreSong = 'comet2.mid';
  DefaultBackdropFile = 'cometbkg.bmp';
  DefaultGameFont = #0;
  DefGameKeys : array[0..MaxPlayers-1] of TGameKeys = (
    (331,333,328,0,57,285),
    (30,32,31,0,42,29),
    (75,77,72,0,82,80),
    (0,0,0,0,0,0)
  );

function GameFontEnumProc(var lf : TLogFont; var lpntm : TTextMetric;
  FontType : integer; lpData : pointer) : integer; export;
begin
  StrLCopy(PChar(lpData), lf.lfFaceName, lf_FaceSize);
  GameFontEnumProc := 0;
end;

const
  PlayerINIFormat = '%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%u';

procedure ReadHiScores;
begin
  HiScores.ReadFromINIFile(INIFileName, 'Scores');
  if HiScores.Count = 0 then begin
    HiScores.Insert(New(PHiScoreEntry, Init('SPF', 5000)));
  end;
end;

procedure WriteHiScores;
begin
  HiScores.WriteToINIFile(INIFileName, 'Scores');
end;

const
  GameTag = {$IFDEF scrnsave}'Screen Saver'{$ELSE}'Game'{$ENDIF};

procedure ReadINIFile;

  function GetProfileGameString(Key, Default : PChar) : PChar;
  var Buf : array[0..255] of char;
  begin
    GetPrivateProfileString(GameTag, Key, Default,
      Buf, sizeof(Buf), INIFileName);
    GetProfileGameString := StrNew(Buf);
  end;

  procedure LocateGameFont;
  { finds us a nice font for the game }
  type
    FontEnumType = 0..12;
  const
    DefFonts : array[FontEnumType] of PChar =
      ('INFORM','BAHAMAS','RENFREW','EUROTYPE','ERAS','ERIE',
       'PENGUIN','PEUGINOT','REVIVE 565','PALATINO','COMIC SANS MS',
       'TIMES NEW ROMAN','TIMES');
  var
    i : FontEnumType;
    Name : array[0..lf_FaceSize] of char;
    DC : HDC;
  begin
    DC := GetDC(0);
    Name[0] := #0;
    i := Low(i);
    repeat
      EnumFonts(DC, DefFonts[i], @GameFontEnumProc, @Name);
      inc(i);
    until (i > High(i)) or (Name[0] <> #0);
    if Name[0] = #0 then
      GameFontName := 'HELV'
    else begin
      Name[lf_FaceSize] := #0;
      GameFontName := StrNew(Name);
    end;
    ReleaseDC(0, DC);
  end;

  procedure ReadPlayer(PlyrNum : integer);
  var
    PlyrKey,Num : array[0..11] of char;
    Buf : array[0..79] of char;
    p : PChar;
    code, i : integer;
  begin
    StrCopy(PlyrKey, 'Player0');
    PlyrKey[6] := chr(PlyrNum+ord('1'));
    with Metrics[PlyrNum] do begin
      if not Bool(GetPrivateProfileString('Players', PlyrKey, nil, Buf,
          sizeof(Buf), INIFileName))
        or (sscanf(Buf, PlayerINIFormat, Metrics[PlyrNum]) = nil)
        or (GetChkSum(ControlType, sizeof(TPlayerMetrics)-2) <>
          ChkSum) then
      begin
        ControlType := 0;
        SpecialType := abil_Hyper;
        for i := 0 to ord(High(SpecType)) do
          Specs[SpecType(i)] := SpecLimit div 2;
        Keys := DefGameKeys[PlyrNum];
      end;
    end;
  end;

begin
  CheckRegistration;

  GameFontName := GetProfileGameString('FontName', DefaultGameFont);
  if GameFontName = nil then LocateGameFont;
  ReadHiScores;
  GameSong := GetProfileGameString('GameSong', DefaultGameSong);
  DeathSong := GetProfileGameString('EndSong', DefaultDeathSong);
  HighScoreSong := GetProfileGameString('HighScoreSong', DefaultHighScoreSong);
  BackdropFilename := GetProfileGameString('Backdrop', DefaultBackdropFile);
  with GameParams, VisualParams do begin
    StarsInBackground := Bool(GetPrivateProfileInt(GameTag, 'StarsInBackground',
      1, INIFileName));
    FragmentExplosions := Bool(GetPrivateProfileInt(GameTag, 'FragmentExplosions',
      1, INIFileName));
    PauseWhenInactive := Bool(GetPrivateProfileInt(GameTag, 'PauseWhenInactive',
      1, INIFileName));
    BulletsKillPlayers := Bool(GetPrivateProfileInt(GameTag, 'DeadlyBullets',
      0, INIFileName));
    TournamentMode := Bool(GetPrivateProfileInt(GameTag, 'TournamentMode',
      0, INIFileName));
    Difficulty := GetPrivateProfileInt(GameTag, 'Difficulty', 1, INIFileName);
    MsecPerFrame := GetPrivateProfileInt(GameTag, 'MsecPerFrame', DefMsecPerFrame, INIFileName);
    UpdateInterval := GetPrivateProfileInt(GameTag, 'UpdateInterval', 1, INIFileName);
    TournamentLevels := GetPrivateProfileInt(GameTag, 'TournamentLevels', 7, INIFileName);
    TournamentLives := GetPrivateProfileInt(GameTag, 'TournamentLives', 5, INIFileName);
    TournamentRocks := GetPrivateProfileInt(GameTag, 'TournamentRocks', 1, INIFileName);
  end;
  {$IFDEF ownjoy}
  JoyCanAccess := Bool(GetPrivateProfileInt(GameTag, 'Joystick',
    0, INIFileName));
  {$ENDIF}
  if not Bool(GetPrivateProfileInt(GameTag, 'Sound', 1, INIFileName)) then
    SetSound(SoundOn or sound_User);
  if not Bool(GetPrivateProfileInt(GameTag, 'Music', 1, INIFileName)) then
    SetMusic(MusicOn or sound_User);
  NumMixChan := GetPrivateProfileInt(GameTag, 'NumMixChan', 4, INIFileName);
  {$IFNDEF scrnsave}
  ReadPlayer(0); ReadPlayer(1);
  ReadPlayer(2); ReadPlayer(3);
  DefineJoyNumbers;
  with RemoteParams do begin
    Port := GetPrivateProfileInt('Remote', 'Port', 2, INIFileName);
    ConnectType := GetPrivateProfileInt('Remote', 'ConnectType', 0, INIFileName);
    GetPrivateProfileString('Remote', 'InitString', 'AT&F&C1&D2E0V1', InitString, sizeof(InitString), INIFileName);
    GetPrivateProfileString('Remote', 'DialString', 'ATDT', DialString, sizeof(DialString), INIFileName);
    GetPrivateProfileString('Remote', 'RemoteNode', '', RemoteName, sizeof(RemoteName), INIFileName);
    BaudRate := GetPrivateProfileInt('Remote', 'BaudRate', 19200, INIFileName);
    IPPort := word(GetPrivateProfileInt('Remote', 'IPPort', -15535, INIFileName));
  end;
  PacketStarveTime := GetPrivateProfileInt(GameTag, 'PktTimeout', PacketStarveTime, INIFileName);
  FullScreenDesired := Bool(GetPrivateProfileInt(GameTag, 'FullScreen', 0, INIFileName));
  {$ENDIF}
end;

function WritePrivateProfileInt(ApplicationName, KeyName : PChar;
  Value : longint; FileName: PChar): Bool;
var s : array[0..20] of char;
    code : integer;
begin
  Str(Value, s);
  WritePrivateProfileInt :=
    WritePrivateProfileString(ApplicationName, KeyName, s, FileName);
end;

procedure WriteINIFile;
  procedure WritePlayer(PlyrNum : integer);
  var
    PlyrKey : array[0..11] of char;
    Buf : array[0..79] of char;
  begin
    StrCopy(PlyrKey, 'Player0');
    PlyrKey[6] := chr(PlyrNum+ord('1'));
    Metrics[PlyrNum].ChkSum := GetChkSum(Metrics[PlyrNum], sizeof(TPlayerMetrics)-2);
    wvsprintf(Buf, PlayerINIFormat, {$IFDEF WIN32}@{$ENDIF}Metrics[PlyrNum]);
    WritePrivateProfileString('Players', PlyrKey, Buf, INIFileName);
  end;
(*var
  fh : THandle;*)
begin
(*
  { first see if the file is writeable so no crappy error messages }
  fh := _lopen(INIFileName, OF_WRITE);
  if fh <> HFILE_ERROR then begin
    _lclose(fh);
    _lopen(INIFileName, OF_
    S.Init(INIFileName, stCreate);
    if S.Status <> stOK then Exit;
  end;
  S.Done;
*)
(*
  WritePrivateProfileString(GameTag, 'FontName', GameFontName, INIFileName);
*)
  WritePrivateProfileString(GameTag, 'GameSong', GameSong, INIFileName);
  {$IFNDEF scrnsave}
  WritePrivateProfileString(GameTag, 'EndSong', DeathSong, INIFileName);
  WritePrivateProfileString(GameTag, 'HighScoreSong', HighScoreSong, INIFileName);
  {$ENDIF}
  WritePrivateProfileString(GameTag, 'Backdrop', BackdropFilename, INIFileName);
  with GameParams, VisualParams do begin
    WritePrivateProfileInt(GameTag, 'StarsInBackground', longint(StarsInBackground), INIFileName);
    WritePrivateProfileInt(GameTag, 'FragmentExplosions', longint(FragmentExplosions), INIFileName);
    WritePrivateProfileInt(GameTag, 'Difficulty', Difficulty, INIFileName);
    {$IFNDEF scrnsave}
    WritePrivateProfileInt(GameTag, 'PauseWhenInactive', longint(PauseWhenInactive), INIFileName);
    WritePrivateProfileInt(GameTag, 'DeadlyBullets', longint(BulletsKillPlayers), INIFileName);
    WritePrivateProfileInt(GameTag, 'TournamentMode', longint(TournamentMode), INIFileName);
    WritePrivateProfileInt(GameTag, 'TournamentLevels', longint(TournamentLevels), INIFileName);
    WritePrivateProfileInt(GameTag, 'TournamentLives', longint(TournamentLives), INIFileName);
    WritePrivateProfileInt(GameTag, 'TournamentRocks', longint(TournamentRocks), INIFileName);
    {$ENDIF}
  end;
  WritePrivateProfileInt(GameTag, 'Sound', longint(SoundOn and sound_User = 0), INIFileName);
  WritePrivateProfileInt(GameTag, 'Music', longint(MusicOn and sound_User = 0), INIFileName);
  {$IFDEF ownjoy}
  WritePrivateProfileInt(GameTag, 'Joystick', longint(JoyCanAccess), INIFileName);
  {$ENDIF}
  WritePrivateProfileInt(GameTag, 'NumMixChan', NumMixChan, INIFileName);
  {$IFNDEF scrnsave}
  WritePlayer(0); WritePlayer(1);
  WritePlayer(2); WritePlayer(3);
  with RemoteParams do begin
    WritePrivateProfileInt('Remote', 'Port', Port, INIFileName);
    WritePrivateProfileInt('Remote', 'ConnectType', ConnectType, INIFileName);
    WritePrivateProfileString('Remote', 'DialString', DialString, INIFileName);
    WritePrivateProfileString('Remote', 'InitString', InitString, INIFileName);
    WritePrivateProfileString('Remote', 'RemoteNode', RemoteName, INIFileName);
    WritePrivateProfileInt('Remote', 'BaudRate', BaudRate, INIFileName);
    WritePrivateProfileInt('Remote', 'IPPort', IPPort, INIFileName);
  end;
  WritePrivateProfileInt(GameTag, 'FullScreen', longint(FullScreenDesired), INIFileName);
  {$ENDIF}
end;

procedure InitSounds;
const
  SndPriorty : array[1..NumSounds] of byte =
    (15, 5, 15, 5, 15, 10, 5, 25, 10, 10, 5, 2, 5, 10, 5, 30, 5, 5);
var i : integer;
begin
  SoundType := sound_None;
  FillChar(Sounds, sizeof(Sounds), 0);
  if InitWaveSound(MainWnd, WAVE_FORMAT_1M08, 0, false) then begin
    { setup for wave sounds }
    for i := 1 to NumSounds do begin
      Sounds[i] := New(PWave, LoadRes(HSndLib, PChar(i+WAV_FIRST), SndPriorty[i]));
      if Sounds[i] = nil then
        Sounds[i] := New(PSound, Init);
{        FatalError(Str_NoMemSounds, MB_ICONEXCLAMATION);}
    end;
    SoundType := sound_Wave;
  end else begin
    for i := 1 to NumSounds do
      Sounds[i] := New(PSound, Init);
    {$IFNDEF win32}
    if InitSpkrSound(1024) then begin
      { setup for speaker sounds }
      { don't forget to make all these sounds! }
      Sounds[1] := New(PNoise, Init(200, -1, 500, 2, 150));
      Sounds[2] := New(PNoise, Init(100, 0, 200, 2, 150));
      Sounds[3] := New(PNoise, Init(2000, -1, 300, 0, 200));
      Sounds[4] := New(PNoise, Init(2000, -25, 0, 3, 50));
      Sounds[5] := New(PNoise, Init(100, 0, 0, 10, 200));
      Sounds[6] := New(PNoise, Init(2000, -80, 0, 50, 20));
      Sounds[7] := New(PNoise, Init(200, 32, 500, 0, 50));
      Sounds[8] := New(PNoise, Init(1, 10000, 0, 0, 500));
      Sounds[9] := New(PNoise, Init(600, 0, 0, 10, 50));
      Sounds[10] := New(PNoise, Init(1, 100, 0, 1000, 200));
      Sounds[11] := New(PNoise, Init(150, -2, 20, 0, 40));
      Sounds[14] := New(PNoise, Init(2000, -80, 0, 50, 20));
      Sounds[16] := New(PNoise, Init(2000, -30, 0, 35, 0));
      Sounds[17] := New(PNoise, Init(100, 0, 200, 2, 150));
      Sounds[18] := New(PNoise, Init(100, 0, 200, 2, 150));
      SoundType := sound_Spkr;
    end else {$ENDIF} begin
      EnableWindow(GetDlgItem(BtnBarWnd, ID_SOUND), false);
        { no sound available }
      SoundOn := sound_NoHardware;
    end;
  end;
  { initialize button texts }
  SetSound(SoundOn);
  SetMusic(MusicOn);
  if GetMIDINumDevs = 0 then
    EnableWindow(GetDlgItem(BtnBarWnd, ID_MUSIC), false);
end;

procedure MakePalette;
{$IFDEF wing}
begin
  Pal := WinGCreateHalftonePalette;
end;
{$ELSE}
var LogPal : PLogPalette;
    Res,HRes : THandle;
begin
  Res := FindResource(HInstance, PChar(1), 'PALETTE');
  if Res > 0 then begin
    HRes := LoadResource(HInstance, Res);
    if HRes > 0 then begin
      LogPal := LockResource(HRes);
      Pal := CreatePalette(LogPal^);
      UnlockResource(HRes);
      FreeResource(HRes);
    end;
  end;
end;
{$ENDIF}

procedure InitShapes(DC : HDC);
var
  i : integer;
begin
  InitShipShapes(DC, 1);
  New(TorpShp, Init(HLib, PChar(BMAP_SHIPTORP), DC, 4, 0));
  AddShape(TorpShp);
  New(AlienTorpShp, Init(HLib, PChar(BMAP_ALIENTORP), DC, 1, 0));
  AddShape(AlienTorpShp);
  New(PestShp, Init(HLib, PChar(BMAP_PEST), DC, PestFrames, 0));
  AddShape(PestShp);
  for i := 0 to 2 do begin
    New(ExploShps[i], Init(HLib, PChar(BMAP_EXPLOSION+i), DC, 5, 0));
    AddShape(ExploShps[i]);
  end;
  New(AlienShps[0], Init(HLib, PChar(BMAP_ALIEN1), DC, 8, 0));
  AddShape(AlienShps[0]);
  for i := 0 to 1 do begin
    New(ThrustShp[i], Init(HLib, PChar(BMAP_THRUST+i), DC, 32, 0));
    AddShape(ThrustShp[i]);
  end;
end;

procedure LoadHiScores;
begin
  HiScores.Init(11, 10);
end;

procedure Setup;
const
  SplashMsg = 'Initializing ...'+#13+'Please wait';
var
  i : integer;
  Ship : PShip;
  Dlg : HWnd;
  ScoreBoard : PLEDReadout;
  LivesBoard : PLivesLeft;
  R : TRect;
begin
{  ShowSplashScreen(R, HLib, PChar(BMAP_SPLASH), SplashMsg, RGB(0, 255, 220));}
  { create stage }
  FillChar(ShieldShp, sizeof(ShieldShp), 0);
  Randomize;
  MakeSinTbl;
  {$IFNDEF scrnsave}
  {$IFNDEF wing}
  InitLEDS(HLib);
  {$ENDIF}
  {$ENDIF}
  InitSounds;
  LoadHiScores;
  ReadINIFile;

  MakePalette;
  MainDC := GetDC(MainWnd);
  SelectPalette(MainDC, Pal, true);
  RealizePalette(MainDC);
  InitShapes(MainDC);
  {$IFDEF wing}
  Stage.LoadBackdrop(BackdropFilename);
  {$ENDIF}

{  InvalidateRect(0, @R, false);}

  Level := 0;
  GameMode := gmode_None;
  WaitTime := 0;
end;

procedure LoadLanguageLib;
{ load the COMET??? library where ??? is the country code
  set up under the Windows Control Panel -- English is ENU,
  German is DEU, etc.
}
var
  LangCode : array[0..3] of char;
  LangCodePtr : pointer;
  Lib : THandle;
begin
  LangCodePtr := @LangCode;
  GetProfileString('Intl', 'sLanguage', 'ENU', LangCode, sizeof(LangCode));
  {$IFDEF langtest}
  LangCode := 'DEU'#0;
  {$ENDIF}
  Lib := LoadLibrary(sprintf('COMET%s.DLL', LangCodePtr));
  if Lib < 32 then begin
    Lib := LoadLibrary('COMETENU.DLL');
    if Lib < 32 then
      FatalError(STR_NOLOADLANGLIB, MB_ICONHAND);
  end;
  HStrLib := Lib;
end;

var
  OldExitProc : pointer;

procedure PreInitApplication;
begin
  OldExitProc := ExitProc;
  ExitProc := @UserExitProc;

  ShapeList.Init(16, 16);
  {$IFDEF wing}ClearSystemPalette;{$ENDIF}
  Stage.Init;
  FillChar(Sounds, sizeof(Sounds), 0);
end;

const
  SplashDlg : HWnd = 0;
{$IFNDEF SPLASH}

procedure ShowInitDialog;
begin
  SplashDlg := CreateDialog(HStrLib, PChar(DLG_INIT), 0, nil);
  CenterWindow(SplashDlg, nil);
  ShowWindow(SplashDlg, SW_SHOWNOACTIVATE);
  UpdateWindow(SplashDlg);
end;

procedure HideInitDialog;
begin
  if SplashDlg <> 0 then begin
    DestroyWindow(SplashDlg);
    SplashDlg := 0;
  end;
end;

{$ELSE}
var
  SplashR : TRect;
procedure ShowInitDialog;
const
  SplashMsg = 'Please wait...';
begin
  ShowSplashScreen(SplashR, HInstance, PChar(BMAP_SPLASH), ''{SplashMsg},
    RGB(0, 255, 220));
  SplashDlg := 1;
end;

procedure HideInitDialog;
begin
  if SplashDlg <> 0 then begin
    InvalidateRect(HWND_DESKTOP, @SplashR, false);
    SplashDlg := 0;
  end;
end;

{$ENDIF}

procedure UserExitProc;
var i : integer;
begin
  ExitProc := OldExitProc;

  StopTimer;
  HideInitDialog;
  ShapeList.Done;
  DeleteObject(Pal);
  {$IFNDEF wing}
  DoneLEDS;
  {$ENDIF}
  DoneBtnBar;

  Stage.Done;
  { for WAVEMIX, gotta dispose the sounds before closing device }
  if SoundType = sound_Wave then
    CloseWaveChannels;
  for i := 1 to NumSounds do
    if Sounds[i] <> nil then Dispose(Sounds[i], Done);
  case SoundType of
    sound_Wave : DoneWaveSound;
    {$IFNDEF win32}
    sound_Spkr : DoneSpkrSound;
    {$ENDIF}
  end;
  {$IFNDEF EXELIB}
  if HLib > 0 then FreeLibrary(HLib);
  if HSndLib > 0 then FreeLibrary(HSndLib);
  {$ENDIF}
  if (HStrLib > 0) and (HStrLib <> HInstance) then FreeLibrary(HStrLib);
  {$IFDEF STRESS}
  FreeAllGDIMem;
  FreeAllMem;
  {$ENDIF}
  WinHelp(MainWnd, 'COMET.HLP', HELP_QUIT, 0);
end;

procedure Cleanup;
var
  a : byte;
begin
  ReleaseDC(MainWnd, MainDC);
  WriteINIFile;
  {$IFNDEF nocomm}
  if RS <> nil then begin
    RemoteDisconnect;
  end;
  {$ENDIF}
end;

procedure CheckRegistration;
var
  key : word;
  F : file;
begin
  if GetPrivateProfileString('Registration', 'UserName', '', UserName, sizeof(UserName),
    IniFileName) <> 0
  then begin
    key := word(GetPrivateProfileInt('Registration', 'ID', 0, IniFileName));

    if (StrLen(UserName) < 4) or (GetChkSum(UserName, StrLen(UserName)) <> key) then
      WinProcs.MessageBox(0, GameLib.LoadStr(STR_REGINVALID), nil, MB_OK or MB_ICONHAND)
    else
      IsShareware := DEFAULT_SHAREWARE;
  end else begin
    StrCopy(UserName, 'Someone');
  end;
end;

end.
