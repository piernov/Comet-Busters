program SpkrTst;

uses
  WinCrt, GameSnd;

var
  dur, df, f, dl, l : integer;
  noise : TNoise;

begin
  if InitSpkrSound(512) then begin
    repeat
      Write('fq, dfq, fl, dfl, dur?');
      Readln(dur,df,f,dl,l);
      if dur = 0 then break;
      noise.Init(dur, df, f, dl, l);
      noise.Play;
    until false;
    DoneSpkrSound;
  end;
end.
