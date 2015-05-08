uses Objects, WinTypes, WinProcs, GameLib, Modem, WinCrt;

function IdleWaitFunc : boolean; far;
begin
  WaitMessage;
  IdleWaitFunc := false;
end;

var
  S : TModemStream;
  cout, cin : char;
  DCB : TDCB;
begin
  S.Init(3, nil);
  S.SetParams('COM1:2400,N,8,1');
{  GetCommState(S.Handle, DCB);
  SetCommBreak(S.Handle);
  ClearCommBreak(S.Handle);
{  DCB.Handle := S.Handle;}
{Writeln(DCB.id,' ',S.Handle,' ',DCB.Baudrate,' ',DCB.Flags,' ',DCB.DSRTIMEOUT);
  Writeln(sprintf('Flags :%x', DCB.Flags));
  DCB.Flags := $1{ or $10 or $4000};
{  DCB.RlsTimeout := 1000;
  DCB.CtsTimeout := 1000;
{  SetCommState(DCB);{}
  S.WriteTextSlowly('atz'#13, 100);
  repeat
    if S.Status <> stok then begin
      MessageBox(0, sprintf('Status: %d Info: %d', S.Status), '',MB_OK);
      Break;
    end;
    if KeyPressed then begin
      cout := ReadKey;
      if cout = #27 then Break;
      S.Write(cout, 1);
      Write(cout);
    end;
    if S.ReadAsync(cin, 1) > 0 then
      Write(cin);
  until false;
  S.Done;
end.
