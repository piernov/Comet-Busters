(*********************************************************)
(**  COMET.PAS                                          **)
(**  Comet Busters! main program                        **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

{$IFNDEF scrnsave}
program Comet;
{$ELSE}
program CometSS;
{$ENDIF}

(*
  $DEFINES:

  cheat       -- Installs the cheat codes (registered only)
  pesttest    -- Makes every rock hatch pests.
  exelib      -- Links the COMET1.DLL file into the executable.
  stress      -- Tests the program's reaction to low memory situations.
  nocomm      -- Takes out the communications-specific code.
  commfile    -- Outputs debug file for comm access.
  ownjoy      -- Uses internal joystick driver.
  oldtimer    -- Uses SetTimer() instead of MMSYSTEM timer.
  scrnsave    -- make screen saver
  loopback    -- test 2 Comets at once!
*)

{$IFNDEF WIN32}
{$C PRELOAD}
{$G+,T-}
{$S $4000}
{$M $2000, $800}
{$ENDIF}

uses
  Objects,
  IMath,
  Win31,
  WinTypes,
  WinProcs,
  WinComp,
  Sprite24,
  GameSnd,
  GameXtra,
  HiScore,
  BtnBar,
  CometLib,
  CometIni,
  CometDlg,
  GameCtrl,
  DynArr,
  MMSystem,
  Messages,
  GameSock,
  CometRem,
  SysUtils,
  GameLib
  {$IFDEF stress} , Stress {$ENDIF}
  {$IFDEF leak} , LeakFind {$ENDIF};

{$IFDEF scrnsave}
{$D SCRNSAVE :Comet Busters!}
{$UNDEF splash}
{$ELSE}
{$D Comet Busters - Copyright (c) 1994 HAMCO Software}
{$ENDIF}

{$R COMET}
{$IFDEF SPLASH}
{$R COMETTIL}
{$ENDIF}
{$IFDEF EXELIB}
  {$R COMET1}
{$ENDIF}

{$IFNDEF wing}
{$R palette}
{$ENDIF}

const
  VersionString = 'Version 1.4'
    {$IFDEF wing}+' WinG'{$ENDIF}
    {$IFDEF win32}+' 32-bit'{$ENDIF}
    {$IFDEF beta}+' beta 2, expires 12/1/96'{$ENDIF};

const
  NewLevelWait = 70;          { ticks to wait before new level begins }
  BeforeGameOverWait = 70;    { ticks to wait before GAME OVER appears }
  GameOverWait = 140;         { ticks to wait on GAME OVER sign }
  TournamentWait = 140;       { ticks to wait between tournament levels }
  AttractWait = 180;          { ticks to wait on each frame of attract mode }
  ScrnSaveWait = 600;         { ticks to wait during screen save }
  PreventBurnoutTime = 16384; { ticks to wait until universe changes }
  LogHighScoreWait = 70;      { ticks to wait after high score is logged }
  HideMouseCount = 50;        { ticks to wait until cursor is hidden }
  ChatMessageWait = 200;       { time a chat message stays on the screen }

  HideMouseTimer : word = HideMouseCount;

  pause_Inactive = 1;
  pause_User     = 2;
  pause_Error    = 4;
  pause_Remote   = 8;
  pause_CommWait = 16;
  pause_RemoteAck = 32;

  pause_Local = 1 + 2 + 4;

  Paused  : byte = pause_Inactive; { if nonzero, game is paused }
(*
  RecvPlayer : integer = 0; { player next message is intended for }
  RecvState : byte = 0; { Receiving on state or off state? }
*)
var
  MsgAcks : word;
  PlayerWon : integer;
  plyrwonname : PChar;
  PlayerWonRound : integer;
  GameChkSum,LastChkSum : byte;
  SendFrame : boolean;
var
  MainWndGameRect : TRect; { size of main window during game }
const
  ChatPlayer : integer = -1;

type
  TRemoteMsg = (RMSG_ACK,RMSG_START,RMSG_STOP,
    RMSG_CHAT,RMSG_NUMPLAYERS,RMSG_PLAYERDATA,RMSG_GAMEDATA,RMSG_ERROR,
    RMSG_HISCORE,RMSG_BYEBYE);

const
  PlayerNames : array[-1..3] of PChar =
    ('No one', 'Blue','Garnet','Green','Gold');

{$IFDEF cheat}
const
  CheatCodes : array[TCheatType] of PChar = (
    'TUOESAHP'{invulnerable},
    'REGGUJ'{kill everything w/ ship},
    'EKUN'{explode all rocks},
    'ERIFOTUA'
  );
var
  CheatBuf : array[0..7] of char;
{$ENDIF}

function IsUpdateFrame : boolean;
begin
  IsUpdateFrame := (RS = nil) or SendFrame or not (GameMode in gmode_Playing);
end;

procedure SendRemoteMsg(Msg : TRemoteMsg; Data : pointer; DataSize : integer);
forward;

const RockHueShift = 8;
procedure LoadRockShape(i : integer);
begin
  if RockShps[i] <> nil then
    ShapeList.Free(RockShps[i]);
  New(RockShps[i], Init(HLib, PChar((((level-1) mod NumMoons)+2)*8+i),
    MainDC, 1, ((level-1) div NumMoons)*RockHueShift));
  AddShape(RockShps[i]);
end;

{ Set the level number to NewLevel, loading in new rock
  shapes if neccessary. }
procedure SetLevel(NewLevel : integer);
begin
  if NewLevel <> Level then begin
    Level := NewLevel;
  end;
end;

{ converts local player # to game player # }
function GetPlayerPosIdx(i : integer) : integer;
begin
  if (RS <> nil) and not Originator and (i >= 0) then begin
    if (i >= NumLocalPlayers) then
      GetPlayerPosIdx := i-NumLocalPlayers
    else
      GetPlayerPosIdx := i+NumRemotePlayers;
  end else
    GetPlayerPosIdx := i;
end;
{ converts game player # to local player # }
function GetPlayerIdxPos(i : integer) : integer;
begin
  if (RS <> nil) and not Originator and (i >= 0) then begin
    if (i >= NumRemotePlayers) then
      GetPlayerIdxPos := i-NumRemotePlayers
    else
      GetPlayerIdxPos := i+NumLocalPlayers;
  end else
    GetPlayerIdxPos := i;
end;

const
  BoardXOfs = 16;
  BoardYOfs = 16;
  BoardXWid = 124+BoardXOfs;
  BoardYWid = 36+BoardYOfs;

{ initializes the player status boards, & player initial positions }
procedure InitPlayerStats;
const
  PlyrPosns : array[0..MaxPlayers-1] of TPoint = (
   (X:-16000;Y:-8000),(X:16000;Y:8000),(X:16000;Y:-8000),(X:-16000;Y:8000));
var
  i,j : integer;
  NewPoint : TPoint;
  BoardX, BoardY : integer;
  R : TRect;
begin
{$IFNDEF scrnsave}
  GetClientRect(GameWnd, R);
  for i := 0 to NumPlayers-1 do begin
    j := GetPlayerPosIdx(i);
    if NumPlayers = 1 then begin
      NewPoint.X := 0;
      NewPoint.Y := 0;  { if only 1 player, put him in center }
    end else
      { *** FIX THIS ***! }
      NewPoint := PlyrPosns[j];
    if j in [0,3] then BoardX := BoardXOfs
                  else BoardX := R.right-BoardXWid;
    if j in [0,2] then BoardY := BoardYOfs
                  else BoardY := R.bottom-BoardYWid;
    Stats[i].Setup(BoardX, BoardY, NewPoint.X, NewPoint.Y, i, j);
    {$IFDEF commfile}if RS <> nil then
      Writeln(commf, 'Init player ',i,' as ',j,', x:',
      Newpoint.x,' y:',newpoint.y);{$ENDIF}
  end;
{$ENDIF}
end;

{ makes a new board full o' rocks }
procedure MakeRocks;
var i : integer;
    Rock : PRock;
begin
  MaxRockVel := longint(Level+GameParams.Difficulty*3)*30000 div StageMaxRes;
  NumRocks := ((Level+2+GameParams.Difficulty)*RocksPerLevel) shr 8;
  NumHatchRocks := NumRocks*3; { # big rocks & their children }
  NumRocksLeft := NumRocks*7;
  HatchesLeft := NumHatchRocks div (25-GameParams.Difficulty*6);
  if TournamentPlay then HatchesLeft := 0;
  for i := 1 to NumRocks do begin
    Rock := New(PRock, Init(@Stage, integer(Stage.ViewOrg.X),
      integer(Stage.ViewOrg.Y), RockShps[0], 0));
    Rock^.Vel.X := integer(random(MaxRockVel*2)-MaxRockVel);
    Rock^.Vel.Y := integer(random(MaxRockVel*2)-MaxRockVel);
    { IT BOMBS HERE IF YOU EXIT RIGHT AFTER STARTING! }
    if random(2) = 0 then begin { left or right }
      Rock^.Pos.Y := integer(random(Stage.ViewSize.X)+Stage.ViewOrg.X);
      if Rock^.Vel.X < 0 then inc(Rock^.Pos.X, Stage.ViewSize.X-1);
      { put on right }
    end else begin { top or bottom }
      Rock^.Pos.X := integer(random(Stage.ViewSize.Y)+Stage.ViewOrg.Y);
      if Rock^.Vel.Y < 0 then inc(Rock^.Pos.Y, Stage.ViewSize.Y-1);
      { put on bottom }
    end;
    Rock^.RockSize := 0;
    Stage.Add(Rock);
  end;
end;

{ set the pause variable to STATE }
procedure SetPause(state : word);
var
  LocalPause : boolean;
begin
  LocalPause := (Paused xor state) and pause_Local <> 0;
  if (Paused = 0) xor (state = 0) then begin
    if state <> 0 then begin
      StopTimer;
      if LocalPause then PauseMIDI;
    end else begin
      if LocalPause then PlayMidiFile;
      StartTimer(GameParams.MSecPerFrame);
    end;
  end;
  { change the button bar if the user pauses }
  if LocalPause then
    SetBtnBarText(ID_PAUSE,
      LoadStr(STR_PAUSE + ord(state and pause_User > 0)));
  Paused := state;
end;

{$IFNDEF nocomm}
{ sends a message with data & size -- if data = nil, sends DataSize w/ len = 2 }
procedure SendRemoteMsg(Msg : TRemoteMsg; Data : pointer; DataSize : integer);
var
  i : byte;
  Ack : TRemoteMsg;
  buf : array[0..255] of byte;
begin
  if RS <> nil then begin
    buf[0] := ord(Msg) or 128;
    if (Data <> nil) or (DataSize = 0) then begin
      if DataSize <> 0 then
        Move(Data^, buf[1], DataSize);
      RS^.WritePacket(buf, DataSize+1);
    end else begin
      Move(DataSize, buf[1], sizeof(DataSize));
      RS^.WritePacket(buf, sizeof(DataSize)+1);
    end;
    { wait for acknowledgement }
    inc(MsgAcks);
    {$IFDEF commfile} Writeln(commf, 'Send esc ',ord(msg),' Acks: ',MsgAcks,' Paused: ',Paused); {$ENDIF}
    SetPause(Paused or pause_RemoteAck);
  end;
end;

procedure SendRemote2Msg(Msg : TRemoteMsg; Data1 : pointer; DataSize1 : integer;
  Data2 : pointer; DataSize2 : integer);
var
  buf : array[0..255] of byte;
begin
  Move(data1^, buf[0], datasize1);
  Move(data2^, buf[0+datasize1], datasize2);
  SendRemoteMsg(Msg, @buf, datasize1+datasize2);
end;
{$ELSE}{nocomm}
procedure SendRemoteMsg(Msg : TRemoteMsg; Data : pointer; DataSize : integer);
begin
end;
{$ENDIF}{nocomm}

{ CHEAT - blows up all rocks on the stage }
procedure Armageddon;
var i : integer;
    P : PPlayer;
begin
  for i := 0 to Stage.Objs.Count-1 do begin
    P := Stage.Objs.At(i);
    if (typeof(P^) = typeof(TRock)) and (P^.Status and plyr_Dead = 0) then
      P^.Kill;
  end;
end;

procedure FindOutWhoWon;
var
  i,highest : integer;
begin
  highest := -1;
  PlayerWon := -1;
  for i := 0 to NumPlayers-1 do begin
    if Stats[i].Score > highest then begin
      PlayerWon := i;
      highest := stats[i].score;
    end;
  end;
  for i := 0 to NumPlayers-1 do
    if (i <> PlayerWon) and (Stats[i].Score = highest) then
      PlayerWon := -1;
  plyrwonname := PlayerNames[GetPlayerIdxPos(PlayerWon)];
end;

procedure ResizeGameWnd; forward;

procedure GetFullScreenWindowRect(Wnd : HWnd; var R : TRect);
var
  Style : longint;
begin
  Style := GetWindowLong(Wnd, GWL_STYLE);
  SetRect(R, 0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN));
  AdjustWindowRect(R, style, GetMenu(Wnd) > 0);
{  InflateRect(R, -1, -1);}
end;

procedure GetMainWndFullScreenRect(var R : TRect);
var
  R2 : TRect;
begin
  GetFullScreenWindowRect(MainWnd, R);
  GetWindowRect(BtnBarWnd, R2);
  dec(R.top, R2.bottom-R2.top-1);
end;

{ set the game mode to MODE and do whatever is required
  of that mode }
procedure SetGameMode(Mode : integer);
  const
    NotFullScreenModes = gmode_AttractMode+[gmode_None];
var
  R : TRect;
  Buf : array[0..15] of char;
  i,j,Plyr : integer;
  pc : PChar;
  b : boolean;
  col : TColorRef;

begin
  {$IFDEF commfile}if RS <> nil then Writeln(commf, 'Set game mode ',GameMode,' -> ',Mode);{$ENDIF}
  if Mode <> GameMode then begin
    GameMode := Mode;
    { turn off those damn Game & Players dialogs!!! }
    b := (RS = nil) or not (GameMode in gmode_Playing);
{    EnableWindow(GetDlgItem(BtnBarWnd, ID_GAME), b);}
    EnableWindow(GetDlgItem(BtnBarWnd, ID_PLAYERS), b);

    case Mode of
      gmode_Stop : begin
        { stop the game, clear the stage, reset to level 1 }
        Stage.Clear;
        {$IFNDEF scrnsave}
        InitPlayerStats;
        SetPause(Paused and pause_Local);
        SetSound(SoundOn or sound_Attract);
        StopMidiSong;
        {$ELSE}
        SetSound(SoundOn or sound_Attract);
        SetSound(SoundOn and not sound_Attract);
        StartMidiSong(GameSong);
        {$ENDIF}
        SetBtnBarText(ID_START, LoadStr(STR_START));
        SetLevel(1);
        for i := 0 to 2 do LoadRockShape(i);
        MakeRocks;
        SetGameMode(gmode_Attract);
        InvalidateRect(GameWnd, nil, false);
      end;
      gmode_Attract: begin
      {$IFDEF scrnsave}
        WaitTime := ScrnSaveWait;
        Stage.ClearForeProps;
      {$ELSE}
        { shareware banner }
        if IsShareware then begin
          Stage.ClearForeProps;
          GetClientRect(GameWnd, R);
          Stage.AddForeProp(New(PBigText,
            Init((R.right-R.left) shr 1, (R.bottom-R.top) div 6,
              LoadStr(STR_GAMETITLE), R.bottom div 10, GameFontName, 0, RGB(192, 160, 0))
          ));
          for i := 0 to 3 do begin
            if i = 0 then col := RGB(128, 0, 0)
                     else col := RGB(0, 160, 160);
            Stage.AddForeProp(New(PBigText,
              Init((R.right-R.left) shr 1, (R.bottom-R.top)*(4+i) div 14,
                LoadStr(STR_REGISTER+i), R.bottom div 16, GameFontName, 0, col)
            ));
          end;
          j := STR_RANDOMREG+v_random((STR_RANDOMLAST-STR_RANDOMREG) div 2)*2;
          if j < STR_RANDOMLAST then
          for i := 0 to 1 do begin
            Stage.AddForeProp(New(PBigText,
              Init((R.right-R.left) shr 1, (R.bottom-R.top)*(13+i) div 16,
                LoadStr(j+i), R.bottom div 24, GameFontName, 0, RGB(128, 0, 128))
            ));
          end;
          Stage.AddForeProp(New(PBigText,
            Init((R.right-R.left) shr 1, (R.bottom-R.top)*4 div 6,
              LoadStr(STR_REGISTER+7), R.bottom div 12, GameFontName, 0, RGB(192, 0, 192))
          ));
          WaitTime := AttractWait;
        end else
          SetGameMode(GameMode + 1);
        {$ENDIF}
      end;
      gmode_Attract+1 : begin
        { 1st attract mode screen }
        Stage.ClearForeProps;
        GetClientRect(GameWnd, R);
        Stage.AddForeProp(New(PBigText,
          Init((R.right-R.left) shr 1, (R.bottom-R.top) shr 2,
            LoadStr(STR_GAMETITLE), R.bottom div 6, GameFontName, 0, RGB(192, 160, 0))
        ));
        {$IFNDEF scrnsave}
        Stage.AddForeProp(New(PBigText,
          Init((R.right-R.left) shr 1, (R.bottom-R.top) shr 1,
            LoadStr(STR_COPYRIGHT), R.bottom div 16, GameFontName, 0, RGB(128, 0, 0))
        ));
        Stage.AddForeProp(New(PBigText,
          Init((R.right-R.left) shr 1, (R.bottom-R.top)*3 shr 2,
            LoadStr(STR_ALLRIGHTS), R.bottom div 16, GameFontName, 0, RGB(128, 0, 0))
        ));
        if IsShareware then
          Stage.AddForeProp(New(PBigText,
            Init((R.right-R.left) shr 1, (R.bottom-R.top)*5 div 6,
              LoadStr(STR_CREDIT), R.bottom div 24, GameFontName, 0, RGB(128, 0, 192))
          ))
        else begin
          pc := UserName;
          Stage.AddForeProp(New(PBigText,
            Init((R.right-R.left) shr 1, (R.bottom-R.top)*5 div 6,
              sprintf(LoadStr(STR_REGTO), pc),
              R.bottom div 24, GameFontName, 0, RGB(192, 0, 192))
          ));
        end;
        {$ENDIF}
        Stage.AddForeProp(New(PBitmapProp,
          Init((R.right-R.left) shr 1, (R.bottom-R.top)*5 shr 3,
            HLib, PChar(BMAP_HAMCO))));
        Stage.AddForeProp(New(PBitmapProp,
          Init(R.right-100, R.bottom-60, HLib, PChar(BMAP_PUBLISHER))));
        WaitTime := AttractWait;
      end;
      gmode_HiScores : begin
        { hi score screen }
        Stage.ClearForeProps;
        GetClientRect(GameWnd, R);
        Stage.AddForeProp(New(PBigText,
          Init((R.right-R.left) shr 1, R.top+R.bottom shr 4,
            LoadStr(STR_SCORESTITLE), R.bottom shr 4, GameFontName, 0, RGB(128, 0, 192))
        ));
        InflateRect(R, -((R.right-R.left) shr 2), -((R.bottom-R.top) shr 3));
        ReadHiScores;
        HiScores.Display(Stage, R, RGB(0, 160, 0), RGB(160, 160, 160), GameFontName);
        WaitTime := AttractWait;
      end;
      gmode_HiScores+1 : begin
        { go back to 1st attract screen }
        SetGameMode(gmode_Attract);
      end;
      gmode_TournamentWin : begin
        SetSound(SoundOn or sound_Attract);
        GetClientRect(GameWnd, R);
        PlayerWonRound := Level;
        if PlayerWon < 0 then
          pc := sprintf(LoadStr(STR_TIED), PlayerWonRound)
        else begin
          plyrwonname := PlayerNames[PlayerWon];
          pc := sprintf(LoadStr(STR_WINNER), plyrwonname);
        end;
        Stage.AddForeProp(New(PBigText,
          Init((R.right-R.left) shr 1, (R.bottom-R.top) shr 1,
            pc,
            R.bottom div 12, GameFontName, 0, RGB(32, 255, 64))
        ));
      end;
      gmode_NewLevel : begin
        SetSound(SoundOn and not sound_Attract);
        { in tournament mode, everybody gets their lives back. }
        if TournamentPlay and (Level > 0) then begin
          Stage.Objs.FreeAll;
          Stage.NewObjs.FreeAll;
          Stage.ClearForeProps;
          { see if game over! }
          if Level >= GameParams.TournamentLevels then begin
            FindOutWhoWon;
            if (PlayerWon >= 0) then begin {otherwise, it's a draw}
              SetGameMode(gmode_GameOver);
              Exit;
            end;
          end;
          for i := 0 to NumPlayers-1 do
            with Stats[i] do begin
              Lives := GameParams.TournamentLives;
              ReturnTime := 0;
            end;
          InvalidateRect(GameWnd, nil, false);
        end;
        { LEVEL xxx sign }
        SetLevel(Level+1);
        GetClientRect(GameWnd, R);
        if not TournamentPlay then
          pc := sprintf(LoadStr(STR_LEVEL), Level)
        else begin
          j := level; i := GameParams.TournamentLevels;
          if (j <= i) then
            pc := sprintf(LoadStr(STR_TOURLEVEL), j)
          else begin
            j := (j-i);
            pc := sprintf(LoadStr(STR_TIEBREAKER), j)
          end;
        end;
        Stage.AddForeProp(New(PBigText,
          Init((R.right-R.left) shr 1, (R.bottom-R.top) shr 2,
            pc,
            R.bottom shr 3, GameFontName, 0, RGB(255, 32, 128))
        ));
        WaitTime := NewLevelWait;
        AlienFreq := 200+1250 div (level+3);
        NextAlien := AlienFreq;
      end;
      gmode_Play : begin
        { now start playing the game }
        if not TournamentPlay or (GameParams.TournamentRocks > 0) then
          MakeRocks;
        { reset bonus flags }
        ActiveBonuses := [Low(TBonusType)..High(TBonusType)];
        if HatchesLeft = 0 then
          ActiveBonuses := ActiveBonuses - [CronieLoverBonus];
        Stage.ClearForeProps;
      end;
      gmode_GameOver : begin
        { game over - turn off sound, play the song, etc }
        SetSound(SoundOn or sound_Attract);
        StartMidiSong(DeathSong);
        SetBtnBarText(ID_START, LoadStr(STR_START));
        GetClientRect(GameWnd, R);
        if not TournamentPlay then begin
          Stage.AddForeProp(New(PBigText,
            Init((R.right-R.left) shr 1, (R.bottom-R.top) shr 1,
              LoadStr(STR_GAMEOVER), R.bottom div 6, GameFontName, 0, RGB(32, 255, 64))
          ));
        end else begin
          Stage.AddForeProp(New(PBigText,
            Init((R.right-R.left) shr 1, (R.bottom-R.top) shr 1,
              sprintf(LoadStr(STR_GAMEWINNER), plyrwonname),
              R.bottom div 8, GameFontName, 0, RGB(0, 192, 192))
          ));
        end;
        PlyrHiScoreNum := -1;
        WaitTime := GameOverWait;
      end;
      gmode_GameOver+1 : begin
        { check for high scores }
        Stage.ClearForeProps;
        if not CheatsWereOn then
          repeat
            ReadHiScores;
            { see if next player got a hi score }
            inc(PlyrHiScoreNum);
            if PlyrHiScoreNum < NumLocalPlayers then
              with Stats[PlyrHiScoreNum] do
                if (HiScores.IsHighScore(Score) > 0)
                  {$IFDEF hiscoretest}or true{$ENDIF} then
                begin
                  { if he did, play the song and log it in }
                  StartMidiSong(HighScoreSong);
                  SetGameMode(gmode_LogHighScore);
                  Exit;
                end;
          until PlyrHiScoreNum >= NumLocalPlayers-1;
        { nobody else got a high score, so go to the hiscore list }
        SetGameMode(gmode_HiScores);
      end;
      gmode_LogHighScore : begin
        LetterPos := 0;
        GetClientRect(GameWnd, R);
        Plyr := PlyrHiScoreNum + 1;
        Stage.AddForeProp(New(PBigText,
          Init((R.right-R.left) shr 1, R.top+R.bottom*2 div 3,
            sprintf(LoadStr(STR_PLAYERX), Plyr),
            R.bottom shr 3, GameFontName, 0, RGB(64, 64, 160))
        ));
        if HiScores.IsHighScore(Stats[PlyrHiscoreNum].Score) = 1 then begin
          Stage.AddForeProp(New(PBigText,
            Init((R.right-R.left) shr 1, R.top+R.bottom shr 3,
              LoadStr(STR_CONGRATS), R.bottom shr 3, GameFontName, 0, RGB(64, 64, 160))
          ));
          Stage.AddForeProp(New(PBigText,
            Init((R.right-R.left) shr 1, R.top+R.bottom shr 2,
              LoadStr(STR_GOTHIGH), R.bottom shr 4, GameFontName, 0, RGB(128, 0, 192))
          ));
        end else begin
          Stage.AddForeProp(New(PBigText,
            Init((R.right-R.left) shr 1, R.top+R.bottom div 4,
              LoadStr(STR_RANK), R.bottom shr 4, GameFontName, 0, RGB(128, 0, 192))
          ));
          Stage.AddForeProp(New(PBigText,
            Init((R.right-R.left) shr 1, R.top+R.bottom div 3,
              LoadStr(STR_RANK+1), R.bottom shr 4, GameFontName, 0, RGB(128, 0, 192))
          ));
        end;
        Stage.AddForeProp(New(PBigText,
          Init((R.right-R.left) shr 1, R.top+R.bottom*4 div 5,
            LoadStr(STR_PLEASEENTER), R.bottom shr 4, GameFontName, 0, RGB(255, 32, 128))
        ));
        InitialsText := New(PBigText,
          Init((R.right-R.left) shr 1, R.top+R.bottom shr 1,
            '_ _ _', R.bottom div 6, GameFontName, 0, RGB(192, 192, 192))
        );
        Stage.AddForeProp(InitialsText);
      end;
      gmode_LogHighScore+1 : begin
        SetGameMode(gmode_GameOver+1);
      end;
    end;
  end;
end;

{ this routine processes an initial }
procedure ProcessInitial(ScanCode : word);
var Txt : array[0..6] of char;
    Name : InitialsStr;
    hisc : PHiScoreEntry;
    R : TRect;
begin
  if LetterPos > 2 then Exit;
  StrCopy(Txt, InitialsText^.GetText);
  case lo(ScanCode) of
    ord('A')..ord('Z'),VK_SPACE : begin
      {$IFDEF wing}
      InitialsText^.GetRect(R);
      Stage.ClearRect(R);
      {$ENDIF}
      InitialsText^.PropDirty := true;
      Txt[LetterPos*2] := chr(lo(ScanCode));
      InitialsText^.ChangeText(Txt);
      inc(LetterPos);
      if LetterPos > 2 then begin
        Name[1] := Txt[0];
        Name[2] := Txt[2];
        Name[3] := Txt[4];
        hisc := New(PHiScoreEntry, Init(Name, Stats[PlyrHiScoreNum].Score));
        HiScores.Insert(hisc);
        SendRemoteMsg(RMSG_HISCORE, hisc, sizeof(hisc^));
        WriteHiScores;
        WaitTime := LogHighScoreWait;
      end;
    end;
    VK_BACK : begin
      if LetterPos > 0 then begin
        Txt[LetterPos*2-2] := '_';
        InitialsText^.ChangeText(Txt);
        dec(LetterPos);
        {$IFDEF wing}
        InitialsText^.GetRect(R);
        Stage.ClearRect(R);
        {$ENDIF}
        InitialsText^.PropDirty := true;
      end;
    end;
  end;
end;

{ creates a new alien spaceship }
procedure NewAlien;
var Alien : PAlien;
    Side : integer;
    X, Y : integer;
begin
  Side := random(2);
  if Side = 0 then X := Stage.ViewOrg.X
              else X := integer(Stage.ViewOrg.X+Stage.ViewSize.X-1);
  New(Alien, Init(@Stage, X,
    integer(random(Stage.ViewSize.Y shr 1)-Stage.ViewSize.Y shr 2),
    AlienShps[0]));
  Stage.Add(Alien);
  Alien^.Vel.X := (GameParams.Difficulty+2)*AlienSpeed;
  if Side = 1 then Alien^.Vel.X := -Alien^.Vel.X;
  Alien^.RotVel := 128;
end;

{ process all the ships' controls }
{ (send state to player object) }
procedure ProcessControls;
var
  i : integer;
begin
  for i := 0 to NumPlayers-1 do with Stats[GetPlayerIdxPos(i)] do
    if Ctrl <> nil then
      Ctrl^.Process;
end;

{ update all controls }
{ (get current state & write all controls to remote) }
{ finalize state of local controls }
procedure UpdateControls;
var
  i : integer;
  buf : array[0..8] of byte;
begin
    for i := 0 to NumLocalPlayers-1 do with Stats[i] do
    begin
      Ctrl^.Update;
      Move(Ctrl^.OnState, buf[i*2], 2);
    end;
    {$IFNDEF nocomm}
    if (RS <> nil) then begin
      buf[NumLocalPlayers*2] := GameChkSum;
      RS^.WritePacket(buf, NumLocalPlayers*2+1);
     {$IFDEF commfile}Writeln(commf, 'Sent - chksum ',GameChkSum);{$ENDIF}
    end;
    {$ENDIF}
end;

procedure StopGame;
begin
  SetGameMode(gmode_Stop);
end;

procedure Disconnect;
begin
  StopGame;
  {$IFDEF commfile}
  if RS <> nil then begin
    Writeln(commf, 'Disconnected');
    system.Close(commf);
  end;
  {$ENDIF}
  NumRemotePlayers := 0;
  RemoteDisconnect;
end;

procedure ErrorBox(errno : word);
var
  errmsg : PChar;
begin
  {$IFDEF commfile}
  if RS <> nil then Writeln(commf, 'Error: ', LoadStr(errno));
  {$ENDIF}
  errmsg := LoadStr(errno);
  if StrLen(errmsg) = 0 then
    errmsg := 'General error';
  MessageBox(MainWnd, errmsg, nil, MB_OK or MB_ICONEXCLAMATION);
  InvalidateRect(GameWnd, nil, false);
end;

{$IFNDEF nocomm}
{ logged a remote error }
procedure RemoteError(errno : word);
begin
  {$IFDEF commfile}
  if RS <> nil then Writeln(commf, 'Remote error: ', LoadStr(errno));
  {$ENDIF}
  SendRemoteMsg(RMSG_ERROR, nil, errno);
{  RS^.SetNotify(0, -1, -1, 0);}
{  if (RS <> nil) and (RS^.Status = stOk) then
    RS^.Status := stError;}
  ErrorBox(errno);
end;
{$ENDIF}{nocomm}
procedure ChatMessage(num : integer; Msg : Pchar);
var
  R : TRect;
  Rgn : HRgn;
  j, BoardX, BoardY : integer;
begin
  with Stats[num] do begin
    if (Stage.HasForeProp(ChatMsg)) then
    begin
      ChatMsg^.GetRect(R);
      {$IFNDEF wing}
      Rgn := CreateRectRgnIndirect(R);
      AddRgn(Stage.DrawRgn, Rgn);
      Check(DeleteObject(Rgn));
      {$ELSE}
      { *** }
      {$ENDIF}
      Stage.ClearForeProp(ChatMsg);
      ChatMsg := nil;
    end;
    if Msg <> nil then begin
      GetClientRect(GameWnd, R);
      j := GetPlayerPosIdx(num);
      if j in [0,3] then BoardX := BoardXOfs
                    else BoardX := R.right-BoardXOfs;
      if j in [0,2] then BoardY := BoardYWid+16
                    else BoardY := R.bottom-BoardYWid-16;
      ChatMsg := New(PBigText,
        Init(BoardX, BoardY, Msg, R.bottom div 30, GameFontName, 0,
          TransColor(PlyrColor, 128, 0)));
      ChatMsg^.XAlign := ord(j in [1,2])*2;
      ChatMsg^.YAlign := ord(j in [1,3])*2;
      Stage.AddForeProp(ChatMsg);
      ChatTime := ChatMessageWait;
    end;
  end;
end;

procedure ProcessChatChar(ScanCode : word);
var
  Buf : array[0..128] of char;
  I : byte;
begin
  with Stats[ChatPlayer] do begin
    if Stage.HasForeProp(ChatMsg) then begin
      StrLCopy(Buf, ChatMsg^.GetText, sizeof(Buf)-1);
      i := StrEnd(Buf)-Buf;
    end else
      i := 0;
    Buf[i] := Char(ScanCode);
    Buf[i+1] := #0;
    ChatMessage(ChatPlayer, Buf);
  end;
end;

procedure TournamentWin(Plyr : integer);
begin
  PlayerWon := Plyr;
  if Plyr >= 0 then
    with Stats[GetPlayerPosIdx(Plyr)] do begin
      AddScore(scor_Tourwin);
    end;
  SetGameMode(gmode_TournamentWin);
end;

function Rol(a,b : byte) : byte;
{$IFDEF WIN32}
register;
assembler; asm
{  mov  al,a}
  mov  cl,dl { dl = b }
  rol  al,cl
  and  eax,0ffh
end;
{$ELSE}
inline($59/$58/$d2/$c0); { pop cx; pop ax; rol al,cl }
{$ENDIF}

{ Called every tick of the clock }
procedure Update;
var DC : HDC;
    ShipsLeft, ThisPlayer : integer;
    i : integer;
    P : PPlayer;
    R : TRect;
begin
  ThisPlayer := -1;
{  PumpWaveSound; { doesn't work ??? }

  { update the stage }
  DC := GetDC(GameWnd);
  {$IFDEF wing}
  SelectPalette(DC, Pal, false);
  RealizePalette(DC);
  {$ENDIF}
  Stage.Update(DC);
  ReleaseDC(GameWnd, DC);

  { compute checksum, if necc. }
  if (RS <> nil) and SendFrame then begin
    LastChkSum := GameChkSum;
    GameChkSum := lo(GameFrame);
    for i := 0 to Stage.Objs.Count-1 do begin
      P := Stage.Objs.At(i);
      with P^ do inc(GameChkSum, Rol(byte(Pos.X+Pos.Y+Rot),lo(i)));
      {$IFDEF commfileverbose}with P^ do Writeln(commf, i,': Pos X:',Pos.X,' Y:',Pos.Y,' Rot:',Rot);{$ENDIF}
    end;
  end;

  { see if we gots rocks left }
  if NumRocksLeft = 0 then begin
    if GameMode = gmode_Play then
      SetGameMode(gmode_Newlevel)
    else
      if not (GameMode in gmode_Playing) then begin
        {$IFDEF scrnsave}
        Level := v_random(6)+1;
        for i := 0 to 2 do LoadRockShape(i);
        {$ENDIF}
        MakeRocks; { in attract mode }
      end;
  end;

  { if WaitTime > 0, we wait WaitTime frames than set the
    game mode to the next mode }
  if WaitTime > 0 then begin
    { see if we should load a new rock shape }
    if (GameMode = gmode_NewLevel) then begin
      i := NewLevelWait - WaitTime;
      if (i >= 0) and (i <= 2) then begin
        LoadRockShape(i);
      end;
    end;
    dec(WaitTime);
    if WaitTime = 0 then SetGameMode(GameMode+1);
  end;

  inc(GameFrame);
  if not TournamentPlay then begin
    dec(NextAlien);
    { see if another alien should come out }
    if NextAlien = 0 then begin
      NextAlien := AlienFreq;
      NewAlien;
    end;
  end;

  if GameMode in gmode_Playing then begin
    ShipsLeft := 0;
    { see if any ships need adding }
    for i := 0 to NumPlayers-1 do with Stats[GetPlayerIdxPos(i)] do begin
      if (CurShip = nil) and (Lives > 0) and (GameMode <> gmode_TournamentWin) then
      begin
        if SafeToAdd or
          ((ReturnTime = 0) and (gcBtn1 in Ctrl^.GetState) and (gcBtn2 in Ctrl^.GetState)) then
        begin
          AddNewShip;
        end;
      end;
      if (Lives > 0) or (CurShip <> nil) then begin
        inc(ShipsLeft);
        ThisPlayer := i;
      end;
      if ChatTime > 0 then begin
        dec(ChatTime);
        if ChatTime = 0 then ChatMessage(GetPlayerIdxPos(i), nil);
      end;
    end;
    { check for GAME OVER condition }
    if TournamentPlay then begin
      if (ShipsLeft <= 1) and (WaitTime = 0) then begin
        if ShipsLeft = 0 then
          TournamentWin(-1)
        else
          TournamentWin(ThisPlayer);
        WaitTime := TournamentWait;
      end;
    end else begin
      if (ShipsLeft = 0) and (WaitTime = 0) then begin
        WaitTime := BeforeGameOverWait;
      end;
    end;
  end;

  {$IFDEF commfile}
  if RS <> nil then begin
    Writeln(commf, 'Updated frame ',GameFrame,' randseed: ',randseed,
      ' chksum: ',GameChkSum);
    for i := 0 to NumPlayers-1 do with Stats[GetPlayerIdxPos(i)] do begin
      if Ctrl <> nil then
        Writeln(commf, i:3,' - State: ',byte(Ctrl^.OnState):4,byte(Ctrl^.OffState):4);
      if CurShip <> nil then
        with CurShip^ do
         Writeln(commf, 'Ship Pos X:',Pos.X,' Y:',Pos.Y,' Rot:',Rot);
    end;
  end;
  {$ENDIF}

end;

{$IFNDEF nocomm}
procedure SendPlayerMetrics(i : integer);
begin
  if RS <> nil then with Metrics[i] do begin
    SendRemote2Msg(RMSG_PLAYERDATA, @i, 1, @SpecialType,
      sizeof(SpecialType) + sizeof(Specs));
  end;
end;

procedure SendLocalPlayers;
var
  i : integer;
begin
  for i := 0 to NumLocalPlayers-1 do
    SendPlayerMetrics(i);
end;

procedure SendGameData;
begin
  if RS <> nil then begin
    SendRemoteMsg(RMSG_GAMEDATA, @GameParams, sizeof(GameParams));
  end;
end;
procedure SendNumberPlayers;
begin
  SendRemoteMsg(RMSG_NUMPLAYERS, @NumLocalPlayers, sizeof(NumLocalPlayers));
end;

procedure NewRemoteGame(Players : integer);
var
  i : integer;
begin
  { tell em how many players we got }
  NumLocalPlayers := Players;
  SendNumberPlayers;
  { now send our players over }
  for i := 0 to Players-1 do
    SendPlayerMetrics(i);
  Received := true;
end;

procedure StartRemoteGame(Players : integer);
begin
  if gamemode in gmode_Playing then
    StopGame;
  Originator := true;
  SendGameData;
  NewRemoteGame(Players);
  SendRemoteMsg(RMSG_START, @RandSeed, sizeof(RandSeed));
end;
{$ENDIF}{nocomm}

{ starts a new game w/ PLAYERS # of players }
procedure NewGame(Players : integer);
var
  i : integer;
  DC : HDC;
begin
  Stage.Clear;

  NumLocalPlayers := Players;
  NumPlayers := Players+NumRemotePlayers;

  UpdateShipShapes;

  Level := StartingLevel;
  TournamentPlay := GameParams.TournamentMode and (NumPlayers > 1);
  GameFrame := 0;
  GameChkSum := 0;
  LastChkSum := 0;
  SendFrame := true;
  {$IFDEF cheat}CheatsOn := [];{$ENDIF}
  CheatsWereOn := false;

  SetBtnBarText(ID_START, LoadStr(STR_START+1));
  GameMode := gmode_Stop;
  StartMidiSong(GameSong);
  SetGameMode(gmode_NewLevel);

  InitPlayerStats;
  for i := 0 to NumPlayers-1 do
    with Stats[GetPlayerIdxPos(i)] do begin
      Reset;
  {$IFDEF commfile}if RS <> nil then Writeln(commf, 'Adding ship ',num);{$ENDIF}
      AddNewShip;
    end;

  InvalidateRect(GameWnd, nil, false); { clear game board }
end;

{ to start new game:
     orig. sends player data, sends # of players, sends RMSG_START request
     remote receives RMSG_START, sends player data, ACK, # of players, and starts game
     orig. receives ack, starts game
}

{$IFNDEF nocomm}
procedure EscapeMsgFunc(Msg : TRemoteMsg; Data : PChar);
type
  PWord = ^word;
var
  i : byte;
  Buf : PChar;
  DC : HDC;
  ackmsg : record ack : byte; msg : TRemoteMsg end;
  hisc : PHiScoreEntry;
begin
  case Msg of
    RMSG_ACK : begin
      move(data^, ackmsg.msg, 1);
      dec(MsgAcks);
      if MsgAcks = 0 then
        SetPause(Paused and not pause_RemoteAck);
      if ackmsg.msg = RMSG_START then begin
        if NumRemotePlayers > 0 then 
          NewGame(NumLocalPlayers);
      end;
      Exit;
    end;
    RMSG_NUMPLAYERS : begin
      Move(data^, NumRemotePlayers, sizeof(NumRemotePlayers));
      if word(NumRemotePlayers + NumLocalPlayers) > 4 then begin
        ErrorBox(STR_2MANYPLAYERS);
        NumRemotePlayers := 0;
      end;
    end;
    RMSG_START : begin
      Originator := false; { person initiating gets the Originator status }
      {$IFDEF commfile} Writeln(commf, 'New game: ',NumLocalPlayers,' against ',NumRemotePlayers); {$ENDIF}
      Move(data^, RandSeed, sizeof(RandSeed));
      NewRemoteGame(NumLocalPlayers);
      if NumRemotePlayers > 0 then begin
        NewGame(NumLocalPlayers);
      end;
    end;
    RMSG_STOP : begin
      StopGame;
    end;
    RMSG_PLAYERDATA : begin
      Move(data^, i, 1); { read player # }
      if i < NumRemotePlayers then
      begin
        inc(i, NumLocalPlayers);
        with Metrics[i] do begin
          Move((data+1)^, SpecialType, sizeof(SpecialType) + sizeof(Specs));
        end;
        with Stats[i] do begin
          if CurShip <> nil then begin
            CurShip^.SetParams;
          end;
        end;
      end;
    end;
    RMSG_GAMEDATA : begin
      Move(data^, GameParams, sizeof(GameParams));
    end;
    RMSG_CHAT : begin
      Move(data^, i, 1); { read player # }
      ChatMessage(i+NumLocalPlayers, data+1);
    end;
    RMSG_ERROR: begin
      { remote hung up! }
      StopGame;
      MessageBox(MainWnd, LoadStr(PWord(data)^), nil, MB_OK or MB_ICONEXCLAMATION);
    end;
    RMSG_HISCORE : begin
      with PHiScoreEntry(data)^ do
        HiScores.Insert(New(PHiScoreEntry, Init(Initials, Score)));
      WriteHiScores;
    end;
    RMSG_BYEBYE: begin
      ErrorBox(STR_REMOTEBYE);
      Disconnect;
    end;
  end;
  { send acknowledgment }
  if RS <> nil then begin
    ackmsg.ack := ord(RMSG_ACK) or 128;
    ackmsg.msg := TRemoteMsg(msg);
    RS^.WritePacket(ackmsg, 2);
  end;
end;
{$ENDIF}{nocomm}

{ make the random starfield }
procedure MakeStars(Width, Height : word);
var i : integer;
    n : byte;
begin
  for i := 0 to MaxStars do with Stars[i] do begin
    n := v_random(256) and 127+96;
    Color := RGB(n, n, n)+(v_random($1000000) and $1F1F1F);
    Pos.X := v_random(Width); Pos.Y := v_random(Height);
  end;
end;

procedure SendCtrlMessage(Message, wParam : word; lParam : longint);
var
  i : integer;
begin
  for i := 0 to NumLocalPlayers-1 do with Stats[i] do begin
    if Ctrl <> nil then Ctrl^.Message(Message, wParam, lParam);
  end;
end;

procedure ProcessTimerTick;
var
  Pt : TPoint;
  R : TRect;
begin
  {$IFNDEF scrnsave}
  if HideMouseTimer > 0 then begin
    dec(HideMouseTimer);
    if (HideMouseTimer = 0) then begin
      GetCursorPos(Pt);
      if WindowFromPoint(Pt) = GameWnd then
        SetCursor(0);
    end;
  end;
  {$ELSE}
  { screen saver -- swap out stuff after a selected # of frames }
  if (GameFrame mod PreventBurnoutTime) = PreventBurnoutTime-1 then begin
    with Stage do begin
      MakeStars(XRes, YRes);
      SetRect(R, 0, 0, XRes, YRes);
      FillRect(GDC, R, GetStockObject(BLACK_BRUSH));
      FillRect(BkgndDC, R, GetStockObject(BLACK_BRUSH));
    end;
    if (GameFrame mod (PreventBurnoutTime*2)) = PreventBurnoutTime*2-1 then
      InvalidateRect(GameWnd, nil, false);
  end;
  {$ENDIF}

  { update at specified interval, default is every frame }
  with GameParams do begin
    SendFrame := (UpdateInterval < 2) or (GameFrame mod GameParams.UpdateInterval = 0);
  end;

  if GameMode in gmode_Playing then
  begin
    if (RS <> nil) and SendFrame then
    begin
      {$IFDEF commfile}EnableWindow(GetDlgItem(BtnBarWnd, ID_ABOUTBTN), Received);{$ENDIF}
      if not Received then begin
        {$IFDEF commfile}Writeln(commf, 'waiting'); {$ENDIF}
        SetPause(Paused or pause_CommWait);
        Exit;
      end else
        Received := false;
    end;

    { we need to "process" (send to players) right before we "update"
      (get current state, send to other party) }
    if (RS <> nil) and SendFrame then
      ProcessControls;

    { get control state, write all controls to output device, if necc. }
    if (RS = nil) or SendFrame then
      UpdateControls;

    { if no remote connection, process controls now }
    if RS = nil then
      ProcessControls;

    { update world }
    Update;

  end else begin
    { attract mode - just update world }
    Update;
  end;
end;

function GameWndProc(Wnd: Hwnd; Message, WParam: Word;
  LParam: LongInt): LongInt; export;{$IFDEF win32}stdcall;{$ENDIF}
var
  ProcAbout: TFarProc;
  DC : HDC;
  PS : TPaintStruct;
  i : integer;
  w,h : integer;
  GameRect : TRect;
begin
  GameWndProc := 0;
  case message of
    WM_TIMER: begin
      if Paused = 0 then
        ProcessTimerTick;
    end;
    {$IFNDEF scrnsave}
    WM_KEYDOWN:
        if (LongRec(lParam).Hi and $4000) = 0 then      { if first time pressed }
          SendCtrlMessage(Message, wParam, lParam);
    WM_MOUSEMOVE: begin
      { reset the mouse hide counter }
      HideMouseTimer := HideMouseCount;
      Stage.SendMessage(Message, wParam, lParam);
    end;
    WM_KEYUP: begin
      SendCtrlMessage(Message, wParam, lParam);
    end;
{    WM_SYSKEYUP:
      if (wParam <> VK_MENU) then
        MainWndProc := DefWindowProc(Wnd, Message, WParam, LParam);}
    {$ENDIF}
    WM_PAINT: with PS do begin
        BeginPaint(Wnd, PS);
        {$IFDEF wing}
        SelectPalette(PS.hdc, Pal, false);
        RealizePalette(PS.hdc);
        {$ENDIF}
        Stage.Show(PS.hdc);
        EndPaint(Wnd, PS);
      end;
    WM_SIZE: if (wParam <> sizeIconic) then begin
      with LongRec(lParam) do begin
        StageMinRes := IMin(Lo, Hi);
        StageMaxRes := IMax(Lo, Hi);
        StageMin := MulDiv(StageMax, StageMinRes, StageMaxRes);
        if Lo > Hi then begin { X > Y }
          Stage.SetViewingArea(-StageMax, -StageMin, StageMax, StageMin, Lo, Hi);
        end else begin
          Stage.SetViewingArea(-StageMin, -StageMax, StageMin, StageMax, Lo, Hi);
        end;
        SafeRadius := 3000000 div StageMaxRes;
        VelocRadius := 4000 div StageMaxRes;
        AlienSpeed := 100000 div StageMaxRes;
        RocksPerLevel := StageMaxRes div 3+1;
        MakeStars(Lo, Hi);
        InitPlayerStats;
      end;
    end;
{    WM_NCPAINT: begin
      PaintWindowFrame(Wnd);
    end;}
    {$IFDEF scrnsave}
    WM_KEYDOWN,WM_MOUSEMOVE,WM_LBUTTONDOWN,WM_MBUTTONDOWN,WM_RBUTTONDOWN : begin
      { i have no idea how Windows screen savers work }
      if GameFrame > 8 then
        SendMessage(MainWnd, WM_CLOSE, 0, 0);
    end;
    {$ENDIF}
  else
    GameWndProc := DefWindowProc(Wnd, Message, WParam, LParam);
  end;
end;

function AboutDlgProc(Dlg: Hwnd; Message, WParam: Word; LParam: Longint): Bool;
  export; {$IFDEF win32}stdcall;{$ENDIF}
begin
  AboutDlgProc := true;
  case Message of
    WM_INITDIALOG: begin
      CenterWindow(Dlg, nil);
      SendDlgItemMessage(Dlg, id_AboutVersion, WM_SETTEXT, 0, longint(PChar(VersionString)));
      Exit;
    end;
    WM_COMMAND:
      if WParam = idOk then
      begin
        EndDialog(Dlg, 1);
        Exit;
      end;
  end;
  AboutDlgProc := false;
end;

procedure ResizeGameWnd;
{ called when the main window size is changed }
var
  R, GameRect : TRect;
begin
  if IsWindow(GameWnd) then
  begin
    GetWindowRect(GameWnd, GameRect);
    GetClientRect(MainWnd, R);
    MapWindowPoints(0, MainWnd, GameRect, 2);
    MoveWindow(GameWnd, GameRect.left, GameRect.top,
      R.right-GameRect.left, R.bottom-GameRect.top, true);
  end;
end;

{$IFNDEF nocomm}
function HandleComm : boolean;
var
  i : integer;
  msgbuf : array[0..255] of byte;
  msg : byte;
begin
  HandleComm := false;

  { if we already got a msg., hang out until the next update frame }
  { we'll have to return here after we update the screen }
  if (GameMode in gmode_Playing) and Received and (Paused = 0) then
    Exit;

  if RS^.Status <> stOk then begin
    RemoteError(RS^.ErrorInfo);
    Disconnect;
    Exit;
  end;

  if ((RS^.ReadPacket(msgbuf, sizeof(msgbuf)) > 0)) then
  begin
    msg := msgbuf[0];
    if msg and $80 > 0 then begin
      { handle a special message }
      msg := msg and 127;
      {$IFDEF commfile} Writeln(commf, 'Recv esc ',ord(msg),' Acks: ',MsgAcks,' Paused: ',Paused); {$ENDIF}
      if msg > (ord(High(TRemoteMsg))) then begin
        RemoteError(STR_INFOERROR);
        Disconnect;
      end else
        EscapeMsgFunc(TRemoteMsg(msg), @msgbuf[1]);
    end else begin
      if GameMode in gmode_Playing then begin
        {$IFDEF commfile} Writeln(commf, 'Received - chksum ',msgbuf[NumRemotePlayers*2],' Received = ',Received); {$ENDIF}

        { if we already got one, and it's paused, then go 'head and update }
        if Received then begin
          repeat ProcessTimerTick until SendFrame;
        end;

        { this is a player-state packet }
        for i := 0 to NumRemotePlayers-1 do begin
          with Stats[NumLocalPlayers+i] do begin
            if Ctrl <> nil then with Ctrl^ do begin
              SetState(GameKeyState(msgbuf[i*2]), GameKeyState(msgbuf[i*2+1]));
              Update;
            end;
          end;
        end;

        { if we're reading from a remote stream, we process the controls AFTER the game
          has processed a frame. This is so we can read the remote computer's controls
          during the break before the next frame }
{        if ReceiveFrame then ProcessControls;}

        Received := true;
        { check checksum }
        if msgbuf[NumRemotePlayers*2] <> LastChkSum then begin
          StopGame;
          RemoteError(STR_OUTOFSYNC);
          Exit;
        end;

        if (Paused and pause_CommWait > 0) then begin
          SetPause(Paused and not pause_CommWait);
          if Paused = 0 then begin
            {$IFDEF commfile} Writeln(commf, 'unwaiting'); {$ENDIF}
            ProcessTimerTick;
          end;
        end;
        {$IFDEF commfile}
        Writeln(commf, 'recvd ',Received, ' pause ',Paused);
        {$ENDIF}
      end;
    end;
    HandleComm := true;
  end;
end;
{$ENDIF}{nocomm}

function MainWndProc(Wnd: Hwnd; Message, WParam: Word;
  LParam: LongInt): LongInt; export; {$IFDEF win32}stdcall;{$ENDIF}
var DC : HDC;
    i : integer;
    AboutProc : TFarProc;
    PrevFullScreen : boolean;
    R : TRect;
    {$IFDEF cheat}cht : TCheatType; ch : char;{$ENDIF}
begin
  MainWndProc := 0;
  case message of
    {$IFNDEF scrnsave}
    WM_KEYUP, WM_KEYDOWN: begin
      {$IFDEF cheat}
      if not IsShareware then
      begin
        if (message = WM_KEYDOWN) and (chr(wParam) in ['A'..'Z']) and (RS = nil) then
        begin
          Move(CheatBuf[0], CheatBuf[1], sizeof(CheatBuf)-1);
          CheatBuf[0] := chr(wParam);
          for cht := Low(TCheatType) to High(TCheatType) do
            if StrLComp(CheatBuf, CheatCodes[cht], StrLen(CheatCodes[cht])) = 0 then
            begin
              case cht of
                cheat_Nuke : Armageddon;
              else
                if cht in CheatsOn then Exclude(CheatsOn, cht)
                                   else Include(CheatsOn, cht);
              end;
              Sounds[snd_Disrupt]^.Play;
              CheatsWereOn := true;
              Exit;
            end;
          end;
          (*
          case wParam of
            VK_F5 : Armageddon; { TAKE THIS OUT!!! }
            VK_F6 : Stats[0].AddScore(2);
            VK_F7 : Stats[0].CurShip^.Kill;
          end;
          *)
      end;
      {$ENDIF}
      if (message = WM_KEYDOWN) then begin
        { are we chatting? }
        if (ChatPlayer >= 0) then
          case wParam of
            VK_RETURN : begin
              if RS <> nil then with Stats[ChatPlayer] do
              begin
                if Stage.HasForeProp(ChatMsg) then
                 with ChatMsg^ do
                  if GetText <> nil then
                    SendRemote2Msg(RMSG_CHAT, @ChatPlayer, 1, GetText, StrLen(GetText)+1)
                  else
                    SendRemote2Msg(RMSG_CHAT, @ChatPlayer, 1, GetText, 1);
              end;
              ChatMessage(ChatPlayer, nil);
              ChatPlayer := -1;
              Exit;
            end;
            VK_ESCAPE : begin
              ChatMessage(ChatPlayer, nil);
              ChatPlayer := -1;
              Exit;
            end;
            VK_SPACE,ord('0')..ord('Z') : begin
              ProcessChatChar(wParam);
              Exit;
            end;
          end;
        { process F1-F4 keys }
        if (RS <> nil) and (wParam >= VK_F1) and (wParam <= VK_F4) then begin
          if (wParam-VK_F1) < NumLocalPlayers then begin
            ChatPlayer := wParam-VK_F1;
            ChatMessage(ChatPlayer, nil);
          end;
          Exit;
        end;
        { process high-score initials }
        if (GameMode = gmode_LogHighScore) then begin
          ProcessInitial(wParam);
          Exit;
        end;
        { key to get out of full-screen? }
        if (wParam = VK_ESCAPE) then
        begin
          if (GameMode in gmode_Playing) and FullScreenDesired then
            if MessageBox(MainWnd, LoadStr(STR_QSTOPTHEGAME), '',
              MB_OKCANCEL or MB_ICONQUESTION) = IDOK
            then
              StopGame;
          { if we're not playing a game, get out of full-screen }
          if not (GameMode in gmode_Playing) and FullScreenDesired then
          begin
            FullScreenDesired := false;
            ShowWindow(MainWnd, SW_RESTORE);
            ShowWindow(MainWnd, SW_MAXIMIZE);
          end else
            { otherwise, minimize window }
            ShowWindow(MainWnd, SW_MINIMIZE);
        end;
      end;
      { send key message to game window }
      SendMessage(GameWnd, Message, wParam, lParam);
    end;
    {$ENDIF}
    MM_WOM_DONE: begin
      DoneWaveChannel(wParam);
      Exit;
    end;
    MM_MCINOTIFY : begin
      if (wParam = MCI_NOTIFY_SUCCESSFUL)
        {$IFNDEF scrnsave}
        and (Paused = 0)
        and (GameMode in gmode_Playing)
        {$ENDIF}
      then begin
{        RestartMIDI;}
        StartMidiSong(GameSong);
      end;
      Exit;
    end;
    {$IFNDEF scrnsave}
    WM_SYSCHAR: if (lParam and $20000000 > 0) and (wParam in [$21..$7F]) then begin
      PostMessage(GetDlgItem(BtnBarWnd, ID_START),
        Message, wParam, lParam);
    end else
      MainWndProc := DefWindowProc(Wnd, Message, WParam, LParam);
    {$ENDIF}
    WM_CLOSE : begin
      SendRemoteMsg(RMSG_BYEBYE, nil, STR_REMOTEBYE);
      Disconnect;
      PostQuitMessage(0);
    end;
    WM_GETMINMAXINFO : begin
      { if full screen or in remote play, use the full screen }
      if FullScreenDesired or (RS <> nil) then
      begin
        GetMainWndFullScreenRect(R);
        { set the maximized window rectangle }
        with PMinMaxInfo(lParam)^, R do
        begin
          ptMaxSize.X := right-left;
          ptMaxSize.Y := bottom-top;
          ptMaxPosition.X := left;
          ptMaxPosition.Y := top;
        end;
      end;
      { if the game is in progress, keep it from being messed up }
      if not (GameMode in gmode_AttractMode) or FullScreenDesired {and not IsIconic(Wnd) }then
      begin
        with PMinMaxInfo(lParam)^ do
        begin
          ptMaxTrackSize := ptMaxSize;
          ptMinTrackSize := ptMaxSize;
        end;
      end;
    end;
    WM_SIZE: begin
      if (wParam <> sizeIconic) and
        (GameMode in gmode_AttractMode)
      then begin
        ResizeGameWnd;
        GetWindowRect(MainWnd, MainWndGameRect);
        StopGame;
      end;
    end;
    WM_PALETTECHANGED, WM_QUERYNEWPALETTE: begin
      if (message = WM_PALETTECHANGED) and (wParam = Wnd) then
        Exit;
      SelectPalette(MainDC, Pal, false);
      MainWndProc := RealizePalette(MainDC);
      Exit;
    end;
    {$IFNDEF scrnsave}
    WM_ACTIVATE: begin
      if wParam = WA_INACTIVE then begin
        if PauseWhenInactive then SetPause(Paused or pause_Inactive)
      end else begin
        SetPause(Paused and not pause_Inactive);
      end;
      { pause game when window inactive }
    end;
    WM_COMMAND: begin
      {$IFDEF commfile}if RS <> nil then Writeln(commf, 'Command ',wParam);{$ENDIF}
      case wParam of
        ID_1PLYR..ID_4PLYR : begin
          if RS <> nil then StartRemoteGame(wParam-ID_1PLYR+1)
                       else NewGame(wParam-ID_1PLYR+1);
        end;
        ID_START : case GameMode of
          gmode_Attract..gmode_HiScores,gmode_GameOver : begin
            if RS <> nil then StartRemoteGame(NumLocalPlayers)
                         else NewGame(NumLocalPlayers);
          end;
        else
          SendRemoteMsg(RMSG_STOP, nil, 0);
          StopGame;
        end;
        ID_SOUND : begin
          if not SetSound(SoundOn xor sound_User) then
            MessageBeep(0);
        end;
        ID_MUSIC : begin
          if not SetMusic(MusicOn xor sound_User) then
            MessageBeep(0);
        end;
        ID_HELP : begin
          WinHelp(MainWnd, 'COMET.HLP', HELP_CONTEXT, 256+ord(IsShareware));
          if GameMode = gmode_Attract { register now } then
            WinHelp(MainWnd, 'COMET.HLP', HELP_SETCONTENTS, 512)
          else
            WinHelp(MainWnd, 'COMET.HLP', HELP_SETCONTENTS, 256+ord(IsShareware));
        end;
        ID_ABOUTBTN : begin
          DialogBox(HInstance, PChar(DLG_ABOUT), MainWnd, @AboutDlgProc);
          Exit;
        end;
        ID_PLAYERS : begin
          DialogBoxLib(HInstance, HStrLib, PChar(DLG_PLAYERS),
            GameWnd, @PlayerDlgProc);
          for i := 0 to NumPlayers-1 do with Stats[i], Metrics[i] do begin
            if i < NumLocalPlayers then
              SendPlayerMetrics(i);
            if CurShip <> nil then begin
              CurShip^.SetParams; { CRASH! }
            end;
            MakeControls;
          end;
          UpdateShipShapes;
          DefineJoyNumbers;
        end;
        ID_GAME : begin
          PrevFullScreen := FullScreenDesired;

          i := DialogBoxLib(HInstance, HStrLib, PChar(DLG_GAME), GameWnd, @GameDlgProc);

          if (FullScreenDesired <> PrevFullScreen) and
            (GameMode in gmode_AttractMode) then
          begin
            ShowWindow(MainWnd, SW_RESTORE);
            ShowWindow(MainWnd, SW_MAXIMIZE);
          end;
          case i of
            ID_OK : begin
              SendGameData;
            end;
            ID_DIAL, ID_ANSWER : begin
              StopGame;
              MsgAcks := 0;
{$IFDEF commfile}
Assign(commf, 'rs'+chr(RemoteParams.port+ord('0'){$IFDEF loopback}+ord(HPrevInst<>0){$ENDIF})+'.txt');
Rewrite(commf); {$ENDIF}
              Originator := i = ID_DIAL;
              SetPause(Paused or pause_CommWait);
              RemoteConnect(Originator);
              SetPause(Paused and not pause_CommWait);
              Originator := false;
            end;
            ID_DISCONNECT : begin
              SendRemoteMsg(RMSG_BYEBYE, nil, STR_REMOTEBYE);
              Disconnect;
            end;
          end;
        end;
        ID_PAUSE : begin
          SetPause(Paused xor pause_User);
        end;
      end;
    end;
    {$ELSE}{scrnsave}
    WM_ACTIVATE,WM_ACTIVATEAPP,WM_NCACTIVATE : begin
      if wParam = 0 then
        SendMessage(MainWnd, WM_CLOSE, 0, 0)
      else
        SetPause(0);
    end;
    WM_SETCURSOR : begin
      SetCursor(0);
      Result := 1;
    end;
    WM_SYSCOMMAND : begin
      if (wParam = SC_SCREENSAVE) or (wParam = SC_CLOSE) then
        MainWndProc := 0
      else
        MainWndProc := DefWindowProc(Wnd, Message, WParam, LParam);
    end;
    {$ENDIF}
  else
    MainWndProc := DefWindowProc(Wnd, Message, WParam, LParam);
  end;
end;

const
  ClassName = 'CometGameWnd';
  MainClassName = 'CometMain';

function InitInstance(Instance: THandle; CmdShow: Integer): Boolean;
var OldCursor : HCursor;
    Child : HWnd;
    MainRect, BarRect : TRect;
const
  MainWndStyle =
    {$IFNDEF scrnsave}WS_OVERLAPPEDWINDOW or WS_MAXIMIZE
    {$ELSE}WS_MAXIMIZE or WS_POPUP
    {$ENDIF};
begin
  InitInstance := false;

  MainWnd := CreateWindow(MainClassName, LoadStr(STR_MAINWNDTITLE),
    MainWndStyle,
    CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
    HWND_DESKTOP, 0, Instance, nil);
  if MainWnd = 0 then Exit;
{  MainDC := GetDC(MainDC);}
{  keep window maximized }
  if (CmdShow = SW_RESTORE) or (CmdShow = SW_NORMAL) then
    CmdShow := SW_SHOWMAXIMIZED;
  { make button bar }
  BtnBarWnd := CreateDialog(HStrLib, PChar(DLG_BTNBAR), MainWnd, @BtnBarDlgProc);
  if BtnBarWnd = 0 then begin
    DestroyWindow(MainWnd);
    Exit;
  end;
  {$IFDEF scrnsave}
  GetWindowRect(BtnBarWnd, BarRect);
  with BarRect do MoveWindow(BtnBarWnd, left, top, right-left, 1, false);
  AlienFreq := 100;
  NextAlien := AlienFreq;
  {$ENDIF}
  { make game window }
  GetClientRect(MainWnd, MainRect);
  GetWindowRect(BtnBarWnd, BarRect);
  GameWnd := CreateWindow(ClassName, nil, WS_CHILD or WS_VISIBLE,
    MainRect.left, MainRect.Top+BarRect.bottom-BarRect.Top, MainRect.right,
    MainRect.bottom-BarRect.bottom+BarRect.Top, MainWnd, 0, Instance, nil);
  if GameWnd = 0 then begin
    DestroyWindow(MainWnd);
    Exit;
  end;
{  SetWindowPos(GameWnd, HWND_TOP, 0, 0, 0, 0, SWP_NOACTIVATE or SWP_NOMOVE
    or SWP_NOSIZE or SWP_NOREDRAW);
    { this is needed to send the WM_SIZE message }
  { grey Music button if shareware version }

  OldCursor := SetCursor(LoadCursor(0, IDC_WAIT));
  Setup;
  SetBtnBarText(ID_PAUSE, LoadStr(STR_PAUSE));
  StopGame;
  SetCursor(OldCursor);

{  if IsShareware then
    EnableWindow(GetDlgItem(BtnBarWnd, ID_MUSIC), false);}
  ShowWindow(MainWnd, CmdShow);
{  UpdateWindow(MainWnd);}

  InitInstance := True;
end;

function InitApplication(Instance: THandle): Boolean;
var
  WC, WCMain : TWndClass;
begin
  with WC do
  begin
    style := CS_HRedraw or CS_VRedraw or CS_ByteAlignClient;
    lpfnWndProc := @GameWndProc;
    cbClsExtra := 0;
    cbWndExtra := 0;
    hInstance := Instance;
    hIcon := 0;
    hCursor := LoadCursor(0, IDC_ARROW);
    hbrBackground := 0;
    lpszMenuName := nil;
    lpszClassName := ClassName;
  end;
  FillChar(WCMain, sizeof(WCMain), 0);
  with WCMain do
  begin
    style := CS_HRedraw or CS_VRedraw;
    lpfnWndProc := @MainWndProc;
    hInstance := Instance;
    hIcon := LoadIcon(Instance, PChar(1));
    hCursor := LoadCursor(0, IDC_ARROW);
    lpszClassName := MainClassName;
  end;
  InitApplication := Bool(RegisterClass(WC))
    and Bool(RegisterClass(WCMain))
    and RegisterBtnBarClass;
  {$IFDEF loopback}
  InitApplication := true;
  {$ENDIF}
  {$IFDEF scrnsave}
  InitApplication := true;
  {$ENDIF}
end;

var
  ErrMode : word;
  Message: TMsg;
var
  Buf : array[0..255] of char;

{$IFDEF beta}
procedure SeeIfExpired;
const
  BetaExpireTime = 728994 { 12/1/96 };
{var dt : TDateTime;}
begin
{  dt := EncodeDate(1996,12,1);}
  if (Now > BetaExpireTime) then
  begin
    MessageBox(MainWnd, 'Sorry, this beta has expired. Contact hamco@pobox.com '+
      'for information on upgrading this program, or go to '+
      '"http://pobox.com/~hamco/cometbus.html".',
      nil, MB_OK or MB_ICONEXCLAMATION);
    Halt;
  end;
end;
{$ENDIF}

begin { main }
  {$IFDEF scrnsave}
  GetProfileString('Comet Busters!', 'Path', 'c:\comet', Buf, sizeof(Buf));
  ChDir(StrPas(Buf));
  INIFileName := StrNew(StrPChar(StrPas(Buf)+'\comet.ini'));
  {$ELSE}
  INIFileName := GetINIFileName;
  {$ENDIF}
  {$IFDEF STRESS}
  AllocMem(2000000);
  AllocGDIMem(10000);
  {$ENDIF}
  {$IFDEF beta}
  SeeIfExpired;
  {$ENDIF}

  PreInitApplication;
  ErrMode := SetErrorMode(SEM_NOOPENFILEERRORBOX);
  LoadLanguageLib;

  {$IFDEF scrnsave}
  if ParamStr(1) = '/c' then begin
    LoadHiScores;
    ReadINIFile;
    DialogBoxLib(HInstance, HStrLib, PChar(DLG_SCRNSAVE), 0, @ScrnSaveSetDlgProc);
{    MessageBox(0, 'No settings available', nil, MB_ICONEXCLAMATION or MB_SYSTEMMODAL);}
    WriteINIFile;
    Halt;
  end;
  {$ENDIF}
  { see if our resource count is too low }
  if GetFreeSystemResources(GFSR_SYSTEMRESOURCES) < 20 then
    FatalError(STR_NORESOURCES, MB_ICONHAND);

  {$IFNDEF scrnsave}ShowInitDialog;{$ENDIF}
  {$IFDEF EXELIB}
  HLib := HInstance;
  {$ELSE}
  {$IFNDEF scrnsave}
  {$IFNDEF loopback}
  if hPrevInst <> 0 then FatalError(Str_OneCopy, MB_ICONHAND);
  {$ENDIF}
  {$ENDIF}
  HLib := LoadLibrary('COMET1.DLL');
  if HLib < HINSTANCE_ERROR then FatalError(Str_NoLoadDll, MB_ICONHAND);
  HSndLib := LoadLibrary('COMETSND.DLL');
  if HSndLib < HINSTANCE_ERROR then FatalError(Str_NoLoadDll, MB_ICONHAND);
  {$ENDIF}
  SetErrorMode(ErrMode);

    SetMessageQueue(64);
    if not InitApplication(hInstance) then
      FatalError(str_NoInitApp, MB_ICONHAND);
    if not InitInstance(hInstance, CmdShow) then
      FatalError(str_NoInitInst, MB_ICONHAND);

  {$IFNDEF scrnsave}HideInitDialog;{$ENDIF}

  try

    repeat
      while PeekMessage(Message, 0, 0, 0, pm_Remove) do begin
        if Message.message = wm_Quit then
          Exit;
        if not IsDialogMessage(BtnBarWnd, Message) then begin
          TranslateMessage(Message);
          DispatchMessage(Message);
        end else begin
          if (IsWindow(BtnBarWnd)) and (IsChild(BtnBarWnd, GetFocus)) and
            (GetCapture = 0) then
          begin
            SendMessage(BtnBarWnd, WMBB_LOSEFOCUS, 0, 0);
          end;
        end;
      end;
      { if remote game, poll for i/o }
      {$IFNDEF nocomm}
      if (RS <> nil) and (Paused and pause_User = 0)
        {$IFDEF loopback} and (v_random(2) = 0){$ENDIF}
      then
        HandleComm;
      {$ENDIF}
      { wait for timer tick }
      {$IFNDEF oldtimer}
      if (Paused = 0) and TimerProcessed then begin
        TimerProcessed := false;
        ProcessTimerTick;
      end;
      {$ENDIF}
    until false;

  finally

    Cleanup;

  end;
end.
