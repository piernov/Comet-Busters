{$IFDEF WINDOWS}
uses
  WinCrt, MMSystem, Joystick, Objects;
{$ELSE}
uses
  Crt, Joystick, Objects;
{$ENDIF}

var
  n  :boolean;
  info : TJoyInfo;

begin
  writeln(getJoynumdevs);
  readln;
  repeat
    n := GetJoyPos(0, info);
    with info do begin
      Writeln('X: ',wXPos:5,'   Y: ',wYPos:5,'  button: ',wButtons);
    end;
  until KeyPressed;
end.
