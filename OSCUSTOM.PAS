library OSCustom;

uses
  SysUtils, WinTypes, WinProcs;

function GetChkSum(var A; Size : word) : word; assembler;
asm
  les  bx,A
  xor  ax,ax
  mov  cx,Size
  stc
@@1:
  sbb  al,es:[bx]
  {$IFOPT G+}
  rcl  ax,3
  {$ELSE}
  rcl ax,1
  rcl ax,1
  rcl ax,1
  {$ENDIF}
  inc  bx
  loop @@1
end;

function UserRegister(Wnd : HWnd; Str : PChar) : integer; export;
var
  ChkSum : word;
  Username : PChar;
  INIFile : PChar;
  buf : array[0..16] of char;
begin
  Result := 0;

{  MessageBox(0, Str, nil, MB_ICONEXCLAMATION or MB_SYSTEMMODAL);}

  INIFile := Str;
  Username := StrScan(Str, '*');
  if Username = nil then Exit;
  Username^ := #0;
  inc(Username);

{  MessageBox(0, INIFile, nil, MB_ICONEXCLAMATION or MB_SYSTEMMODAL);
  MessageBox(0, Username, nil, MB_ICONEXCLAMATION or MB_SYSTEMMODAL);}
(*
  INIFile := '.\COMET.INI';
  Username := Str;
*)
  ChkSum := GetChkSum(Username^, StrLen(Username));
  WritePrivateProfileString('Registration', 'UserName', Username, INIFile);
  wvsprintf(buf, '%d', ChkSum);
  WritePrivateProfileString('Registration', 'ID', Buf, INIFile);

  Result := 1;
end;

exports
  UserRegister resident;

begin
end.

