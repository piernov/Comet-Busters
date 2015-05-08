(*********************************************************)
(**  GAMEXTRA.PAS                                       **)
(**  Special TPROPs for games                           **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit GameXtra;
{$X+,P+}

{$IFDEF wing}
{$DEFINE spritetext}
{$ENDIF}

interface

uses
  Objects, WinTypes, WinProcs, GameLib, IMath, Sprite24, SysUtils
  {$IFDEF wing}, Wing{$ENDIF};

type
  { a scorebord prop with cool LED numbers }
  PLEDReadout = ^TLEDReadout;
  TLEDReadout = object(TProp)
    Pos : TPoint;
    Val : PLongint; { points to a longint which should contain the score }
    LastVal : longint;
    Costume : PBitCostume;
    constructor Init(X, Y : integer; pVal : PLongint; Hue : integer);
    destructor Done; virtual;
    procedure Update(Stage : PStage); virtual;
    procedure Draw(Stage : PStage); virtual;
    procedure GetRect(var R : TRect); virtual;
  end;

  { a prop which shows little ships defining how many lives you have left }
  PLivesLeft = ^TLivesLeft;
  TLivesLeft = object(TProp)
    Pos : TPoint;
    Lives : PInteger;
    Shape : PCostume;
    Color : TColorRef;
    LifeBeingKilled : integer;
    KillStage : integer;
    AddLife : boolean;
    constructor Init(X, Y : integer; pLives : PInteger; pShape : PCostume;
      pColor : TColorRef);
    procedure GetRect(var R : TRect); virtual;
    procedure Draw(Stage : PStage); virtual;
    procedure Update(Stage : PStage); virtual;
    procedure KillLife;
    procedure AddNewLife;
  end;

  { a prop which displays BIG text on the stage }
  PBigText = ^TBigText;
  TBigText = object(TProp)
  private
    Size : integer;
    Font : HFont;
    BkColor, ForeColor : TColorRef;
    Text : PChar;
    {$IFDEF spritetexts}
    SpritePtr : pointer;
{    SpriteSize : longint;}
    {$ENDIF}
  public
    Pos : TPoint;
    XAlign,YAlign : byte;
    constructor Init(X, Y : integer; s : PChar; ASize : integer;
      FontName : PChar; TheBCol, TheFCol : TColorRef);
    destructor Done; virtual;
    procedure Update(Stage : PStage); virtual;
    procedure Draw(Stage : PStage); virtual;
    procedure GetRect(var R : TRect); virtual;
    procedure ChangeText(NewText : PChar);
    function GetText : PChar;
  end;

  { a prop that displays a bitmap }
  PBitmapProp = ^TBitmapProp;
  TBitmapProp = object(TProp)
    Cen : TPoint;
    Size : TPoint;
    Costume : PBitCostume;
    constructor Init(X, Y : integer; Instance : THandle; Name : PChar);
    destructor Done; virtual;
    procedure Update(Stage : PStage); virtual;
    procedure Draw(Stage : PStage); virtual;
    procedure GetRect(var R : TRect); virtual;
  end;

  PixRec = record
    Pos : TPoint;
    Col : TColorRef;
    k : longint;
  end;
  PixArray = array[0..$ffe] of PixRec;

  { PixelCloud - a cloud of particles when something blows up }
  PPixelCloud = ^TPixelCloud;
  TPixelCloud = object(TCostume)
    Pixels : ^PixArray;
    NumPixels : word;
    OddFrame : boolean;
    constructor Init(Pal : HPalette; Player : PPlayer; ANumPixels : word);
    { initialize this with the game palette, the player you want exploded,
      and number of particles you want. The constructor will draw the
      player in an internal buffer and create particles based on the
      colors in the buffer }
    destructor Done; virtual;
    procedure Draw(Stage : PStage;
      X, Y, sX, sY, Rot, Frame : integer; ROP : longint); virtual;
  end;


function TransColor(Color : TColorRef; Scal : word; Add : word) : TColorRef;

const
  talign_Left  = 0;
  talign_Xcen  = 1;
  talign_Right = 2;
  talign_Top   = 0;
  talign_Ycen  = 1;
  talign_Bottom= 2;

implementation

uses
  CometLib, BMPCache
  {$IFDEF leak}, LeakFind{$ENDIF}
  ;

constructor TLEDReadout.Init;
var
  DC : HDC;
begin
  inherited Init;
  Pos.X := X; Pos.Y := Y;
  Val := pVal;
  LastVal := -1;
  DC := GetDC(0);
  Costume := New(PBitCostume, Init(HLib, PChar(128), DC, 13, Hue));
  ReleaseDC(0, DC);
end;

destructor TLEDReadout.Done;
begin
  Dispose(Costume, Done);
  inherited Done;
end;

procedure TLEDReadout.Draw(Stage : PStage);
  const
    CharXSize = 16;
    CharYSize = 18;
const
  ScoreLen = 7;
  MaxScoreVal = 10000000;
var s : string[ScoreLen];
    i : integer;
    n : byte;
    oldbits : pointer;
begin
  Str(Val^ mod MaxScoreVal:ScoreLen, s);
  for i := 1 to ScoreLen do
    if s[i] = ' ' then s[i] := '0';
{  WriteLEDStr(Pos.X, Pos.Y, s);}
    oldbits := Stage^.BackBits;
    Stage^.BackBits := Stage^.BkgndBits;
    for i := 1 to length(s) do begin
      case s[i] of
        '0'..'9' : n := ord('9')-ord(s[i])+2;
      else
        n := 0;
      end;
      Costume^.Draw(Stage, Pos.x+i*CharXSize+(CharXSize div 2), pos.Y+CharYSize div 2,
        256, 256, 0, n, SRCCOPY);
    end;
    Stage^.BackBits := oldbits;
end;

procedure TLEDReadout.Update(Stage : PStage);
begin
  if LastVal <> Val^ then begin
    LastVal := Val^;
    PropDirty := true;
  end;
end;

procedure TLEDReadout.GetRect(var R : TRect);
begin
  SetRect(R, Pos.X, Pos.Y, Pos.X+14*8, Pos.Y+18);
end;

constructor TLivesLeft.Init;
begin
  inherited Init;
  Pos.X := X; Pos.Y := Y;
  Lives := pLives;
  Shape := pShape;
  Color := pColor;
  LifeBeingKilled := 0;
end;

const
  XSpac = 20;

procedure TLivesLeft.Draw(Stage : PStage);
const
  ScoreLen = 7;
  MaxScoreVal = 10000000;
  Siz = 128;
var s : string[ScoreLen];
    i : integer;
    R : TRect;
    DC : HDC;
    DCStage : TStage;
begin
  DC := Stage^.BkgndDC;
  DCStage.GDC := DC;
  DCStage.BackBits := Stage^.BkgndBits;
  if Lives^ > 0 then
    for i := 1 to Lives^ do begin
      SetTextColor(DC, 0);
      if (i <> LifeBeingKilled) or (KillStage = Siz) then begin
        SetBkColor(DC, Color);
        Shape^.DrawMask(@DCStage, Pos.X+i*XSpac+8, Pos.Y+8, Siz, Siz, 0, 0, SRCCOPY)
      end else begin
        Shape^.GetRect(R, Pos.X+i*XSpac+8, Pos.Y+8, Siz, Siz, 0);
        FillRect(DC, R, GetStockObject(BLACK_BRUSH));
        SetBkColor(DC, $FFFFFF);
        Shape^.DrawMask(@DCStage, Pos.X+i*XSpac+8, Pos.Y+8,
          KillStage, KillStage, 0, 0, SRCCOPY)
      end;
    end;
end;

procedure TLivesLeft.GetRect(var R : TRect);
begin
  SetRect(R, Pos.X, Pos.Y, Pos.X+Lives^*XSpac+XSpac, Pos.Y+16);
end;

procedure TLivesLeft.Update;
begin
  if LifeBeingKilled > 0 then begin
    if AddLife then inc(KillStage, 16)
               else dec(KillStage, 16);
    if (KillStage = 0) or (KillStage = 128) then begin
      if not AddLife then dec(Lives^);
      LifeBeingKilled := 0;
    end;
    PropDirty := true;
  end;
end;

procedure TLivesLeft.KillLife;
begin
  LifeBeingKilled := Lives^;
  KillStage := 128;
  AddLife := false;
end;

procedure TLivesLeft.AddNewLife;
begin
  inc(Lives^);
  LifeBeingKilled := Lives^;
  KillStage := 0;
  AddLife := true;
end;

constructor TBigText.Init;
var LogFont : TLogFont;
begin
  if s = nil then Fail;
  inherited Init;
  Pos.X := X; Pos.Y := Y;
  Text := StrNew(s);
  BkColor := TheBCol;
  ForeColor := TheFCol;
  FillChar(LogFont, sizeof(LogFont), 0);
  LogFont.lfHeight := ASize;
  LogFont.lfWeight := FW_BOLD;
  LogFont.lfQuality := PROOF_QUALITY;
  StrLCopy(LogFont.lfFaceName, FontName, LF_FACESIZE-1);
  Font := CreateFontIndirect(LogFont);
  GetObject(Font, sizeof(LogFont), @LogFont);
  Size := LogFont.lfHeight;
  XAlign := 1; YAlign := 1;
  {$IFDEF spritetexts}
  SpritePtr := nil;
  {$ENDIF}
end;

function TBigText.GetText : PChar;
begin
  Result := Text;
end;

procedure TBigText.ChangeText(NewText : PChar);
begin
  if Text <> nil then StrDispose(Text);
  Text := StrNew(NewText);
  PropDirty := true;
{  SpritePtr := nil;}
end;

destructor TBigText.Done;
begin
  DeleteObject(Font);
  inherited Done;
end;

function TransColor(Color : TColorRef; Scal : word; Add : word) : TColorRef;
{ scales the RGB color COLOR by Scal and offsets it by ADD }
{$IFNDEF WIN32}
assembler;
var NewRef : longint;
asm
  mov  cx,3
  mov  di,Scal
  xor  si,si
@@1:
  mov  al,byte ptr [Color+si]
  mov  ah,0
  mul  di
  add  ah,byte ptr Add
  adc  dl,byte ptr Add+1
  or   dx,dx
  jz   @@2
  mov  ah,0ffh
@@2:
  mov  byte ptr [NewRef+si],ah
  inc  si
  loop @@1
  mov  ax,word ptr [NewRef]
  mov  dx,word ptr [NewRef+2]
  mov  dh,0
end;
{$ELSE}
var
  cols : array[0..2] of byte absolute Color;
  i : integer;
begin
  for i := 0 to 2 do begin
    cols[i] := IMin((cols[i]*Scal+Add) shr 8, $FF);
  end;
  Result := Color;
end;
{$ENDIF}

procedure ColorRect(DC : HDC; var R : TRect; Color : TColorRef);
var Brush : HBrush;
begin
  Brush := CreateSolidBrush(Color);
  FillRect(DC, R, Brush);
  DeleteObject(Brush);
end;

procedure TBigText.Draw(Stage : PStage);
var R,BR : TRect;
    BorderX, BorderY, OldBk : integer;
    SDC,DC : HDC;
    OldBitmap, Bitmap : HBitmap;
    {$IFDEF wing}
    Info : TBitmapInfo8Bit;
    Bits : pointer;
    BitInfo : TBitmap;
    BitSize : longint;
    LogFont : TLogFont;
    Key : String;
    i : integer;
    BMPObj : TSpriteObj;
    SpritePtr : pointer;
    SpriteSize : longint;
    {$ENDIF}
begin
  GetRect(R);
  {$IFDEF spritetext}
  BR := R;
  OffsetRect(R, -R.left, -R.top);
{  if SpritePtr = nil then}
  begin
    { see if this font bitmap is in cache }
    GetObject(Font, sizeof(LogFont), @LogFont);
    { make a unique id for the font + message }
    with LogFont do
      Key := Format('"%s"-%s:%d-%d-%d-%d-%d-%d',
        [StrPas(Text), StrPas(lfFaceName),
         lfHeight, lfWidth, lfWeight, lfItalic, lfUnderline, lfStrikeout]);
    BMPObj := TSpriteObj(TheBMPCache.GetObject(Key));
    { if it's not in the cache, create it }
    if BMPObj <> nil then begin
      SpritePtr := BMPObj.Data;
    end else begin
      R.right := (R.right+3) and not 3;
      Bitmap := Stage^.CreateDDBitmap(Info, R.right, R.bottom, Bits);
      DC := WinGCreateDC;
      OldBitmap := SelectObject(DC, Bitmap);
      SelectPalette(DC, Pal, false);
      RealizePalette(DC);
  {$ELSE}
    DC := Stage^.GDC;
  {$ENDIF}
    SelectObject(DC, Font);
    SetTextAlign(DC, TA_LEFT or TA_TOP);
    {$IFNDEF wing}ColorRect(DC, R, BkColor);{$ENDIF}
    {$IFDEF spritetext}ColorRect(DC, R, BkColor);{$ENDIF}
    OldBk := SetBkMode(DC, TRANSPARENT);
    BorderX := GetSystemMetrics(SM_CXBORDER);
    BorderY := GetSystemMetrics(SM_CYBORDER);
    SetTextColor(DC, TransColor(ForeColor, $180, $40));
    TextOut(DC, R.left, R.top, Text, StrLen(Text));
    SetTextColor(DC, TransColor(ForeColor, $80, 0));
    TextOut(DC, R.left+BorderX*2, R.top+BorderY*2, Text, StrLen(Text));
    SetTextColor(DC, ForeColor);
    TextOut(DC, R.left+BorderX, R.top+BorderY, Text, StrLen(Text));
    SetBkMode(DC, OldBk);
  {$IFDEF spritetext}
      GetObject(Bitmap, sizeof(BitInfo), @BitInfo);
      with BitInfo do BitSize := longint(bmWidthBytes)*bmHeight;
      Bits := GlobalAllocPtr(GMEM_MOVEABLE, BitSize);
      GetBitmapBits(Bitmap, BitSize, Bits);
      SpritePtr := MakeSpriteFromBMP(PBitmapInfo(@Info)^, Bits,
        (BitInfo.bmWidthBytes), true{, SpriteSize});
      GlobalFreePtr(Bits);
      DeleteObject(SelectObject(DC, OldBitmap));
      DeleteDC(DC);
      TheBMPCache.AddObject(Key, TSpriteObj.Create(SpritePtr));
    end;
  end;
  SpriteDraw(Stage, SpritePtr, Stage^.BackBits, BR.left, BR.top, 0, R.bottom);
  {$ENDIF}
end;

procedure TBigText.Update(Stage : PStage);
begin
  inherited Update(Stage);
end;

procedure TBigText.GetRect(var R : TRect);
var DC: HDC;
    P : TPoint;
begin
  DC := GetDC(0);
  SelectObject(DC, Font);
  {$IFNDEF WIN32}
  longint(P) := GetTextExtent(DC, Text, StrLen(Text));
  {$ELSE}
  GetTextExtentPoint32(DC, Text, StrLen(Text), TSize(P));
  {$ENDIF}
  R.left := Pos.X;
  R.top := Pos.Y;
  dec(R.left, (P.X*XAlign) shr 1);
  dec(R.top, (P.Y*YAlign) shr 1);
  R.right := R.left + P.X + GetSystemMetrics(SM_CXBORDER)*2;
  R.bottom := R.top + P.Y + GetSystemMetrics(SM_CYBORDER)*2;
  ReleaseDC(0, DC);
end;

constructor TBitmapProp.Init(X, Y : integer; Instance : THandle; Name : PChar);
var BitInfo : TBitmap;
    DC : HDC;
begin
  inherited Init;
  Cen.X := X; Cen.Y := Y;
  DC := GetDC(0);
  Costume := New(PBitCostume, Init(Instance, Name, DC, 1, 0));
  ReleaseDC(0, DC);
  Size := Costume^.Size;
{  Bits := LoadBitmap(Instance, Name);
  if Bits = 0 then Fail;
  GetObject(Bits, sizeof(BitInfo), @BitInfo);
  Size.X := BitInfo.bmWidth;
  Size.Y := BitInfo.bmHeight;}
end;

destructor TBitmapProp.Done;
begin
{  DeleteObject(Bits);}
  if Costume <> nil then
    Dispose(Costume, Done);
  inherited Done;
end;

procedure TBitmapProp.GetRect(var R : TRect);
begin
  R.left := Cen.X-Size.X shr 1;
  R.top := Cen.Y-Size.Y shr 1;
  R.right := R.left+Size.X;
  R.bottom := R.top+Size.Y;
end;

procedure TBitmapProp.Draw(Stage : PStage);
begin
  Costume^.Draw(Stage, Cen.X, Cen.Y, 256, 256, 0, 0, SRCCOPY);
end;

procedure TBitmapProp.Update(Stage : PStage);
begin
  inherited Update(Stage);
end;

constructor TPixelCloud.Init(Pal : HPalette; Player : PPlayer; ANumPixels : word);
var
  i : integer;
  DispDC, MemDC : HDC;
  DCStage : TStage;
  Bits : HBitmap;
  R : TRect;
  OldOrg : TPoint;
  X, Y : integer;
  Count : integer;
begin
  inherited Init;
  Player^.GetRect(R);
  Size.X := R.right-R.left;
  Size.Y := R.bottom-R.top;
  {$IFDEF wing}
    NumPixels := ANumPixels;
    GetMem(Pixels, ANumPixels*sizeof(PixRec));
    for i := 0 to ANumPixels-1 do with Pixels^[i] do begin
      repeat
        X := v_random(Size.X);
        Y := v_random(Size.Y);
      until ISqr(X)+ISqr(Y) <= ISqr(Size.X);
      Pos.X := X-Size.X shr 1;
      Pos.Y := Y-Size.Y shr 1;
      Col := $808080+v_random($40);
    end;
  {$ELSE}
  DispDC := CreateDC('DISPLAY', nil, nil, nil);
  MemDC := CreateCompatibleDC(DispDC);
  if MemDC <> 0 then begin
    Bits := CreateCompatibleBitmap(DispDC, Size.X, Size.Y);
    SelectObject(MemDC, Bits);
    SelectPalette(MemDC, Pal, true);
    SetWindowOrgEx(MemDC, R.left, R.top, @OldOrg);

    DCStage.GDC := MemDC;
    with Player^ do begin
      Stage^.TransCoords(Pos, X, Y);
      Costume^.Draw(@DCStage, X, Y, Size.X-1, Size.Y-1, Rot, Frame, SRCCOPY);
    end;

    SetWindowOrgEx(MemDC, OldOrg.X, OldOrg.Y, @OldOrg);
    NumPixels := ANumPixels;
    GetMem(Pixels, ANumPixels*sizeof(PixRec));
    for i := 0 to ANumPixels-1 do with Pixels^[i] do begin
      Count := 16;
      repeat
        X := v_random(Size.X);
        Y := v_random(Size.Y);
        Col := GetPixel(MemDC, X, Y);
        dec(Count);
      until (Col <> 0) or (Count = 0);
      SetPixel(MemDC, X, Y, 0);
      Pos.X := X-Size.X shr 1;
      Pos.Y := Y-Size.Y shr 1;
    end;
    DeleteDC(MemDC);
    DeleteObject(Bits);
  end else begin
    DeleteDC(DispDC);
    Fail;
  end;
  DeleteDC(DispDC);
  {$ENDIF}
  OddFrame := false;
end;

destructor TPixelCloud.Done;
begin
  FreeMem(Pixels, NumPixels*sizeof(PixRec));
  inherited Done;
end;

procedure TPixelCloud.Draw(Stage : PStage;
  X, Y, sX, sY, Rot, Frame : integer; ROP : longint);
var
  I : integer;
  R : TRect;
  P : TPoint;
begin
  for i := 0 to NumPixels-1 do
    with Pixels^[i] do begin
      P.X := X+LongMulShr8(Pos.X, sX);
      P.Y := Y+LongMulShr8(Pos.Y, sY);
      Stage^.PutPixel(P.X, P.Y, TransColor(Col, Frame, Frame shr 6));
    end;
  OddFrame := not OddFrame;
  GetRect(R, X, Y, sX, sY, 0);
  InflateRect(R, 1, 1);
  Stage^.Dirty^.AddRect(R);
end;

end.

