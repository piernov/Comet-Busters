unit WaveMix;

interface

uses
  WinTypes;

{$IFNDEF NOWMIXSTR}
type
  PMIXWAVE = pointer;
{$ENDIF}

(* flag values for play params *)
const
  WMIX_QUEUEWAVE                          = $00;
  WMIX_CLEARQUEUE                         = $01;
  WMIX_USELRUCHANNEL                      = $02;
  WMIX_HIPRIORITY                         = $04;
  WMIX_WAIT                               = $08;
type
  PMixPlayParams = ^TMixPlayParams;
  TMixPlayParams = record
    wSize : word;
    hMixSession : THandle;
    iChannel : smallint;
    lpMixWave : PMIXWAVE;
    hWndNotify : HWnd;
    dwFlags : longint;
    wLoops : word;
  end;

  PWaveMixInfo = ^TWaveMixInfo;
  TWaveMixInfo = record
    wSize : word;
    bVersionMajor : byte;
    bVersionMinor : byte;
    szDate : array[0..11] of char;
    dwFormats : longint;
  end;

const
  WMIX_CONFIG_CHANNELS          = 1;
  WMIX_CONFIG_SAMPLINGRATE      = 2;

type
  PMixConfig = ^TMixConfig;
  TMixConfig = record
    wSize : word;
    dwFlags : longint;
    wChannels : word;
    wSamplingRate : word;
  end;

function WaveMixGetInfo(var Info : TWAVEMIXINFO) : word;

(* return same errors as waveOutOpen, waveOutWrite, and waveOutClose *)
function WaveMixInit : THandle;
function WaveMixConfigureInit(var Config : TMIXCONFIG) : THandle;
function WaveMixActivate(hMixSession : THandle; fActivate : Bool) : integer;

const
  WMIX_FILE                               = $0001;
  WMIX_RESOURCE                           = $0002;

function WaveMixOpenWave(hMixSession : THandle; szWaveFilename : PChar;
  hInst : THandle; dwFlags : longint) : PMIXWAVE;

const
  WMIX_OPENSINGLE                         = 0;
  WMIX_OPENALL                            = 1;
  WMIX_OPENCOUNT                          = 2;

function WaveMixOpenChannel(hMixSession : THandle; iChannel : integer;
  dwFlags : longint) : integer;

function WaveMixPlay(var MixPlayParams : TMIXPLAYPARAMS) : integer;

const
  WMIX_ALL                                = $0001;
  WMIX_NOREMIX                            = $0002;

function WaveMixFlushChannel(hMixSession : THandle; iChannel : integer; dwFlags : longint) : integer;
function WaveMixCloseChannel(hMixSession : THandle; iChannel : integer; dwFlags : longint) : integer;

function WaveMixFreeWave(HMixSession : THandle; MixWave : PMIXWAVE) : integer;
function WaveMixCloseSession(hMixSession : THandle) : integer;
procedure WaveMixPump;

implementation

const
{$IFDEF WIN32}
  uwavemix = 'WAVMIX32';
{$ELSE}
  uwavemix = 'WAVMIX16';
{$ENDIF}

function WaveMixGetInfo; external uwavemix;
function WaveMixInit; external uwavemix;
function WaveMixConfigureInit; external uwavemix;
function WaveMixActivate; external uwavemix;
function WaveMixOpenWave; external uwavemix;
function WaveMixOpenChannel; external uwavemix;
function WaveMixPlay; external uwavemix;
function WaveMixFlushChannel; external uwavemix;
function WaveMixCloseChannel; external uwavemix;
function WaveMixFreeWave; external uwavemix;
function WaveMixCloseSession; external uwavemix;
procedure WaveMixPump; external uwavemix;


end.
