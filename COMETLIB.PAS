(*********************************************************)
(**  COMETLIB.PAS                                       **)
(**  Comet Busters! common objects, procs, and constants**)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit CometLib;
{$C FIXED PRELOAD PERMANENT}

interface

uses
  Objects, SysUtils, WinTypes, WinProcs, Sprite24, GameSnd, GameXtra, GameLib,
  HiScore, IMath, MMSystem, Joystick, GameCtrl, Messages
  {$IFNDEF nocomm}, GameSock{$ENDIF};

{$I COMET.INC}
{$I COMET1.INC}

const
  { special ability constants }
  abil_None    = 0;
  abil_Hyper   = 1;
  abil_Shield  = 2;
  abil_Disrupt = 3;
  abil_Cloak   = 4;

  control_Keyboard = 0;
  control_Joystick = 1;
  control_Remote = 2;

  MaxBulletsOut  = 4;

var
  GameWnd, MainWnd, BtnBarWnd, TitleWnd : THandle;
  MainDC : HDC;

type
  PShip = ^TShip;
  SpecType = (specBulletSpeed, specThrustSpeed, specMaxSpeed,
              specRotSpeed, specAbilityStrength);

  TPlayerMetrics = object       { metrics that can be changed during play }
    ControlType : integer;     { type of control }
    SpecialType : integer;     { type of special abilty }
    Specs : array[SpecType] of integer; { player attributes }
    Keys : TGameKeys;           { key definitions }
    JoyCenter : TUPoint;        { joystick center position }
    JoyNumber : integer;        { joystick index }
    ChkSum : word;
  end;

  TBonusType = (CronieLoverBonus, MarksmanBonus, AlienFirstBonus);

  StarRec = record             { record for a background star }
    Color : TColorRef;
    Pos : TPoint;
  end;

  PPlyrStatus = ^TPlyrStatus;  { status for a player - score, lives, etc. }
  TPlyrStatus = object
    num,shpnum : integer;              { # of player }
    ScoreBoard : PLEDReadout;
    LivesBoard : PLivesLeft;
    Score : longint;
    Lives : integer;
    CurShip : PShip;            { current ship in play, or NIL }
    NewShipPos : TPoint;        { position where new ships should appear }
    ReturnTime : word;          { time left before new ship can appear }
    PlyrColor : TColorRef;      { player's assigned color }
    ChatMsg : PBigText;
    ChatTime : word;            { time since last chat msg }
    Ctrl : PController;

    procedure Setup(BoardX, BoardY, NewX, NewY, PlyrNum, LookLike : integer);
    procedure Reset;
    procedure AddScore(n : integer);
    procedure AddBonus(b : TBonusType);
    procedure AddNewShip;
    function SafeToAdd : boolean;
    procedure MakeControls;
  end;

  PPlyr = ^TPlyr;
  TPlyr = object(TPlayer)
    Mass : integer; { mass of the player }
    procedure Setup; virtual;
    procedure Explode(siz : integer);
    procedure Move; virtual;
  end;

  PPest = ^TPest;
  TPest = object(TPlyr)
    IncFrame : boolean;
    procedure Kill; virtual;
    procedure Move; virtual;
    procedure Setup; virtual;
    procedure Cue; virtual;
  end;

  PTorpedo = ^TTorpedo;

  PCraft = ^TCraft;
  TCraft = object(TPlyr)
    BulletsOut : integer;         { how many bullets are in play }
    Bullets : array[0..MaxBulletsOut-1] of PTorpedo;
    destructor Done; virtual;
    procedure Kill; virtual;
    procedure Setup; virtual;
    procedure AddScore(n : integer); virtual;
    procedure AddBullet(P : PTorpedo);
    procedure RemoveBullet(P : PTorpedo);
  end;

  PAlien = ^TAlien;
  TAlien = object(TCraft)
    procedure Setup; virtual;
    procedure Cue; virtual;
    procedure Shoot;
  end;

  TShip = object(TCraft)
    Stat : PPlyrStatus;   { points to the ship's TPLYRSTATUS }

    { stuff relating to movement }
    Rotate : integer;     { direction currently rotating, 0 if not }
    Thrust, Fire : boolean;
    MaxShieldStrength, ShieldStrength : integer;

    { constants derived from player attributes }
    RotSpeed, ThrustSpeed, BulletSpeed : integer;
    VelocAtten : longint;
    AbilityStrength : integer;

    { stuff that controls special abilities }
    Materializing : byte; { time left until no longer invulnerable }
    Hyperspace : byte;
    Hypercharge : byte;
    {$IFDEF wormhole}
    WormHole : boolean;
    {$ENDIF}
    ShieldsOn : boolean;
    Disruptor : boolean;
    Cloaked   : integer; { 0 = not cloaked, >0 = cloaking, <0 = coming out }
    Cloaktime : integer; { time you are cloaked }
    ThrustID : word;
    ShieldID : word;
    DisruptID : word;
    FairyDust : array[0..255] of TPoint; { what appears when you materialize }
    destructor Done; virtual;
    procedure Setup; virtual;
    procedure SetParams;
    procedure Cue; virtual;
    procedure Move; virtual;
    procedure Kill; virtual;
    function Message(Command, wParam : word; lParam : longint) : longint;
      virtual;
    procedure Bounce(p : PPlyr);
    { bounces ship off object P -- makes him spin out of control }
    procedure AddScore(n : integer); virtual;
    procedure SetAbility(State : boolean);
    procedure Draw(ROP : longint); virtual;
    procedure StopSound(var ID : word);
  end;

  PRock = ^TRock;
  TRock = object(TPlyr)
    RockSize : byte; { 0-biggest, 2-smallest }
    constructor Init(TheStage : PStage; X, Y : integer; Cost : PCostume;
      ARockSize : byte);
{    procedure Move; virtual;}
    procedure Setup; virtual;
    procedure Cue; virtual;
    procedure Kill; virtual;
  end;

  TTorpedo = object(TPlyr)
    Owner : PCraft;       { who shot this shot }
    TimeLeft : integer;   { time until the shot expires }
    Deflects : boolean;   { whether or not a ship's shield deflects }
    destructor Done; virtual;
    procedure Setup; virtual;
    procedure Cue; virtual;
    procedure Kill; virtual;
  end;

  PExplosion = ^TExplosion;
  TExplosion = object(TPlyr)
    procedure Move; virtual;
  end;

  PBoom = ^TBoom;
  TBoom = object(TPlyr)
    procedure Setup; virtual;
    destructor Done; virtual;
    procedure Move; virtual;
  end;

  TGameStage = object(TStage)
    procedure DrawBackground(DC : HDC); virtual;
  end;

const
  DefMSecPerFrame = 42;          { msec/tick }
  StartingLevel = 0;
  NumSounds = 18;
  NumMoons = 8; { # of rock shapes }
  NumLives = 5;
  HyperTime = 8;
  HyperSpeed = 256 div HyperTime;
  HyperSoundPlay = 12;
  HyperDelay = 36;
  RotHit = 2;
  MaxPlayers = 4;
  MaxStars = 200;
  StageMax = 30000;
  DefShieldStrength = 18*9;
  ShieldChargeFreq = 63; { 1 unit every N frames }
  SpecLimit = 2048; { high limit of Metrics.Specs array }
  PestFrames = 32;

  { game modes -- tell what state the game is currently in }
  gmode_None = 127;
  gmode_Stop = 0;
  gmode_Attract = 1;
  gmode_HiScores = 3;
  gmode_Playing = [9,10,11];
  gmode_AttractMode = [0..8];
  gmode_TournamentWin = 9;
  gmode_NewLevel = 10;
  gmode_Play = 11;
  gmode_GameOver = 12;
  gmode_LogHighScore = 14;

  { all the different sounds }
  snd_PlayerBlowUp = 1;
  snd_Explode      = 2;
  snd_NewShip      = 3;
  snd_Shoot        = 4;
  snd_HyperSpace   = 5;
  snd_Bounce       = 6;
  snd_AlienShoot   = 7;
  snd_WonNewLife   = 8;
  snd_Pop          = 9;
  snd_CroniesOut   = 10;
  snd_RockBounce   = 11;
  snd_Thrust       = 12;
  snd_Shield       = 13;
  snd_ShieldBounce = 14;
  snd_Disrupt      = 15;
  snd_Bonus        = 16;
  snd_ExplodeLo    = 17;
  snd_ExplodeHi    = 18;

var
  Level : integer;

  AlienFreq,             { how often the alien comes out }
  NextAlien : integer;   { how many frames until the next alien }
  NumRocks,
  NumRocksLeft,          { total number of rocks to be blasted }
  NumHatchRocks,         { number of rocks on this level that *could* hatch, }
  HatchesLeft : integer; { & the number remaining that *will* hatch }
  GameFrame : longint;   { frame # of game in progress -- 1 frame every
                           55 msec }
  ActiveBonuses : set of TBonusType;

  ShapeList : TCollection; { all the Costumes in the game }
  ShipShp : array[0..MaxPlayers-1] of PBitCostume;
  ShieldShp : array[0..MaxPlayers-1] of PBitCostume;
  PestShp,
  TorpShp,
  AlienTorpShp : PBitCostume;
  RockShps : array[0..2] of PBitCostume;
  ExploShps : array[0..2] of PBitCostume;
  AlienShps : array[0..0] of PBitCostume;
  ThrustShp : array[0..1] of PBitCostume;

  { player status records -- contain score, lives, etc. }
  Stats : array[0..MaxPlayers-1] of TPlyrStatus;
  { player metrics (attributes) }
  Metrics : array[0..MaxPlayers-1] of TPlayerMetrics;
  { all the sounds in the game }
  Sounds : array[1..NumSounds] of PSound;

  GameMode : integer;
  WaitTime : integer;           { # of ticks before switching to next game mode }
  CurTimerTime : word;
  TimerID : cardinal;

  HiScores : THiScoreList;
  PlyrHiScoreNum : integer;
  InitialsText : PBigText;
  LetterPos : byte;

  GameFontName : PChar;
  GameSong,
  DeathSong,
  HighScoreSong : PChar;
  BackdropFilename : PChar;
  PauseWhenInactive : boolean;
  GameParams : record
    Difficulty : byte;
    FragmentExplosions,
    BulletsKillPlayers,
    TournamentMode : boolean;
    UpdateInterval : word;
    MsecPerFrame : word;
    TournamentLevels,
    TournamentLives,
    TournamentRocks : byte;
    _Filler : array[11..31] of byte;
  end;
  VisualParams : record
    StarsInBackground : boolean;
  end;
  TournamentPlay : boolean;

  MaxRockVel : integer;
  RocksPerLevel : integer;
  AlienSpeed : integer;
  SafeRadius     : word;        { used for seeing if it is safe to come back
                                  into the game }
  VelocRadius    : word;        { ditto }
  {$IFDEF ownjoy}
  JoyCanAccess   : boolean;
  {$ENDIF}

  Stage : TGameStage; { the main playfield }
  StageMin : integer;
  StageMinRes, StageMaxRes : integer;

  Stars : array[0..MaxStars] of StarRec;        { background stars }

var
  RemoteParams : record
    Port : byte;
    ConnectType : byte; { 0 = direct; 1 = modem; 2 = network }
    BaudRate : longint;
    InitString,
    DialString,
    RemoteName : array[0..79] of char;
    IPPort : word;
  end;
  Originator : boolean; { TRUE if the local machine originated the call }
  Received : boolean;   { TRUE if ok to do next scrn update }

{$IFNDEF nocomm}
const
  RS : PGameSocket = nil;
{$ELSE}
const
  RS = nil;
{$ENDIF}

const
  pause_Inactive = 1;
  pause_User = 2;

  sound_None = 0;
  sound_Wave = 1;
  sound_Spkr = 2;
  sound_User = 1;
  sound_Attract = 2;
  sound_NoHardware = 4;

  scor_Tourwin = 5;

  SoundOn : byte = 0;
  MusicOn : byte = 0;
  SoundType : byte = sound_None;
  NumLocalPlayers : integer = 1;
  NumRemotePlayers : integer = 0;
  NumPlayers : integer = 1;

  SongPlaying : PChar = nil;
  Pal : HPalette = 0;
  TimerOn : boolean = false;
  TimerResolution = 14;
  Paused  : byte = pause_Inactive; { if nonzero, game is paused }

  RockShpsLevel : integer = 0;
  ShipShpsLoaded : integer = 0;
  HLib : THandle = 0;
  HSndLib : THandle = 0;

  FullScreenDesired : boolean = false;

{$IFNDEF oldtimer}
var
  TimerProcessed : boolean;
{$ENDIF}

type
  TCheatType = (cheat_Phaseout, cheat_Jugger, cheat_Nuke, cheat_Autofire);
var
  CheatsWereOn : boolean;
{$IFDEF cheat}
  CheatsOn : set of TCheatType;
{$ELSE}
const
  CheatsOn = [];
{$ENDIF}
const
  DEFAULT_SHAREWARE = false;
  IsShareware : boolean = DEFAULT_SHAREWARE;
var
  UserName : array[0..127] of char;

function SetSound(state : word) : boolean;
function SetMusic(state : word) : boolean;
function StartMidiSong(FileName : PChar) : boolean;
procedure StopMidiSong;
procedure SetBtnBarText(ID : THandle; Txt : PChar);
procedure AddShape(Shp : PCostume);
procedure InitShipShapes(DC : HDC; Num : integer);
procedure UpdateShipShapes;
procedure StartTimer(Time : word);
procedure StopTimer;

implementation

const
  BulletLast     = 20;
  TimeToReturn   = 50;
  HyperRechargeTime  = 150;
  MaterializeTime = 30;
  MinPests = 4;
  MaxPests = 8;

  Rock_Mass    = 80;
  Ship_Mass    = 20;
  Torpedo_Mass = 10;
  Boom_mass    = 2;
  Pest_mass    = 10;

  ScoreAmts : array[0..8] of integer =
    (20, 50, 100, { rocks }
     150, { pest}
     250, { alien }
     1, {tournament}
     500, { bonuses }
     5000,
     1000
    );
  scor_Rocks = 0;
  scor_Pest = 3;
  scor_Alien = 4;
  scor_Bonuses = 6;
  NewShipScore = 10000;   { score which gets you a new ship }
const
  CloudPixelsFactor = {$IFDEF wing}1{$ELSE}2{$ENDIF};

type
  TVMTPtr = {$IFDEF win32}integer{$ELSE}word{$ENDIF};

procedure SetBtnBarText(ID : THandle; Txt : PChar);
begin
  SendMessage(GetDlgItem(BtnBarWnd, ID), WM_SETTEXT, 0, longint(Txt));
end;

procedure TGameStage.DrawBackground(DC : HDC);
var i : integer;
begin
  inherited DrawBackground(DC);
  if VisualParams.StarsInBackground {$IFDEF wing}and (BackdropBits = nil){$ENDIF} then
  begin
    for i := 0 to MaxStars do with Stars[i] do begin
      SetPixel(DC, Pos.X, Pos.Y, Color);
    end;
  end;
end;

procedure TPlyrStatus.Setup;
const
  ShipMaskColor : array[0..MaxPlayers-1] of TColorRef =
    ($FFFF00,$FF00FF,$00FF00,$00FFFF);
begin
  Num := PlyrNum;
  ShpNum := Looklike;
  NewShipPos.X := NewX;
  NewShipPos.Y := NewY;
  New(ScoreBoard, Init(BoardX, BoardY, @Score, ShpNum*8));
  Stage.Props.Insert(ScoreBoard);
  PlyrColor := ShipMaskColor[Shpnum];
  New(LivesBoard, Init(BoardX, BoardY+24, @Lives, ShipShp[ShpNum], PlyrColor));
  Stage.Props.Insert(LivesBoard);
  Ctrl := nil;
  ChatMsg := nil;
  ChatTime := 0;
end;

procedure TPlyrStatus.Reset;
begin
  CurShip := nil;
  Score := 0;
  Lives := NumLives;
  if TournamentPlay then
    Lives := GameParams.TournamentLives;
  ReturnTime := 0;
  MakeControls;
end;

procedure TPlyrStatus.AddScore;
begin
  if (Score div NewShipScore) < ((Score+ScoreAmts[n]) div NewShipScore) then
  begin
    Sounds[snd_WonNewLife]^.Play;
    LivesBoard^.AddNewLife;
  end;
  inc(Score, ScoreAmts[n]);
  case n of
    scor_Pest :
      ActiveBonuses := ActiveBonuses - [CronieLoverBonus];
    scor_Rocks + 2 : if (NumRocksLeft = 0) then begin
      AddBonus(CronieLoverBonus);
      AddBonus(MarksmanBonus);
    end;
    scor_Alien :
      AddBonus(AlienFirstBonus);
  end;
  ActiveBonuses := ActiveBonuses - [AlienFirstBonus];
  ScoreBoard^.PropDirty := true;
end;

procedure TPlyrStatus.AddBonus(b : TBonusType);
begin
  if b in ActiveBonuses then begin
    Sounds[snd_Bonus]^.Play;
    inc(Score, ScoreAmts[ord(b) + scor_Bonuses] *
      (Level * GameParams.Difficulty));
    ActiveBonuses := ActiveBonuses - [b];
  end;
end;

function SafeHaven(x, y : integer; ExcludePlyr : PPlayer) : boolean;
var i : integer;
    Dist,Veloc : word;
    P : TPoint;
    ply : PPlayer;
begin
  SafeHaven := true;
  if Stage.Objs.Count = 0 then Exit;
  for i := 0 to Stage.Objs.Count-1 do begin
    Ply := PPlayer(Stage.Objs.At(i));
    if Ply^.ChkCollide and (Ply <> ExcludePlyr) then
    with Ply^ do begin
      Dist := Abs(X-Pos.X) shr 1 + Abs(Y-Pos.Y) shr 1;
      Veloc := Abs(Vel.X)+Abs(Vel.Y);
      if Dist < SafeRadius+LongMul(VelocRadius, Veloc) then begin
        SafeHaven := false;
        Exit;
      end;
    end;
  end;
end;

function TPlyrStatus.SafeToAdd : boolean;
begin
  if ReturnTime > 0 then begin
    dec(ReturnTime);
    SafeToAdd := false;
    Exit;
  end;
  SafeToAdd := SafeHaven(NewShipPos.X, NewShipPos.Y, nil);
end;

procedure TPlyrStatus.AddNewShip;
begin
  if CurShip <> nil then Exit;
  CurShip := New(PShip, Init(@Stage, NewShipPos.X, NewShipPos.Y, ShipShp[Shpnum]));
  with CurShip^ do begin
    Stat := @Self;
    SetParams;
    MaxShieldStrength := MulDiv(DefShieldStrength, AbilityStrength, 24576);
    ShieldStrength := MaxShieldStrength;
  end;
  Ctrl^.Reset;
  Ctrl^.Client := CurShip;

  Stage.Add(CurShip);
  Sounds[snd_NewShip]^.Play;

  LivesBoard^.KillLife;
end;

procedure TPlyrStatus.MakeControls;
begin
  with Metrics[num] do begin
    if Ctrl <> nil then Dispose(Ctrl, Done);
    Ctrl := nil;
    if (RS <> nil) and (num >= NumLocalPlayers) then begin
      ctrl := New(PRemoteController, Init(CurShip, RS));
    end else begin
      case ControlType of
        control_Keyboard :
          Ctrl := New(PKeybdController, Init(CurShip, @Keys));
        control_Joystick :
          Ctrl := New(PJoyController, Init(CurShip, JoyNumber, @JoyCenter));
      end;
    end;
  end;
end;

procedure TExplosion.Move;
begin
  inherited Move;
  inc(Frame);
  if Frame = 4 then Kill;
end;

procedure TBoom.Setup;
begin
  inherited Setup;
  Status := Status or plyr_NoRgnAdd or plyr_Invulnerable;
  Mass := Boom_Mass;
end;

procedure TBoom.Move;
begin
  inherited Move;
  Frame := (256*4-Size.X)*2;
  inc(Size.X, 40);
  inc(Size.Y, 40);
  if Size.X > 256*4 then
    Kill;
end;

destructor TBoom.Done;
var
  R : TRect;
  Rgn : HRgn;
begin
  GetRect(R);
  {$IFNDEF wing}
  Rgn := CreateRectRgnIndirect(R);
  AddRgn(Stage^.DrawRgn, Rgn);
  Check(DeleteObject(Rgn));
  {$ELSE}
  { *** }
  {$ENDIF}
{  Status := Status and not plyr_NoRgnAdd;
  Draw(0, SRCCOPY);}
  Costume^.Free;
  inherited Done;
end;

procedure TPlyr.Setup;
begin
  Mass := 0;
  Status := Status or plyr_WrapAround;
end;

procedure TPlyr.Explode(siz : integer);
var expl : PExplosion;
    cloud : PBoom;
    R : TRect;
begin
  if siz <= 2 then begin
    if GameParams.FragmentExplosions then begin
      GetRect(R);
      New(cloud, Init(Stage, Pos.X, Pos.Y,
        New(PPixelCloud, Init(Pal, @Self,
          ISqrt(LongMul(R.right-R.left, R.bottom-R.top)) div CloudPixelsFactor
        ))
      ));
      cloud^.Vel := Vel;
      Stage^.Add(cloud);
    end;
  end else
    dec(siz);

  expl := New(PExplosion, Init(Stage, Pos.X, Pos.Y, ExploShps[siz]));
  {if siz = 2 then }siz := 1; { at smallest exploision size, use smaller shape }
  expl^.Size.X := 512 shr siz;
  expl^.Size.Y := expl^.Size.X;
  expl^.Status := plyr_Invulnerable;
  Stage^.Add(expl);
end;

procedure TPlyr.Move;
begin
{gravity}{  dec(Vel.X, Pos.X div 1500);
  dec(Vel.Y, Pos.Y div 1500);}
  inherited Move;
end;

procedure TTorpedo.Setup;
begin
  inherited Setup;
  Mass := Torpedo_Mass;
  TimeLeft := BulletLast;
  Deflects := false;
end;

destructor TTorpedo.Done;
begin
  if Owner <> nil then
    Owner^.RemoveBullet(@Self);
  inherited Done;
end;

procedure TTorpedo.Cue;
begin
  if TimeLeft > 0 then
    Dec(TimeLeft)
  else begin
    if (Owner <> nil) and (typeof(Owner^) = typeof(TShip)) then begin
      { if he missed, he loses the marksman bonus }
      ActiveBonuses := ActiveBonuses - [MarksmanBonus];
    end;
    Kill;
  end;
end;

procedure TTorpedo.Kill;
begin
  inherited Kill;
end;

procedure TPest.Kill;
begin
  Explode(2);
  inherited Kill;
end;

procedure TPest.Move;
begin
  inherited Move;
  { inc(Frame); if Frame >= 32 then Frame := 0; }
  if IncFrame then begin
    inc(Frame); if Frame >= PestFrames-1 then IncFrame := false;
  end else begin
    dec(Frame); if Frame <= 0 then IncFrame := true;
  end;
end;

procedure TPest.Setup;
begin
  inherited Setup;
  Mass := Pest_Mass;
  Frame := random(PestFrames-2)+1;
  IncFrame := boolean(random(2));
end;

procedure TPest.Cue;
const
  JitterFreq = 40;
  Jitter = 512;
  PestAttn = 16;
var
  Priority : integer;
  BestXX, BestYY,
  BestDist : longint;
  NumAvgs : integer;
  AttractAmt,
  AttractDist : longint;
  V : TPoint;
  procedure DoPest(Item : PPlyr); far;
  const
    ShipAttract = 32;
  var
    xx,yy : integer;
    dist : longint;
    T : TVMTPtr;
  begin
    T := TVMTPtr(typeof(Item^));
    if ((T = TVMTPtr(typeof(TShip))) or (T = TVMTPtr(typeof(TAlien))))
      and (Item^.Status and plyr_Cloaked = 0) then
    begin
      if (T <> TVMTPtr(typeof(TShip))) or (PShip(Item)^.Cloaked = 0) then
      begin
        { Pests seek out ships & aliens }
        xx := integer(Item^.Pos.X-Pos.X);
        yy := integer(Item^.Pos.Y-Pos.Y);
(*        if (GameDifficulty = 3) then
        with Item^.Vel do begin
          inc(xx, X*32); { pest anticipates next movement-- tricky eh? }
          inc(yy, Y*32);
        end;*)
        dist := ISqrt(ISqr(xx div 2) + ISqr(yy div 2)) shr 4 + 8;
        if (Priority = 0) or (dist < BestDist) then begin
          BestDist := dist;
          BestXX := xx;
          BestYY := yy;
          Priority := 1;
        end;
      end;
    end else
    if ((T = TVMTPtr(typeof(TPest))) and (Item <> PPlyr(@Self)))
      or (T = TVMTPtr(typeof(TRock))) then
    begin
      { pests shy away from rocks & other pests that are too close }
      xx := integer(Item^.Pos.X-Pos.X);
      yy := integer(Item^.Pos.Y-Pos.Y);
{      xx := (Item^.Pos.X div 2)-Pos.X div 2;
      yy := (Item^.Pos.Y div 2)-Pos.Y div 2;}
      dist := (ISqr(xx div 2) + ISqr(yy div 2)) div AttractAmt+4;
      if (T = TVMTPtr(typeof(TRock))) then
        dist := dist shr (2-PRock(Item)^.RockSize);
      if dist <= AttractDist then begin
        if ((BestDist = 0) or (dist < BestDist)) then
        begin
          BestDist := dist;
          BestXX := -xx; { repel when near }
          BestYY := -yy;
          Priority := 1;
        end;
      end else begin
        if (T <> TVMTPtr(typeof(TRock))) and (Priority = 0) 
          and (dist > BestDist)
        then begin  { attract when far }
          BestDist := dist;
          BestXX := xx;
          BestYY := yy;
        end;
      end;
    end else
    if (T = TVMTPtr(typeof(TTorpedo))) and Collide(Item) then
    begin
      { blow up the pest }
      if (PTorpedo(Item)^.Owner <> nil) then
        with PTorpedo(Item)^ do begin
          Owner^.AddScore(scor_Pest);
        end;
      Sounds[snd_Pop]^.Play;
      Kill;
      Item^.Kill;
    end;
  end;
begin
  BestDist := 0;
  Priority := 0;
  AttractDist := 20;
  BestXX := 0; BestYY := 0; numavgs := 0;
  AttractAmt := 20000000 div StageMaxRes;
  Stage^.Objs.ForEach(@DoPest);
  if BestDist > 0 then begin
    if Priority > 0 then begin
      V.X := BestXX div BestDist;
      V.Y := BestYY div BestDist;
    end else begin
      V.X := BestXX div ISqrt(BestDist-AttractDist) div 8;
      V.Y := BestYY div ISqrt(BestDist-AttractDist) div 8;
    end;
    inc(Vel.X, V.X);
    inc(Vel.Y, V.Y);
  end{ else begin
    if (random(JitterFreq) = 0) then begin
      inc(Vel.X, random(Jitter)-Jitter div 2);
      inc(Vel.Y, random(Jitter)-Jitter div 2);
    end;
  end};
  Vel.X := MulDiv(Vel.X, PestAttn-1, PestAttn);
  Vel.Y := MulDiv(Vel.Y, PestAttn-1, PestAttn);
end;

destructor TCraft.Done;
var
  i : integer;
begin
  if BulletsOut > 0 then
    for i := 0 to BulletsOut-1 do
      Bullets[i]^.Owner := nil;
  { tell all the bullets that I'm dead }
  inherited Done;
end;

procedure TCraft.AddScore(n : integer);
begin end;

procedure TCraft.Setup;
begin
  inherited Setup;
  Mass := Ship_Mass;
  BulletsOut := 0;
end;

procedure TCraft.Kill;
begin
  inherited Kill;
  Explode(0);
end;

procedure TCraft.AddBullet(P : PTorpedo);
begin
  if BulletsOut < MaxBulletsOut then begin
    Bullets[BulletsOut] := P;
    P^.Owner := @Self;
    inc(BulletsOut);
  end;
end;

procedure TCraft.RemoveBullet(P : PTorpedo);
var
  i : integer;
begin
  P^.Owner := nil;
  if BulletsOut > 0 then
    for i := 0 to BulletsOut-1 do
      if P = Bullets[i] then begin
        if i < BulletsOut-1 then
          System.Move(Bullets[i+1], Bullets[i], sizeof(PTorpedo)*(BulletsOut-i));
        dec(BulletsOut);
        Exit;
      end;
end;

procedure TShip.SetParams;
var Res : integer;
begin
  Res := StageMaxRes;
  with Metrics[Stat^.num] do begin { PROGRAM CRASHES HERE! }
    RotSpeed := 16+Specs[specRotSpeed] div (SpecLimit div 16);
    ThrustSpeed := MulDiv(Specs[specThrustSpeed]+(SpecLimit div 6),
      170000 div SpecLimit, Res);
    VelocAtten := ISqr(SpecLimit div 5+Specs[specMaxSpeed])*8 div Res;
    AbilityStrength := Specs[specAbilityStrength]*(24576 div SpecLimit);
    BulletSpeed := MulDiv(Specs[specBulletSpeed]+(SpecLimit div 2),
      1200000 div SpecLimit, Res);
  end;
end;

procedure TShip.Setup;
begin
  inherited Setup;
  Thrust := false; Hyperspace := 0; Hypercharge := 0; Fire := false;
  Rotate := 0; {$IFDEF wormhole}WormHole := false;{$ENDIF}
  ShieldsOn := false;
  Disruptor := false;
  Cloaked := 0;
  ThrustID := 0;
  ShieldID := 0;
  DisruptID := 0;
  { Setup for big entrance }
  Materializing := MaterializeTime;
  Status := Status or plyr_Cloaked;
  FillChar(fairydust, sizeof(fairydust), $7f);
end;

procedure TShip.Move;
var
  siz : UPoint;
begin
  inherited Move;
  { see if we're hyperspacing in or out }
  if HyperSpace > 0 then begin
    { play the reentering sound }
    if (HyperSpace = HyperTime+HyperSoundPlay) then
      Sounds[snd_HyperSpace]^.Play;
    inc(HyperSpace);
    { we're spacing out }
    if HyperSpace <= HyperTime then begin
      Status := Status or plyr_Invulnerable or plyr_MaskOnly;
      dec(Size.X, HyperSpeed);
      dec(Size.Y, HyperSpeed);
      if HyperSpace = HyperTime then begin
        Status := Status or plyr_Cloaked;
        {$IFDEF wormhole}
        WormHole := Sqr(random(156)) > AbilityStrength;
        {$ENDIF}
      end;
    end;
    { we're spacing in }
    if (HyperSpace > HyperTime+HyperDelay) then begin
      Status := Status and not plyr_Cloaked;
      if HyperSpace = HyperTime*2+HyperDelay then begin
        HyperSpace := 0;
        Status := Status and not (plyr_Invulnerable or plyr_MaskOnly);
      end else begin
        inc(Size.X, HyperSpeed);
        inc(Size.Y, HyperSpeed);
        {$IFDEF wormhole}
        if WormHole then begin
          inc(Size.X, HyperSpeed*3);
          inc(Size.Y, HyperSpeed*3);
        end;
        {$ENDIF}
      end;
    end else
      { try to pick a safe location }
      if (HyperSpace = HyperTime) or
        ((HyperSpace > HyperTime) and
         (HyperSpace < HyperTime+MulDiv(AbilityStrength, HyperDelay, 24576)) and
         not SafeHaven(Pos.X, Pos.Y, @Self)) then
      with Stage^ do begin
        Siz.X := ViewSize.X div 8;
        Siz.Y := ViewSize.Y div 8;
        Pos.X := integer(random(Siz.X*6)+ViewOrg.X+Siz.X);
        Pos.Y := integer(random(Siz.Y*6)+ViewOrg.Y+Siz.Y);
        Vel.X := 0; Vel.Y := 0;
      end;
  end;
end;

procedure TShip.AddScore;
begin
  Stat^.AddScore(n);
end;

procedure TShip.Bounce;
{ mv = mv }
begin
  Vel.X := Vel.X + MulDiv(p^.Vel.X-Vel.X, abs(p^.Mass), abs(Mass));
  Vel.Y := Vel.Y + MulDiv(p^.Vel.Y-Vel.Y, abs(p^.Mass), abs(Mass));
  inc(Rotate, integer(random(RotHit*2+1))-RotHit);
end;

procedure TShip.StopSound(var ID : word);
begin
  if (ID <> 0) then begin
    StopWaveID(ID);
    ID := 0;
  end;
end;

procedure TShip.Cue;

  procedure DoDisrupt(Item : PPlyr); far;
  var
    xx,yy,dist : longint;
    amt : integer;
  begin
    if (Item <> PPlyr(@Self)) and (Item^.Mass <> 0) then begin
      xx := integer(Item^.Pos.X-Pos.X);
      yy := integer(Item^.Pos.Y-Pos.Y);
      dist := HiWord(ISqr(xx div 2)+ISqr(yy div 2))+1;
      xx := integer(HiWord(xx*AbilityStrength)) div dist;
      yy := integer(HiWord(yy*AbilityStrength)) div dist;
{      dec(Vel.X, MulDiv(xx, Item^.Mass, Mass));
      dec(Vel.Y, MulDiv(yy, Item^.Mass, Mass));}
      inc(Item^.Vel.X, MulDiv(xx, Mass, Item^.Mass));
      inc(Item^.Vel.Y, MulDiv(yy, Mass, Item^.Mass));
    end;
  end;

const
  Shipofs = 36;
var
  p, Bullet : PPlyr;
  T : pointer;
  Pt : TPoint;
  i, Rot2 : integer;
  Spd : longint;
  IsPlayerTorp,OkToEnter : boolean;
  pOwner : PCraft;
  Shp : PCostume;

begin
  RotVel := Rotate*RotSpeed;

  if Thrust then begin
    { loop the thrust sound if not already started }
    if (SoundType = sound_Wave) and not IsPlayingID(ThrustID) then begin
      ThrustID := PWave(Sounds[snd_Thrust])^.StartLoop;
    end;
    inc(Vel.X, integer(HiWord(LongMul(ISin(Rot), ThrustSpeed))));
    inc(Vel.Y, -integer(HiWord(LongMul(ICos(Rot), ThrustSpeed))));
  end else
    StopSound(ThrustID);
  Spd := ISqrt(ISqr(Vel.X)+ISqr(Vel.Y)) div 2;
  if (Disruptor) then
    Spd := Spd * 16;
  if Spd > 0 then begin
    Vel.X := Vel.X*VelocAtten div (Spd+VelocAtten);
    Vel.Y := Vel.Y*VelocAtten div (Spd+VelocAtten);
  end;

  {$IFDEF wormhole}
  if WormHole then begin
    inc(Size.X, random(64)-32);
    inc(Size.Y, random(64)-32);
    if Size.X < 256 then inc(Size.X, 32);
    if Size.Y < 256 then inc(Size.Y, 32);
  end;
  {$ENDIF}

  if ShieldsOn then begin
    dec(ShieldStrength);
    if ShieldStrength < 20 then
      Status := Status xor plyr_MaskOnly  { flash shield when low }
    else
      Status := Status and not plyr_MaskOnly;
    if ShieldStrength <= 0 then begin
      SetAbility(false); { shield ran out }
    end;
    { loop the shield sound if not already started }
    if (SoundType = sound_Wave) and not IsPlayingID(ShieldID) then begin
      ShieldId := PWave(Sounds[snd_Shield])^.StartLoop;
    end;
  end else begin
    if (ShieldStrength < MaxShieldStrength) and
    (GameFrame mod 32 = 0) then
      inc(ShieldStrength);
    StopSound(ShieldID);
  end;

  if Disruptor then begin
    if (SoundType = sound_Wave) and not IsPlayingID(DisruptID) then begin
      DisruptId := PWave(Sounds[snd_Disrupt])^.StartLoop;
    end;
    Stage^.Objs.ForEach(@DoDisrupt);
    Color := Color xor $FFFFFF;
  end else
    StopSound(DisruptID);

  if Hypercharge > 0 then dec(Hypercharge);

  if Cloaked <> 0 then begin
    if ((NumRemotePlayers > 0) and (Stat^.num < NumLocalPlayers)) or
      (NumPlayers = 1) then
    begin
      { what the ship looks like to the local players }
      inc(Cloaked);
      Color := $FFFFFF;
      if Cloaked and 2 = 0 then
        Status := Status and not plyr_MaskOnly
      else
        Status := Status or plyr_MaskOnly
    end else begin
      { what the ship looks like to the remote players }
      if abs(Cloaked) < 8 then begin
        i := $FF shr (abs(Cloaked) shr 1-1);
        Color := RGB(i,i,i);
      end else
        Color := 0;
      inc(Cloaked);
      if Cloaked > 0 then begin
        Status := Status or plyr_MaskOnly;
      end else begin
        if Cloaked = 0 then begin
          Status := Status and not plyr_MaskOnly;
          Color := $FFFFFF;
        end;
      end;
{      Size.X := ISin(abs(Cloaked)*48) div 256+256;
      Size.Y := ISin(abs(Cloaked)*64) div 256+256;}
    end;
    dec(CloakTime);
    if CloakTime = 0 then
      SetAbility(false);
  end;

  { fire bullets }
  if Fire and (BulletsOut < MaxBulletsOut) then
  begin
    Pt.X := 0; Pt.Y := LongMulShr8(Size.Y, ShipOfs);
    Stage^.ScreenToStage(Pt);
    Rot2 := Rot;
    IRotate(Pt, Rot2);
    if GameParams.BulletsKillPlayers then Shp := AlienTorpShp else Shp := TorpShp;
    Bullet := New(PTorpedo, Init(Stage, Pt.X+Pos.X, Pt.Y+Pos.Y, Shp));
    PTorpedo(Bullet)^.RotVel := 256;
    { make the player's bullet harmless if the setting is off }
    if not GameParams.BulletsKillPlayers then
      PTorpedo(Bullet)^.Deflects := true;
    Pt.X := 0; Pt.Y := BulletSpeed;
    IRotate(Pt, Rot2);
    Bullet^.Vel.X := Pt.X+Vel.X div 2;
    Bullet^.Vel.Y := Pt.Y+Vel.Y div 2;
    {$IFDEF wormhole}
    if WormHole then with PTorpedo(Bullet)^ do begin
      Size.X := 1024; Size.Y := 1024;
      Vel.X := Vel.X*2;
      Vel.Y := Vel.Y*2;
    end;
    {$ENDIF}
    Stage^.Add(Bullet);
    AddBullet(PTorpedo(Bullet));
    Sounds[snd_Shoot]^.Play;
  end;
  if not (cheat_AutoFire in CheatsOn) then
    Fire := false;

  { check collisions }
  OkToEnter := true;
  for i := 0 to Stage^.Objs.Count-1 do begin
    p := Stage^.Objs.At(i);
    if p <> PPlyr(@Self) then begin
      T := typeof(P^);
      if ((T <> typeof(TTorpedo)) or (PTorpedo(p)^.Owner <> PCraft(@Self))) and
       Collide(p) then begin
        if Materializing > 0 then
          OkToEnter := false { collision; so not OK to enter playing field }
        else begin
          IsPlayerTorp := ((T = typeof(TTorpedo)) and PTorpedo(p)^.Deflects);
          if ShieldsOn or IsPlayerTorp then
          begin
            { bounce off player's bullets, and when shield is activated }
            p^.Kill;
            Rot2 := Rotate;
            Bounce(p);
            { if shields are on and player torp hit us, don't spin around }
            if ShieldsOn and IsPlayerTorp then
              Rotate := Rot2;
            { if ship is cloaked, flash it }
            if Cloaked > 0 then Cloaked := 4;
            if T = typeof(TTorpedo) then PShip(p)^.Explode(3);
            if ShieldsOn then begin
              Sounds[snd_ShieldBounce]^.Play;
              Status := Status or plyr_MaskOnly; { flash the shield }
              ShieldStrength := ShieldStrength*(100-p^.Mass) div 100;
                { drain some strength from the shield when you bounce off }
            end else
              Sounds[snd_Bounce]^.Play
          end else begin
            { blow up player }
            Sounds[snd_PlayerBlowUp]^.Play;
            Kill;
            p^.Kill;
          end;
        end;
      end;
    end;
  end;

  { see if we should allow ship to materialize }
  if (Materializing = MaterializeTime) then begin
    if OkToEnter then begin
      HyperSpace := HyperTime+HyperDelay;
      Size.X := HyperSpeed; Size.Y := HyperSpeed;
      dec(Materializing);
      Status := Status or plyr_Invulnerable or plyr_MaskOnly;
    end;
  end else
    if (Materializing > 0) then begin
      dec(Materializing);
      (*
      Color := $0;
      Status := Status xor plyr_MaskOnly;
      *)
      if Materializing = 0 then
        Status := Status and not (plyr_Invulnerable {or plyr_MaskOnly});
    end;

  if cheat_PhaseOut in CheatsOn then
    Status := Status or plyr_Invulnerable;
end;

destructor TShip.Done;
begin
  Stat^.CurShip := nil;
  with Stat^ do begin
    ReturnTime := TimeToReturn;
    Ctrl^.Client := nil;
  end;
  StopSound(ThrustID);
  StopSound(ShieldID);
  StopSound(DisruptID);
  inherited Done;
end;

procedure TShip.Kill;
begin
  if cheat_Jugger in CheatsOn then
    Exit;
  if not ShieldsOn then begin { can't die when shields R up! }
    SetAbility(false);
    inherited Kill;
  end;
end;

procedure TShip.Draw(ROP : longint);
const NotSrcInvert = SrcInvert xor $FF0000;
      NotSrcAnd = SrcAND xor $FF0000;
var
  x,y,i : integer;
  Pt : TPoint;
  R : TRect;
  fairysize : integer;
  clr : TColorRef;
  radius,sqrradius : integer;
  DC : HDC;
begin
  if (abs(Cloaked) >= 8) and (Color = 0) then begin
    GetRect(R);
    BitBlt(Stage^.GDC, R.left, R.top, R.right-R.left-1, R.bottom-R.top-1,
      Stage^.GDC, R.left+1, R.top+1, SRCCOPY);
    Stage^.Dirty^.AddRect(R);
    Exit;
  end else
    inherited Draw(ROP);
  { draw thruster flame }
  if Thrust and (Status and (plyr_Hidden or plyr_MaskOnly) = 0)
    and (Hyperspace = 0) then
  begin
    Pt.X := 0; Pt.Y := -36;
    IRotate(Pt, Rot);
    Stage^.TransCoords(Pos, X, Y);
    ThrustShp[GameFrame and 1]^.Draw(Stage,
      X+1+Pt.X, Y+Pt.Y, Size.X, Size.Y, Rot, 0, SRCPAINT);
    ThrustShp[GameFrame and 1]^.GetRect(R,
      X+1+Pt.X, Y+Pt.Y, Size.X, Size.Y, Rot);
    Stage^.Dirty^.AddRect(R);
  end;
  { draw fairy dust }
  if (Hyperspace = 0) and (Materializing > 0) and (Materializing < MaterializeTime) then
  begin
    DC := Stage^.GDC;
    radius := LongMulShr8(20, Size.X);
    sqrradius := sqr(Radius);
    Stage^.TransCoords(Pos, integer(pt.X), integer(pt.Y));
    clr := Stat^.PlyrColor;
    fairysize := Materializing*High(fairydust) div MaterializeTime;
    for i := Low(fairydust) to fairysize do
      with fairydust[i] do begin
        if v_random(8) = 0 then begin
          repeat
            x := v_random(radius*2)-radius;
            y := v_random(radius*2)-radius;
          until Sqr(x)+Sqr(y) <= sqrradius;
        end;
        if x <> $7f7f then begin
          {$IFDEF wing}
          Stage^.PutPixel(pt.x+x, pt.y+y, clr);
          {$ELSE}
          SetPixel(DC, pt.x+x, pt.y+y, clr);
          {$ENDIF}
        end;
      end;
  end;
end;

procedure TShip.SetAbility(State : boolean);
begin
  case Metrics[Stat^.num].SpecialType of
    abil_Hyper :
      if State and (HyperSpace = 0) then
        if HyperCharge > 0 then
          Sounds[snd_RockBounce]^.Play
        else
        {$IFDEF wormhole}if not WormHole then {$ENDIF}begin
          Hyperspace := 1;
          HyperCharge := HyperRechargeTime;
        end;
    abil_Shield :
      if State <> ShieldsOn then
        if State then begin
          if (Status and plyr_Invulnerable = 0) and (ShieldStrength > 0) then
          begin
            Costume := ShieldShp[Stat^.shpnum];
            ShieldsOn := true;
            Mass := -Ship_Mass;
            Thrust := false;
          end;
        end else begin
          Status := Status and not (plyr_Invulnerable or plyr_MaskOnly);
          Costume := ShipShp[Stat^.shpnum];
          Mass := Ship_Mass;
          ShieldsOn := false;
        end;
    abil_Disrupt :
      if State <> Disruptor then
        if State then begin
          Disruptor := true;
          Color := Stat^.PlyrColor;
          Status := Status or plyr_MaskOnly;
        end else begin
          Disruptor := false;
          Color := $FFFFFF;
          Status := Status and not plyr_MaskOnly;
        end;
    abil_Cloak :
      if State <> (Cloaked <> 0) then
        if State then begin
          Cloaked := 1;
          Cloaktime := AbilityStrength div 50;
        end else begin
          Cloaked := -5;
        end;
  end;
end;

function TShip.Message(Command, wParam : word; lParam : longint) : longint;
begin
  Message := 0;
  case Command of
    WM_KEYDOWN: if (HyperSpace = 0) or (HyperSpace > HyperTime+HyperDelay) then
    begin
      case GameKeyType(wParam) of
        gcLeft : Rotate := -1;
        gcRight : Rotate := 1;
        gcUp : if not ShieldsOn then Thrust := true;
        gcBtn1 : begin
          if not ShieldsOn then begin
            if (Cloaked > 0) then SetAbility(false); { come out of cloak }
            Fire := true;
          end;
        end;
        gcBtn2 :
          case Metrics[Stat^.num].SpecialType of
            abil_Cloak : SetAbility(Cloaked = 0);
          else
            SetAbility(true);
          end;
      end;
    end;
    WM_KEYUP: begin
      case GameKeyType(wParam) of
        gcLeft, gcRight : Rotate := 0;
        gcUp : Thrust := false;
        {$IFDEF cheat}gcBtn1 : if cheat_AutoFire in CheatsOn then Fire := false;{$ENDIF}
        gcBtn2 :
          if Metrics[Stat^.num].SpecialType <> abil_Cloak then
            SetAbility(False);
      end;
    end;
  else
    Message := inherited Message(Command, wParam, lParam);
  end;
end;

constructor TRock.Init(TheStage : PStage; X, Y : integer; Cost : PCostume;
  ARockSize : byte);
begin
  RockSize := ARockSize;
  inherited Init(TheStage, X, Y, Cost);
end;

procedure TRock.Setup;
begin
  inherited Setup;
  Mass := Rock_Mass shr RockSize;
end;

procedure TRock.Kill;

  procedure MakeNewRocks;
  const
    NumAddRocks = 2;
  var
    x,dir : integer;
    NewVel, NewPos : TPoint;
    rock : PRock;
  begin
    for x := 1 to NumAddRocks do begin
      Dir := random(IntPi*2); { random direction }
      NewVel.X := random(MaxRockVel*2)+MaxRockVel shr 1; { random velocity }
      NewVel.Y := 0;
      IRotate(NewVel, Dir);
      NewPos.X := (StageMax*64 div StageMaxRes) shr RockSize;
      NewPos.Y := 0;
      IRotate(NewPos, Dir);
      New(rock, Init(Stage, Pos.X+NewPos.X, Pos.Y+NewPos.Y, { offset a little from center }
        RockShps[RockSize+1], RockSize+1));
      rock^.Vel.X := Vel.X + NewVel.X;
      rock^.Vel.Y := Vel.Y + NewVel.Y;  { give velocity of the parent asteroid }
      Stage^.Add(rock);
    end;
  end;

  procedure HatchPests;
  var
    i, size : integer;
    Pest : PPest;
  begin
    Sounds[snd_CroniesOut]^.Play;
    size := (StageMax*45 div StageMaxRes) shr RockSize;
    for i := 1 to random(MaxPests-MinPests)+MinPests do begin
      New(Pest, Init(Stage,
        Pos.X+random(size)-size shr 1,
        Pos.Y+random(size)-size shr 1,
        PestShp));
      Stage^.Add(Pest);
    end;
  end;

begin
  Explode(RockSize);
  if RockSize < 2 then begin
    MakeNewRocks;
    {$IFNDEF pesttest}
    { probability of hatching : NumHatches/NumHatchRocks }
    if random(NumHatchRocks) < HatchesLeft then { bombs here! }
    {$ENDIF}
    begin
      HatchPests;
      dec(HatchesLeft);
    end;
    dec(NumHatchRocks);
  end;
  dec(NumRocksLeft);
  inherited Kill;
end;

procedure TRock.Cue;
const
  RockPitch : array[0..2] of byte = (snd_ExplodeLo,snd_Explode,snd_ExplodeHi);
var i : integer;
    p : PPlyr;
    T : pointer;
begin
  for i := 0 to Stage^.Objs.Count-1 do begin
    p := Stage^.Objs.At(i);
    T := typeof(P^);
    if (T=typeof(TTorpedo)) and Collide(p) then begin
      if not TournamentPlay or (GameParams.TournamentRocks = 2) then begin
        Sounds[RockPitch[RockSize]]^.Play;
        Kill;
        if not TournamentPlay then
          if (PTorpedo(p)^.Owner <> nil) then
            PTorpedo(p)^.Owner^.AddScore(scor_Rocks + RockSize);
        p^.Kill;
      end else begin
        Sounds[snd_RockBounce]^.Play;
        PTorpedo(p)^.Explode(2);
        p^.Kill;
        Vel.X := Vel.X + MulDiv(p^.Vel.X-Vel.X, abs(p^.Mass), abs(Mass));
        Vel.Y := Vel.Y + MulDiv(p^.Vel.Y-Vel.Y, abs(p^.Mass), abs(Mass));
      end;
    end;
  end;
end;

procedure TAlien.Setup;
begin
  inherited Setup;
  Status := Status and not plyr_WrapAroundX;
end;

procedure TAlien.Shoot;
var Bullet : PTorpedo;
    X, Y, Dir : integer;
    Pt : TPoint;
begin
  Dir := random(1024);
  Bullet := New(PTorpedo, Init(Stage, Pos.X, Pos.Y, AlienTorpShp));
  PTorpedo(Bullet)^.RotVel := 256;

  Pt.X := 0; Pt.Y := AlienSpeed*14;
  IRotate(Pt, Dir);
  Bullet^.Vel.X := Vel.X+Pt.X;
  Bullet^.Vel.Y := Vel.Y+Pt.Y;
  Stage^.Add(Bullet);
  AddBullet(Bullet);
  Sounds[snd_AlienShoot]^.Play;
end;

procedure TAlien.Cue;
var i : integer;
    p : PPlayer;
    T : pointer;
    Torp : PTorpedo;
begin
  for i := 0 to Stage^.Objs.Count-1 do begin
    p := Stage^.Objs.At(i);
    T := typeof(P^);
    if (T=typeof(TTorpedo)) and (PTorpedo(p)^.Owner <> PCraft(@Self)) and
     Collide(p) then
    begin
      { collided with other object }
      if (PTorpedo(p)^.Owner <> nil) then
        PTorpedo(p)^.Owner^.AddScore(scor_Alien);
      Sounds[snd_Explode]^.Play;
      Sounds[snd_ExplodeLo]^.Play;
      Kill;
      p^.Kill;
      Exit
    end;
  end;
  with Stage^ do
    if (Pos.X < ViewOrg.X) or (Pos.X > ViewOrg.X+ViewSize.X) then begin
      TPlyr.Kill;
      Exit
    end;
  if BulletsOut = 0 then Shoot;
  if NextAlien mod (42-GameParams.Difficulty*8) = 0 then begin
    { time to change direction }
    if Vel.Y <> 0 then Vel.Y := 0
    else begin
      Vel.Y := 250+GameParams.Difficulty*128;
      if random(2) = 0 then Vel.Y := -Vel.Y;
    end;
  end;
end;

procedure StopMidiSong;
begin
  if SongPlaying <> nil then begin
    DoneMidiSound;
    StrDispose(SongPlaying);
    SongPlaying := nil;
  end;
end;

function StartMidiSong(FileName : PChar) : boolean;
var
  CurSong : PChar;
begin
  StartMidiSong := false;
  if FileName = nil then Exit;
  if SongPlaying <> nil then StopMidiSong;
  SongPlaying := StrNew(FileName);
  CurSong := GetRandomFile(FileName);
  if (MusicOn = 0) then begin
    if (InitMidiSound(MainWnd, CurSong) = 0) then
      StartMidiSong := (PlayMidiFile = 0);
  end;
  SysUtils.StrDispose(CurSong);
end;

function SetSound(state : word) : boolean;
begin
  SetSound := false;
  if (SoundOn = 0) xor (state = 0) then begin
    if state = 0 then begin
      case SoundType of
        sound_Wave :
          PauseWaveSound(False);
        {$IFNDEF win32}
        sound_Spkr :
          if not InitSpkrSound(512) then Exit;
        {$ENDIF}
      end;
    end else begin
      case SoundType of
        sound_Wave : PauseWaveSound(True);
        {$IFNDEF win32}
        sound_Spkr : DoneSpkrSound;
        {$ENDIF}
      end;
    end;
  end;
  SoundOn := state;
  SetBtnBarText(ID_SOUND,
    LoadStr(STR_SOUND + ord(ByteBool(SoundOn and sound_User))));
  SetSound := true;
end;

function SetMusic(state : word) : boolean;
var
  CurSong : PChar;
begin
  SetMusic := true;
  if (MusicOn = 0) xor (state = 0) then begin
    MusicOn := state;
    if MusicOn = 0 then begin
      CurSong := StrNew(SongPlaying);
      SetMusic := StartMidiSong(CurSong);
      StrDispose(CurSong);
    end else begin
      DoneMidiSound;
    end;
  end;
  SetBtnBarText(ID_MUSIC,
    LoadStr(STR_MUSIC + ord(ByteBool(MusicOn and sound_User))));
end;

procedure AddShape(Shp : PCostume);
begin
  if Shp <> nil then begin
    ShapeList.Insert(Shp);
  end else begin
    FatalError(Str_NoMemShapes, MB_ICONEXCLAMATION);
  end;
end;

procedure InitShipShapes(DC : HDC; Num : integer);
var OldCursor : HCursor;
    i : integer;
begin
  OldCursor := SetCursor(LoadCursor(0, IDC_WAIT));
  { load all ship & shield shapes into memory for active players }
  while ShipShpsLoaded < Num do begin
    New(ShipShp[ShipShpsLoaded], Init(HLib, PChar(BMAP_SHIP),
       DC, 64, ShipShpsLoaded*8));
    AddShape(ShipShp[ShipShpsLoaded]);
    New(ShieldShp[ShipShpsLoaded], Init(HLib, PChar(BMAP_SHIELD), DC, 64, ShipShpsLoaded*8));
    AddShape(ShieldShp[ShipShpsLoaded]);
    inc(ShipShpsLoaded);
  end;
  SetCursor(OldCursor);
end;

procedure UpdateShipShapes;
begin
  InitShipShapes(MainDC, NumPlayers);
end;

{$IFNDEF oldtimer}
{$S-}
{$IFNDEF WIN32}
procedure TimerFunc(ID : cardinal; wMessage : word; dwuser, dw1, dw2 : longint); export;
{$ELSE}
procedure TimerFunc(ID : MMresult; wMessage, dwuser, dw1, dw2 : integer);
  stdcall; 
{$ENDIF}
type
  PBoolean = ^Boolean;
begin
  PBoolean(dwuser)^ := true;
end;
{$ENDIF}

{ Start a periodic timer with Time msec between ticks }
procedure StartTimer(Time : word);
begin
  if not TimerOn then begin
{$IFDEF oldtimer}
    TimerOn := SetTimer(GameWnd, 1, Time, nil) <> 0;
{$ELSE}
      TimerProcessed := false;
      TimerID := timeSetEvent(Time, TimerResolution,
        {$IFDEF win32}@TimerFunc{$ELSE}TimerFunc{$ENDIF},
        longint(@TimerProcessed), TIME_PERIODIC);
      TimerOn := TimerID <> 0;
{$ENDIF}
  end;
  if not TimerOn then begin
    Paused := 255;
    FatalError(str_NoTimersLeft, MB_ICONEXCLAMATION);
  end;
  CurTimerTime := Time;
end;

{ stop the game timer }
procedure StopTimer;
begin
  if TimerOn then begin
{$IFDEF oldtimer}
    KillTimer(GameWnd, 1);
{$ELSE}
    timeKillEvent(TimerID);
{$ENDIF}
    TimerOn := false;
  end;
end;

{$IFNDEF oldtimer}
begin
  timeBeginPeriod(TimerResolution);
{$ENDIF}
end.

