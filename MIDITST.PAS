program MidiTst;

uses MMSystem, WinCrt, WinTypes, WinProcs, GameSnd;

var
  Wnd : HWnd;

function ChkErr(Error : integer) : boolean;
var
 Buf : array[0..1023] of char;
begin
  if Error <> 0 then begin
    mciGetErrorString(Error, Buf, sizeof(Buf));
    Writeln(Buf);
  end else
    ChkErr := true;
end;

begin
  Wnd := GetDesktopWindow;
  Writeln(InitMidiSound(Wnd, 'c:\windows\midi\taxi.mid'));
  Writeln(PlayMidiFile(Wnd));
  readln;
  ChkErr(SetMIDITempo(Wnd, 30));
  readln;
  Writeln(DoneMidiSound);
end.
