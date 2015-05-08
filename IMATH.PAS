(*********************************************************)
(**  IMATH.PAS                                          **)
(**  Integer math routines                              **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit IMath;

interface

{$IFDEF WINDOWS}uses WinTypes;{$ENDIF}

const
  IntPi = 512;

{$IFNDEF WINDOWS}
type
  TPoint = record x,y : integer end;
{$ENDIF}

procedure MakeSinTbl;
function ISqrt(n : longint) : word;
function ISin(i : integer) : integer;
function ICos(i : integer) : integer;
function ITan(i : integer) : integer;
procedure IXChg(var n1, n2 : integer);
procedure IRotate(var P : TPoint; Rot : integer);
function ISqr(n : integer) : longint;
  inline($58/$F7/$E8); { POP AX; IMUL AX }
function IPwr(a : integer; exponent : integer) : longint;
function IInvLog2(a : longint) : integer;

function IMin(a,b : integer) : integer;
  inline($58/$5A/$3B/$C2/$7C/$01/$92); { POP DX; POP AX; CMP AX,DX; JL @+1; XCHG DX,AX }
function IMax(a,b : integer) : integer;
  inline($58/$5A/$3B/$C2/$7F/$01/$92); { POP DX; POP AX; CMP AX,DX; JG @+1; XCHG DX,AX }
function ISign(a : longint) : integer;

function Shr16(a : longint) : integer;
inline($58/$58);

function Shr8(a : longint) : integer;
{ divides the input by 256, a shift of 8 bits }
inline($58/     { POP AX }
       $5A/     { POP DX }
       $88/$E0/ { MOV AL,AH }
       $88/$D4  { MOV AH,DL }
);

function LongMulShr8(X,Y : integer) : integer;
{ multiplies X by Y, and shifts the result by 8 (divides by 256) }
inline(
$5A/$58/$f7/$EA/ { POP DX; POP AX; IMUL DX }
$88/$E0/$88/$D4  { MOV AL,AH; MOV AH,DL }
);

function LongMulShr16(X,Y : integer) : integer;
{ multiplies X by Y, and shifts the result by 8 (divides by 256) }
inline(
$5A/$58/$f7/$EA/ { POP DX; POP AX; IMUL DX }
$8B/$C2          { MOV AX,DX }
);

function MakeHigh(X : integer) : longint;
{ Puts an integer in the high-order word of a long integer. }
inline($5A/$31/$C0); { POP DX; XOR AX,AX }
function MakeHighByte(n : byte) : word;
{ Puts an byte in the high-order byte of a word. }
inline($58/$88/$C4/$B0/$00); { POP AX; MOV AH,AL; MOV AL,0 }

procedure SwapWord(var w : word);
procedure SwapLong(var l : longint);

function LongMul(X, Y: Integer): Longint;
inline($5A/$58/$F7/$EA);

function LongDiv(X: Longint; Y: Integer): Integer;
inline($59/$58/$5A/$F7/$F9);

implementation

var
  SinTbl : array[0..IntPi div 2-1] of integer; { 0..255 = 0..pi/2 }

procedure MakeSinTbl;
var i : integer;
begin
  for i := 0 to IntPi div 2-1 do
    SinTbl[i] := round(sin(i*(3.141592/IntPi))*32767);
end;

function ISin(i : integer) : integer;
const IntPid2 = IntPi*2-1;
begin
  i := i and IntPid2;
  case hi(i) of
    0 : ISin := SinTbl[lo(i)];
    1 : ISin := SinTbl[lo(not i)];
    2 : ISin := -SinTbl[lo(i)];
    3 : ISin := -SinTbl[lo(not i)];
  end;
end;

function ICos(i : integer) : integer;
begin
  ICos := ISin(i+256);
end;

function ITan(i : integer) : integer;
begin
  ITan := LongDiv(MakeHigh(ISin(i)), ICos(i));
end;

procedure IXChg(var n1, n2 : integer); assembler;
asm
  les  bx,n1
  mov  ax,word ptr [es:bx]
  les  bx,n2
  xchg ax,word ptr [es:bx]
end;

function MSB(a : longint) : byte; assembler;
asm
  xor  ax,ax
  mov  bx,word ptr [a]
  mov  cx,word ptr [a+2]
@@lp:
  mov  dx,bx
  or   dx,cx
  jz   @@done
  shr  cx,1
  rcr  bx,1
  inc  ax
  jmp  @@lp
@@done:
end;

function IPwr(a : integer; exponent : integer) : longint;
{$IFNDEF VER80}
var
  result : longint;
{$ENDIF}
begin
  result := 1;
  while (exponent > 0) do begin
    result := result*a;
    dec(exponent);
  end;
  {$IFNDEF VER80}IPwr := result;{$ENDIF}
end;

function IRoot(a : longint; root : integer) : word;
var
{$IFNDEF VER80}
  result : word;
{$ENDIF}
  bitpos : byte;
  mask,rem,cmpr : longint;
begin
  result := 1;
  bitpos := ((MSB(a)-1) div root) * root;
  mask := (1 shl root)-1;
  dec(a, longint(1) shl bitpos);
  rem := a shr bitpos;
  while (bitpos > 0) do begin
    dec(bitpos, root);
    rem := (rem shl root) + ((a shr bitpos) and mask);
    cmpr := IPwr(2*result+1, root)-IPwr(2*result, root);
    result := result shl 1;
    if rem >= cmpr then begin
      result := result or 1;
      rem := rem-cmpr;
    end;
  end;
{$IFNDEF VER80}
  IRoot := result;
{$ENDIF}
end;

function _ISqrt(n : longint) : word; external;
function _ISqrt2(n : longint) : word; external;
{$L ISQRT}

function ISqrt(n : longint) : word;
begin
  if Test8086 >= 2 then
    ISqrt := _ISqrt2(n)
  else
    ISqrt := IRoot(n, 2);
end;

procedure IRotate(var P : TPoint; Rot : integer);
var X2 : integer;
begin
  X2 := LongMulShr16(P.X, ICos(Rot))+LongMulShr16(P.Y, ISin(Rot));
  P.Y := LongMulShr16(P.X, ISin(Rot))-LongMulShr16(P.Y, ICos(Rot));
  P.X := X2;
end;

function IInvLog2(a : longint) : integer;
var
  l : integer;
begin
  if a >= 0 then begin
    l := 0;
    while a <> 0 do begin
      a := a shr 1;
      inc(l);
    end;
  end else begin
    l := 0;
  end;
  IInvLog2 := l;
end;

function ISign(a : longint) : integer;
begin
  if a >= 0 then begin
    if a = 0 then ISign := 0
    else ISign := 1
  end else
    ISign := -1;
end;

procedure SwapWord(var w : word);
begin
  w := Swap(w);
end;

procedure SwapLong(var l : longint); assembler;
asm
  push ds
  lds  bx,l
  mov  al,byte ptr [bx]
  xchg byte ptr [bx+3],al
  mov  byte ptr [bx],al
  mov  al,byte ptr [bx+1]
  xchg byte ptr [bx+2],al
  mov  byte ptr [bx+1],al
  pop  ds
end;

end.
