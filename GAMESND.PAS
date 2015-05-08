(*********************************************************)
(**  GAMESND.PAS                                        **)
(**  Sound-handling objects - req. SNDLIB.DLL           **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit GameSnd;
{$C FIXED PRELOAD PERMANENT}
{$R-}

interface

uses
  {$IFDEF debugsnd}WinCrt, {$ENDIF}WinTypes, WinProcs, Objects, Win31, WaveMix, MMSystem;

const
  HWave : THandle = 0;
  NumMixChan : word = 4;

  SpkrSoundOn : word = 0; { each of these represents the number of }
  MidiSoundOn : word = 0;

function InitWaveSound(Wnd : HWnd; Formats, Support : longint; Sync : boolean) : boolean;
procedure DoneWaveSound;
function PlayWaveSound(Priorty : word; Data : pointer; Loops : word) : integer;
procedure PauseWaveSound(Pause : boolean);
procedure CloseWaveChannels;
procedure PumpWaveSound;

function GetMIDINumDevs : integer;
function InitMIDISound(Wnd : HWnd; FileName : PChar) : integer;
function PlayMIDIFile : integer;
function PauseMIDI : integer;
function ResumeMIDI : integer;
function RestartMIDI : integer;
function SetMIDITempo(Tempo : longint) : integer;
function DoneMIDISound : integer;

{$IFNDEF win32}
function InitSpkrSound(MaxNotes : integer) : boolean;
procedure DoneSpkrSound;
function PlaySpkrNoise(fq, dfq, fl, dfl, dur : integer) : boolean;
{$ENDIF}

type
  { generic sound object }
  PSound = ^TSound;
  TSound = object(TObject)
    constructor Init;
    function Play : boolean; virtual;
    function ChangePitch(Amt : word) : boolean; virtual;
  end;

  {$IFNDEF win32}
  { speaker sound object }
  PNoise = ^TNoise;
  TNoise = object(TSound)
    Freq, DFreq, Filter, DFilter, Duration : integer;
    constructor Init(frq, dfrq, filt, dfilt, dur : integer);
    function Play : boolean; virtual;
  end;
  {$ENDIF}

  { wave sound object }
  PWave = ^TWave;
  TWave = object(TSound)
    Data : PMixWave;
    Priority : byte;
    NumLoops : word;

    constructor LoadRes(Instance : THandle; Name : PChar; APriority : byte);
    destructor Done; virtual;
    function Play : boolean; virtual;
    function ChangePitch(Amt : word) : boolean; virtual;
    function StartLoop : word;
  end;

procedure DoneWaveChannel(Chan : integer);
procedure StopWaveID(WaveId : word);
function IsPlayingID(WaveId : word) : boolean;

implementation

uses
  GameLib;

constructor TSound.Init;
begin end;

function TSound.Play : boolean;
begin Play := true; end;

function TSound.ChangePitch(Amt : word) : boolean;
begin ChangePitch := false end;

{$IFNDEF win32}
constructor TNoise.Init(frq, dfrq, filt, dfilt, dur : integer);
begin
  Freq := frq; DFreq := dfrq;
  Filter := filt; DFilter := dfilt;
  Duration := dur;
end;

function TNoise.Play : boolean;
begin
  Play := PlaySpkrNoise(Freq, DFreq, Filter, DFilter, Duration);
end;
{$ENDIF}

constructor TWave.LoadRes(Instance : THandle; Name : PChar; APriority : byte);
type LongPtr = ^longint;
var Resinfo : THandle;
begin
  NumLoops := 0;
  Data := WaveMixOpenWave(HWave, Name, Instance, WMIX_RESOURCE);
  if Data <> nil then begin
    Priority := APriority;
  end else
    Fail;
end;

destructor TWave.Done;
begin
  WaveMixFreeWave(HWave, Data);
end;

function TWave.Play : boolean;
begin
  Play := PlayWaveSound(Priority, PChar(Data), NumLoops) > 0;
end;

function TWave.ChangePitch(Amt : word) : boolean;
begin
  Result := false;
(*
  with PWaveFormat(Ptr(PtrRec(Data).Seg, PtrRec(Data).Ofs+$14))^ do begin
    nSamplesPerSec := (OrigPitch*Amt) shr 8;
    nAvgBytesPerSec := nSamplesPerSec;
  end;
*)
end;

{
function InitSoundSystem : boolean; external 'SNDLIB' index 1;
procedure DoneSoundSystem; external 'SNDLIB' index 2;
}
var
  NotifyWnd : HWnd;
  ChannelRec : array[0..7] of record
    lpWave : pointer;
    Priority : integer;
    id : word;
  end;
  WaveActivated : boolean;

const
  cursndid : word = 1;

function TWave.StartLoop : word;
var
  chan : integer;
begin
  chan := PlayWaveSound(Priority, PChar(Data), $FFFF);
  StartLoop := ChannelRec[chan].id;
end;

procedure StopWaveID(WaveId : word);
var
  i : integer;
begin
  if WaveId <> 0 then begin
    for i := 0 to NumMixChan-1 do with ChannelRec[i] do begin
      if (WaveId = id) then begin
        WaveMixFlushChannel(HWave, i, 0);
        DoneWaveChannel(i);
      end;
    end;
  end;
end;

function IsPlayingID(WaveId : word) : boolean;
var
  i : integer;
begin
  IsPlayingId := false;
  if WaveId <> 0 then begin
    for i := 0 to NumMixChan-1 do with ChannelRec[i] do begin
      if (WaveId = id) then begin
        IsPlayingId := true;
        Exit;
      end;
    end;
  end;
end;

function InitWaveSound;
begin
  InitWaveSound := false;
  WaveActivated := false;
  if HWave <> 0 then Exit;
  HWave := WaveMixInit;
  InitWaveSound := (HWave <> 0) and (WaveMixOpenChannel(HWave, NumMixChan, WMIX_OPENCOUNT) = 0);
  NotifyWnd := Wnd;
  FillChar(ChannelRec, sizeof(ChannelRec), 0);
end;

procedure DoneWaveSound;
begin
  if HWave <> 0 then begin
    WaveMixActivate(HWave, False);
    WaveMixCloseChannel(HWave, 0, WMIX_ALL);
    WaveMixCloseSession(HWave);
  end;
end;

procedure PumpWaveSound;
begin
  if HWave <> 0 then WaveMixPump;
end;

{$IFDEF debugsnd}
procedure PrintWaves;
var
  i : integer;
begin
  for i := 0 to NumMixChan-1 do with ChannelRec[i] do begin
    Write(Priority:4);
  end;
  Writeln;
end;
{$ENDIF}

procedure DoneWaveChannel(Chan : integer);
begin
  with ChannelRec[Chan] do begin
    Priority := 0;
    lpWave := nil;
    id := 0;
  end;
end;

function FindLRUChannel(Priority : integer; Data : pointer) : integer;
var
  i,j,chan,best : integer;
begin
  chan := -1;
  best := 32767;
  for i := 0 to NumMixChan-1 do begin
    j := ChannelRec[i].Priority;
    if (j < Priority) and (j < best) then begin
      best := j;
      chan := i;
    end;
    if (j = Priority) and (best > priority) then begin
      chan := i;
    end;
  end;
  FindLRUChannel := chan;
end;

function PlayWaveSound(Priorty : word; Data : pointer; Loops : word) : integer;
var
  Params : TMixPlayParams;
begin
  PlayWaveSound := -1;
  if not WaveActivated then Exit;
  with Params do begin
    iChannel := FindLRUChannel(Priorty, Data);
    if iChannel < 0 then Exit;
    wSize := Sizeof(Params);
    hMixSession := HWave;
    lpMixWave := Data;
    hWndNotify := NotifyWnd;
    dwFlags := WMIX_CLEARQUEUE or WMIX_HIPRIORITY{ or WMIX_USELRUCHANNEL};
    wLoops := Loops;
  end;
  if WaveMixPlay(Params) = 0 then
    with ChannelRec[Params.iChannel] do begin
      Priority := Priorty;
      lpWave := Data;
      id := cursndid;
    end;
  inc(cursndid);
  if cursndid = 0 then cursndid := 1;
  PlayWaveSound := Params.iChannel;
  {$IFDEF debugsnd}
  PrintWaves;
  {$ENDIF}
end;

procedure CloseWaveChannels;
begin
  if HWave <> 0 then begin
    WaveMixActivate(HWave, False);
    WaveMixCloseChannel(HWave, 0, WMIX_ALL);
  end;
end;

procedure PauseWaveSound(Pause : boolean);
begin
  if HWave <> 0 then begin
    WaveMixActivate(HWave, not Pause);
    WaveActivated := not Pause;
  end;
end;

{$IFNDEF win32}
var
  NumSpkrVoices : integer;

function InitSpkrSound(MaxNotes : integer) : boolean; 
begin
  if SpkrSoundOn = 0 then begin
    NumSpkrVoices := OpenSound;
    if (NumSpkrVoices > 0) and
     (SetVoiceQueueSize(1, (192 div 32)*MaxNotes) = 0) then
      inc(SpkrSoundOn);
  end else
    inc(SpkrSoundOn);
  InitSpkrSound := SpkrSoundOn <> 0;
end;

procedure DoneSpkrSound; 
begin
  if SpkrSoundOn = 0 then Exit;
  dec(SpkrSoundOn);
  if SpkrSoundOn = 0 then begin
    CloseSound;
  end;
end;

function PlaySpkrNoise(fq, dfq, fl, dfl, dur : integer) : boolean; 
var
  res,
  f,
  rs : longint;
begin
  if SpkrSoundOn = 0 then begin
    PlaySpkrNoise := false;
    Exit;
  end;
  rs := RandSeed;
  StopSound;
  LongRec(f).lo := 0;
  repeat
    LongRec(f).hi := fq+v_random(fl);
    res := SetVoiceSound(1, f, 1);
    inc(fq, dfq);
    inc(fl, dfl);
    dec(dur);
  until (dur <= 0) or (res = s_SerQFUL);
  RandSeed := rs;
  PlaySpkrNoise := (StartSound = 0);
end;
{$ENDIF}

var
  HMidi : word;
  MidiWnd : HWnd;

function InitMIDISound(Wnd : HWnd; FileName : PChar) : integer; 
var
  Parms : TMCI_OPEN_PARMS;
begin
  Parms.dwCallBack := Wnd;
  MidiWnd := Wnd;
  LongRec(Parms.lpstrDeviceType).Lo := mci_DevType_Sequencer;
  LongRec(Parms.lpstrDeviceType).Hi := 0;
  Parms.lpstrElementName := FileName;
  InitMIDISound :=
    mciSendCommand(0, MCI_OPEN, MCI_OPEN_TYPE_ID OR MCI_OPEN_ELEMENT,
    longint(@Parms));
  HMidi := Parms.wDeviceID;
end;

function LoadMIDIFile(FileName : PChar) : integer; 
var
  Parms : TMCI_LOAD_PARMS;
begin
  if HMidi = 0 then begin LoadMidiFile := -1; Exit end;
  Parms.dwCallBack := MidiWnd;
  Parms.lpfilename := FileName;
  LoadMIDIFile :=
    mciSendCommand(hMidi, MCI_LOAD, MCI_LOAD_FILE or MCI_WAIT,
    longint(@Parms));
end;

function PlayMIDIFile : integer; 
var
  Parms : TMCI_PLAY_PARMS;
begin
  if HMidi = 0 then begin PlayMidiFile := -1; Exit end;
  Parms.dwCallBack := MidiWnd;
  PlayMIDIFile :=
    mciSendCommand(hMidi, MCI_PLAY, MCI_NOTIFY,  longint(@Parms));
end;

function PauseMIDI : integer; 
var
  Parms : TMCI_GENERIC_PARMS;
begin
  if HMidi = 0 then begin PauseMidi := -1; Exit end;
  Parms.dwCallBack := MidiWnd;
  PauseMIDI :=
    mciSendCommand(hMidi, MCI_PAUSE, MCI_NOTIFY,  longint(@Parms));
end;

function ResumeMIDI : integer; 
var
  Parms : TMCI_GENERIC_PARMS;
begin
  if HMidi = 0 then begin ResumeMidi := -1; Exit end;
  Parms.dwCallBack := MidiWnd;
  ResumeMIDI :=
    mciSendCommand(hMidi, MCI_RESUME, MCI_NOTIFY,  longint(@Parms));
end;

function RestartMIDI : integer; 
var
  Parms : TMCI_SEEK_PARMS;
begin
  if HMidi = 0 then begin RestartMidi := -1; Exit end;
  Parms.dwCallBack := MidiWnd;
  Parms.dwTo := 0;
  RestartMIDI :=
    mciSendCommand(hMidi, MCI_RESUME, MCI_TO,  longint(@Parms));
end;

function SetMIDITempo(Tempo : longint) : integer; 
var
  Parms : TMCI_SEQ_SET_PARMS;
begin
  if HMidi = 0 then begin SetMidiTempo := -1; Exit end;
  Parms.dwCallBack := MidiWnd;
  Parms.dwTimeFormat := mci_format_SMPTE_30;
  Parms.dwTempo := Tempo;
  SetMidiTempo :=
    mciSendCommand(hMidi, MCI_SET, MCI_NOTIFY or MCI_WAIT or MCI_SET_TIME_FORMAT,
      longint(@Parms));
end;

function DoneMIDISound : integer; 
var
  Parms : TMCI_GENERIC_PARMS;
begin
  if HMidi = 0 then begin DoneMidiSound := -1; Exit end;
  Parms.dwCallBack := 0;
  DoneMidiSound :=
    mciSendCommand(hMidi, MCI_CLOSE, MCI_WAIT, longint(@Parms));
end;

function GetMIDINumDevs : integer; 
var
  Parms : TMCI_SYSINFO_PARMS;
  num : longint;
begin
  Parms.dwCallBack := 0;
  Parms.lpstrReturn := PChar(@num);
  Parms.wDeviceType := mci_DevType_Sequencer;

  if mciSendCommand(0, MCI_SYSINFO, MCI_SYSINFO_QUANTITY, longint(@Parms)) = 0
    then GetMIDINumDevs := num
    else GetMIDINumDevs := 0;
end;

end.
