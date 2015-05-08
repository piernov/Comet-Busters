uses
  Objects, WinTypes, WinProcs, WinCrt, Modem, Strings;

const
  ATcmd : PChar = 'ATZ'#13;
  Atcmd2 : PChar = 'ATDT5745911'#13;
var
  S : TModemStream;
  Buf : array[0..255] of char;
var
  DCB : TDCB;


procedure Wait;
const
  Cmds : array[0..2] of PChar = ('OKAY','OK','ERROR');

  function Action : boolean; far;
  begin
    Action := KeyPressed;
  end;

begin
  Writeln('wait: ',S.WaitFor(Cmds, @Action));
end;

begin
  repeat
    readln(Buf);
    Writeln(BuildCommDCB(Buf, DCB));
  until Buf[0] = #0;
  halt;
  S.Init(3);
  S.Write(Atcmd^, 4);
  Writeln(s.status:5,s.errorinfo:5);
{  S.WriteText(ATcmd);}
  Writeln(S.Status:5);
  Wait;
  Writeln(S.Status:5);
  S.Done;
end.
