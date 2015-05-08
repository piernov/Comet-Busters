program SndTest;

uses
  WinCrt, WinTypes, GameSnd, WaveMix;

var
  tw : THandle;
  w1 : pointer;
  config : TMixConfig;
  Params : TMixPlayParams;

begin
  config.wSize := sizeof(TMIXCONFIG);
  config.dwFlags := WMIX_CONFIG_CHANNELS;
  config.wChannels := 2;
  tw := WaveMixConfigureInit(config);
  Writeln('init: ',tw);


  w1 := WaveMixOpenWave(tw, 'd:\windows\asteroid\beat1.wav', 0, 0);
  Writeln(longint(w1));

  Writeln('Opench:' ,WaveMixOpenChannel(tw, 8, WMIX_OPENCOUNT));
  Writeln('Activate: ', WaveMixActivate(tw, True));

  FillChar(Params, sizeof(Params), 0);
  with Params do begin
    wSize := Sizeof(Params);
    hMixSession := tw;
    iChannel := 1;
    lpMixWave := w1;
    hWndNotify := 0;
    dwFlags := WMIX_CLEARQUEUE or WMIX_HIPRIORITY;
    wLoops := 0;
  end;
  Writeln('Play: ', WaveMixPlay(Params));

  readln;

  Writeln('freech: ', WaveMixCloseChannel(tw, 0, WMIX_ALL));
  Writeln('close: ',WaveMixCloseSession(tw));
end.
