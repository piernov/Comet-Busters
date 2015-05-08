
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

var
  UserName : String;
  ChkSum : word;
begin
  Write('Username:');
  Readln(UserName);
  Writeln('[Registration]');
  ChkSum := GetChkSum(UserName[1], length(UserName));
  Writeln('UserName=',UserName);
  Writeln('ID=',ChkSum);
end.
