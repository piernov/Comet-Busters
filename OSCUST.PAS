
uses
  WinTypes, WInProcs;

function UserRegister(Wnd : HWnd; Str : PChar) : integer;
  far; external 'OSCUSTOM.DLL';

begin
  UserRegister(0, 'ste hugg');
end.

