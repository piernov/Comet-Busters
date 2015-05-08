uses WinCrt, KeyWnd, WinTypes, WinProcs;

var
  s : array[0..79] of char;

begin
  repeat
    Write('Enter key name: ');
    Readln(s);
    if s = '' then Halt;
    Writeln('Code is ',GetKeyCodeFromName(s));
    GetKeyNameText(longint(GetKeyCodeFromName(s)) shl 16, s, Sizeof(s));
    Writeln('Key name is ',s);
  until false;
end.
