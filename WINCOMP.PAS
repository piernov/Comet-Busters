unit WinComp;

interface

{$IFDEF WIN32}
{$DEFINE WINDOWS}
{$ENDIF}

{$IFNDEF WINDOWS}
uses
  Dos;

type
  NativeStr = string;
const
  fsPathName      =  79;
  fsDirectory     =  67;
  fsFileName      =  8;
  fsExtension     =  4;
{$ELSE}
type
  PathStr = string[127];
  NativeStr = PChar;
{$ENDIF}

{$IFNDEF WINDOWS}
function wvsprintf(DestStr, Format: PChar; var ArgList): Integer;
function FileSearch(Dest, Name, List : PChar) : PChar;
{$ENDIF}

function StrFix(S : PChar) : NativeStr;
function StrPNew(const Source: String): PChar;
function StrPChar(const S : string) : PChar;

implementation

uses
  {$IFDEF WINDOWS}SysUtils{$ELSE}Strings{$ENDIF};

{$IFNDEF WINDOWS}
function wvsprintf(DestStr, Format: PChar; var ArgList): Integer; external;
{$L SPRINTF}

function FileSearch(Dest, Name, List : PChar) : PChar;
var
  P : PathStr;
  D : string;
begin
  P := StrPas(Name);
  D := StrPas(List);
  FileSearch := StrPCopy(Dest, FSearch(P, D));
end;
{$ENDIF}

function StrFix(S : PChar) : NativeStr;
begin
{$IFDEF WINDOWS}
  StrFix := S;
{$ELSE}
  StrFix := StrPas(S);
{$ENDIF}
end;

var
  buf : array[0..256] of char;
function StrPChar(const S : string) : PChar;
begin
  StrPCopy(buf, S);
  StrPChar := buf;
end;

function StrPNew(const Source: String): PChar;
var
  p : PChar;
begin
  if Source = '' then
    StrPNew := nil
  else begin
    GetMem(p, length(Source)+1);
    StrPNew := StrPCopy(p, Source);
  end;
end;

end.
