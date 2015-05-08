uses
  Objects, Modem;

const
  Waits : array[0..1] of PChar = ('SPIFF','COOL');
var
  S : TModemStream;
begin
  S.Init(2);
  Writeln(S.WaitFor(Waits, nil));
  S.Done;
end.
