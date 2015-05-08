(*********************************************************)
(**  GAMELIB.PAS                                        **)
(**  Common handy functions                             **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit GameLib;

interface

uses
  WinTypes, Messages, WinProcs, Objects, SysUtils;

{ Additional string functions }
function sprintf(Format : PChar; var ArgList) : PChar;
function sscanf(Input, Format : PChar; var ArgList) : PChar;

function StrToken(Dest, Src : PChar; MaxSize : word; Delim : Char) : PChar;
{ extracts a token delimited by Delim up to MaxSize characters and copies
  it to Dest }

function LoadStr(ID : word) : PChar;
{ Loads the string resource from ID into an internal buffer and returns a
  pointer to it. }

procedure FatalError(StrID, TxtType : word);
{ puts the string specified by ID into its own internal buffer and
  returns a pointer to it -- trouble is you can only have one of these
  in the buffer at a time }

function WhichRadioButtonChecked(Dlg: HWnd; IDFirstButton,
  IDLastButton : Integer) : integer;
{ looks at the radio buttons in a specified range and if one is
  checked, returns its ID, otherwise returns 0 }

function GetWindowInt(Wnd : HWnd; Default : longint) : longint;
{ parses an integer from the window text of Wnd; returns Default if cannot }

function GetChkSum(var A; Size : cardinal) : word;
{ returns the simple checksum of object A with size Size }

procedure CenterWindow(Wnd : HWnd; R : PRect);
{ Centers the window Wnd in the rectangle R.
  If R = nil, centers in middle of screen }

function DialogBoxLib(Instance, DlgLib : THandle; TemplateName : PChar;
  WndParent : HWnd; DialogFunc : TFarProc) : integer;
{ ummm... what does this do? Oh yeah, this is like the DialogBox
  function in the API except the dialog box template can reside in a
  DLL. Nice of Microsoft to forget this function. }

procedure ShowSplashScreen(var R: TRect; Instance : THandle;
  BitmapName, Message : PChar; MsgColor : TColorRef);
{ Displays a bitmap on the main display DC which is a resource
  in library Instance with name BitmapName. Also can place
  a message in the upper-left corner of the rectangle defined by
  Message with color MsgColor. }

function PaletteCreate(Colors : array of TColorRef;
  NumCols : integer) : HPalette;
function CreatePaletteOf(Info : PBitmapInfo) : HPalette;
function CreatePaletteOfBMP(Info : PBitmapInfo) : HPalette;
function CreateGreyPalette(NumGreys : integer) : HPalette;
function CreateColorCube(rn, bn, gn : integer) : HPalette;
function CreateSystemPalette : HPalette;

function GetINIFileName : PChar;
{ this function returns the full path to the program's .INI file
  in the same directory as the running program. }

function v_random(a : longint) : longint;
{ gives you a secondary random number generator }

function GetRandomFile(FileSpec : PChar) : PChar;

var
  HStrLib : THandle; { handle of library containing strings }

implementation

procedure FatalError(StrID, TxtType : word);
var Buf : array[0..255] of char;
begin
  if LoadString(HStrLib, StrID, Buf, sizeof(Buf)) = 0 then
    StrCopy(Buf, 'Fatal error. Exiting program.');
  MessageBeep(TxtType);
  MessageBox(0, Buf, 'Fatal error', TxtType or MB_SYSTEMMODAL);
  Halt;
end;

var sprintbuf,stringbuf : array[0..1023] of char;
function sprintf(Format : PChar; var ArgList) : PChar;
begin
  wvsprintf(sprintbuf, Format, {$IFDEF WIN32}@{$ENDIF}ArgList);
  sprintf := sprintbuf;
end;

function LoadStr(ID : word) : PChar;
begin
  if LoadString(HStrLib, ID, stringbuf, sizeof(stringbuf)) = 0 then
    stringbuf[0] := #0;
  LoadStr := stringbuf;
end;

function sscanf(Input, Format : PChar; var ArgList) : PChar;
type
  WordPtr = ^word;
  LongPtr = ^longint;
  PCharPtr = ^PChar;
var
  DelimPos : PChar;
  ArgPtr : PChar;
  n : longint;
  FmtCmd : char;
  code : integer;
  LongCmd : boolean;
  LenStr : string[8];
  MaxLen : integer;
begin
  sscanf := nil;
  ArgPtr := addr(ArgList);
  if (Format = nil) then
    Exit;
  while (Format^ <> #0) do
  begin
    if (Input = nil) or (Input^ = #0) then
      Exit; { ***ERROR }
    if Format^ = '%' then
    begin
      inc(Format);
      FmtCmd := Format^;

      if FmtCmd in ['0'..'9'] then
      begin
        LenStr := '';
        repeat
          LenStr := LenStr + FmtCmd;
          inc(Format);
          FmtCmd := Format^;
        until not (FmtCmd in ['0'..'9']);
        if LenStr <> '' then begin
          Val(LenStr, MaxLen, code);
          if code <> 0 then Exit;
        end;
      end else
        MaxLen := $7FFF;

      if FmtCmd = 'l' then
      begin
        LongCmd := true;
        inc(Format);
        FmtCmd := Format^;
      end else
        LongCmd := false;

      case FmtCmd of
        'c' : begin
          ArgPtr^ := Input^;
          inc(ArgPtr, 2);
        end;
        'd','i','u','s','*' : begin
          { look for delimiter }
          DelimPos := StrScan(Input, (Format+1)^);
          if DelimPos <> nil then begin
            if (DelimPos-Input > MaxLen) then Exit;
            DelimPos^ := #0; { zero delimiter }
          end;

          if FmtCmd = 's' then begin
            if PCharPtr(ArgPtr)^ = nil then { if dest. string is NIL }
              PCharPtr(ArgPtr)^ := StrNew(Input) { then allocate a new one }
            else
              StrCopy(PCharPtr(ArgPtr)^, Input); { else copy to dest buffer }
          end else
            if FmtCmd <> '*' then
              Val(Input, n, code);

          if DelimPos <> nil then DelimPos^ := (Format+1)^; { set it back }
          case FmtCmd of
            's' : inc(ArgPtr, 4);
            '*' : ; { dummy }
          else
            if code <> 0 then Exit; { could not convert }
            if LongCmd then begin
              LongPtr(ArgPtr)^ := n;
              inc(ArgPtr, 4);
            end else begin
              WordPtr(ArgPtr)^ := LongRec(n).Lo;
              inc(ArgPtr, 2);
            end;
          end;
          Input := DelimPos; { move input pointer to delimiter }
        end;
      else
        Exit;
      end;
      inc(Format);
    end else begin
      if Input^ <> Format^ then Exit;
      inc(Format);
      inc(Input);
    end;
  end;
  sscanf := Input;
end;

function WhichRadioButtonChecked(Dlg: HWnd; IDFirstButton,
  IDLastButton : Integer) : integer;
var
  id : integer;
begin
  id := IDFirstButton;
  while (id <= IDLastButton) do
  begin
    if SendDlgItemMessage(Dlg, id, BM_GETCHECK, 0, 0) > 0 then
    begin
      WhichRadioButtonChecked := id;
      Exit;
    end;
    inc(id);
  end;
  WhichRadioButtonChecked := IDFirstButton;
end;

function GetWindowInt(Wnd : HWnd; Default : longint) : longint;
var
  buf : array[0..15] of char;
  a : longint;
  code : integer;
begin
  GetWindowInt := Default;
  if GetWindowText(Wnd, buf, sizeof(buf)) > 0 then
  begin
    Val(buf, a, code);
    if code = 0 then
      GetWindowInt := a;
  end;
end;

procedure CenterWindow(Wnd : HWnd; R : PRect);
var WR : TRect;
    Scrn : TRect;
begin
  GetWindowRect(Wnd, WR);
  if R = nil then begin
    GetWindowRect(GetDesktopWindow, Scrn);
    R := @Scrn;
  end;
  { Center R in R2 : (ScreenX-R.right+R.left)/2}
  with R^ do begin
    MoveWindow(Wnd, (right+left-WR.right+WR.left) div 2,
      (bottom+top-WR.bottom+WR.top) div 2, WR.right-WR.left,
      WR.bottom-WR.top, false);
  end;
end;

function StrToken(Dest, Src : PChar; MaxSize : word; Delim : Char) : PChar;
{$IFNDEF WIN32}
assembler;
asm
  push ds
  mov  ah,Delim
  lds  si,Src
  les  di,Dest
  xor  cx,cx
@@1:
  lodsb
  or   al,al
  je   @@strend
  cmp  al,ah
  je   @@done
  inc  cx
  cmp  cx,MaxSize
  ja   @@1
  stosb
  jmp  @@1
@@strend:
  stosb
  xor  ax,ax
  xor  dx,dx
@@done:
  mov  al,0
  stosb
  mov  dx,ds
  mov  ax,si
  pop  ds
end;
{$ELSE}
begin
end;
{$ENDIF}

function GetChkSum(var A; Size : cardinal) : word;
{$IFNDEF WIN32}
assembler; asm
  les  bx,A
  xor  ax,ax
  mov  cx,Size
  stc
@@1:
  sbb  al,es:[bx]
  rcl  ax,3
  inc  bx
  loop @@1
end;
{$ELSE}
assembler; asm
  mov  ebx,A
  xor  eax,eax
  mov  ecx,Size
  stc
@@1:
  sbb  al,[ebx]
  rcl  ax,3
  inc  ebx
  loop @@1
end;
{$ENDIF}

function PaletteCreate(Colors : array of TColorRef; NumCols : integer)
  : HPalette;
var
  LogPal : record
    palVersion: Word;
    palNumEntries: Word;
    palPalEntry: array[0..255] of TPaletteEntry;
  end;
  i : integer;
begin
  with LogPal do begin
     palVersion := $300;
    palNumEntries := NumCols;
    for i := 0 to NumCols-1 do begin
      palPalEntry[i] := TPaletteEntry(Colors[i]);
    end;
  end;
  PaletteCreate := CreatePalette(PLogPalette(@LogPal)^);
end;

function CreateGreyPalette(NumGreys : integer) : HPalette;
var
  cols : array[0..255] of TColorRef;
  i : word;
  a : byte;
begin
  Result := 0;
  if NumGreys > 256 then Exit;
  for i := 0 to NumGreys-1 do begin
    a := i*255 div NumGreys;
    cols[i] := RGB(a,a,a);
  end;
  Result := PaletteCreate(Cols, NumGreys);
end;

function CreateColorCube(rn, bn, gn : integer) : HPalette;
var
  cols : array[0..255] of TColorRef;
  ncols : integer;
  i,ri,bi,gi : word;
begin
  Result := 0;
  ncols := rn*bn*gn;
  if ncols > 256 then Exit;
  i := 0;
  for ri := 0 to rn-1 do
    for bi := 0 to bn-1 do
      for gi := 0 to gn-1 do begin
        cols[i] := RGB(
          ri*255 div (rn-1), gi*255 div (gn-1), bi*255 div (bn-1)
        );
        inc(i);
      end;
  Result := PaletteCreate(Cols, ncols);
end;

function CreateSystemPalette : HPalette;
var
  cols : array[0..255] of TColorRef;
  DC : HDC;
begin
  DC := GetDC(0);
  GetSystemPaletteEntries(DC, 0, 256, cols);
  ReleaseDC(0, DC);
  Result := PaletteCreate(Cols, 256);
end;

function CreatePaletteOf(Info : PBitmapInfo) : HPalette;
var
  Size : integer;
  LogPal : PLogPalette;
begin
  with Info^, bmiHeader do begin
    Size := sizeof(TRGBQuad) shl biBitCount;
    GetMem(LogPal, Size+4);
    with LogPal^ do begin
      palVersion := $300;
      palNumEntries := biClrUsed;
      if palNumEntries = 0 then
        palNumEntries := 1 shl biBitCount;
      Move(bmiColors, palPalEntry, Size);
    end;
    CreatePaletteOf := CreatePalette(LogPal^);
    FreeMem(LogPal, Size+4);
  end;
end;

function CreatePaletteOfBMP(Info : PBitmapInfo) : HPalette;
var
  Size : integer;
  LogPal : PLogPalette;
  i : integer;
begin
  with Info^, bmiHeader do begin
    Size := sizeof(TRGBQuad) shl biBitCount;
    GetMem(LogPal, Size+4);
    LogPal^.palVersion := $300;
    LogPal^.palNumEntries := 1 shl biBitCount;
    {$R-}
    for i := 0 to LogPal^.palNumEntries-1 do with bmiColors[i], LogPal^.palPalEntry[i] do
    begin
      peRed := rgbRed;
      peBlue := rgbBlue;
      peGreen := rgbGreen;
      peFlags := 0;
    end;
    CreatePaletteOfBMP := CreatePalette(LogPal^);
    FreeMem(LogPal, Size+4);
  end;
end;

function DialogBoxLib(Instance, DlgLib : THandle; TemplateName : PChar;
  WndParent : HWnd; DialogFunc : TFarProc) : integer;
var
  Dlg, HRes : THandle;
  DlgPtr : pointer;
begin
  {$IFDEF WIN32}
  DialogBoxLib :=
    DialogBox(DlgLib, MakeIntResource(TemplateName), WndParent, DialogFunc);
  {$ELSE}
  DialogBoxLib := -1;
  HRes := FindResource(DlgLib, TemplateName, RT_DIALOG);
  if HRes > 0 then begin
    Dlg := LoadResource(DlgLib, HRes);
    if Dlg <> 0 then begin
      LockResource(Dlg);
      DialogBoxLib :=
        DialogBoxIndirect(Instance, Dlg, WndParent, DialogFunc);
      UnlockResource(Dlg);
      FreeResource(Dlg);
    end;
  end;
  {$ENDIF}
end;

procedure ShowSplashScreen(var R: TRect; Instance : THandle;
  BitmapName, Message : PChar; MsgColor : TColorRef);
var
  HRes : THandle;
  BM: HBitmap;
  BitmapPtr, BitsPtr : pointer;
  Info : PBitmapInfo;
  DC : HDC;
  Palette : THandle;
begin
  HRes := FindResource(Instance, BitmapName, RT_BITMAP);
  BM := LoadResource(Instance, HRes);
  if (BM <> 0) then begin
    BitmapPtr := LockResource(BM);
    Info := BitmapPtr;
    {$IFDEF WIN32}
    BitsPtr := PChar(BitmapPtr) + sizeof(TBitmapInfoHeader) +
      sizeof(TRGBQuad) shl Info^.bmiHeader.biBitcount;
    {$ELSE}
    BitsPtr := Ptr(PtrRec(BitmapPtr).Seg, sizeof(TBitmapInfoHeader) +
      sizeof(TRGBQuad) shl Info^.bmiHeader.biBitcount);
    {$ENDIF}
{    DC := CreateDC('DISPLAY', nil, nil, nil);}
    DC := GetDC(0);
    with Info^.bmiHeader do begin
      Palette := CreatePaletteOf(Info);
      SelectPalette(DC, Palette, false);
      RealizePalette(DC);
      R.Left := GetDeviceCaps(DC,HORZRES) shr 1 - biWidth shr 1;
      R.Top := GetDeviceCaps(DC,VERTRES) shr 1 - biHeight shr 1;
      R.Right := R.Left + biWidth;
      R.Bottom := R.Top + biHeight;
      SetDIBitsToDevice(DC, R.Left, R.Top, biWidth, biHeight,
        0, 0, 0, biHeight, BitsPtr, Info^, DIB_RGB_COLORS);
    end;
    UnlockResource(BM);
    FreeResource(BM);
    if Message <> nil then begin
      SetTextColor(DC, MsgColor);
      SetBkMode(DC, TRANSPARENT);
      InflateRect(R, -10, -10);
      DrawText(DC, Message, StrLen(Message), R, DT_WORDBREAK);
    end;
{    DeleteDC(DC);}
    ReleaseDC(0, DC);
  end;
end;

function GetINIFileName : PChar;
var
  Buf: array [0..127] of Char;
  B, E: PChar;
begin
  GetModuleFileName(HInstance, Buf, SizeOf(Buf));
  B := StrRScan(Buf, '\');
  if B = nil then
    B := Buf
  else
    Inc(B);
  E := StrRScan(B, '.');
  if E = nil then
    StrCat(B,'.INI')
  else
    StrCopy(E, '.INI');
  GetINIFileName := StrNew(Buf);
end;

function GetRandomFile(FileSpec : PChar) : PChar;
var
  Info : TSearchRec;
  count : integer;
  Buf : array[0..127] of char;
  p : PChar;
  r : integer;
begin
  count := 0;
  r := FindFirst(StrPas(FileSpec), faArchive, Info);
  while r = 0 do begin
    inc(Count);
    r := FindNext(Info);
  end;
  FindClose(Info);
  if count = 0 then begin
    GetRandomFile := StrNew(FileSpec);
    Exit;
  end;
  if count > 1 then begin
    count := v_random(Count);
    FindFirst(StrPas(FileSpec), faArchive, Info);
    while Count > 0 do begin
      FindNext(Info);
      dec(Count);
    end;
    FindClose(Info);
  end;
  StrCopy(Buf, FileSpec);
  p := StrRScan(Buf, '\');
  if p <> nil then
    StrPCopy(p+1, Info.Name)
  else
    StrPCopy(Buf, Info.Name);
  Result := StrNew(Buf);
end;

var
  v_seed : longint;

function v_random(a : longint) : longint;
var
  oldseed : Longint;
begin
  oldseed := RandSeed;
  RandSeed := v_seed;
  v_random := random(a);
  v_seed := RandSeed;
  RandSeed := oldseed;
end;

begin
  Randomize;
  v_seed := RandSeed;
  HStrLib := HInstance;
end.

