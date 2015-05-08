uses
  Objects, Modem;

const
  Waits : array[0..1] of PChar = ('SPIFF','COOL');
var
  S : TModemStream;
begin
  S.Init(3);
  Writeln(S.InS.Status:5, S.OutS.Status:5);
  S.WriteText('SPIFF');
  S.Done;
end.
