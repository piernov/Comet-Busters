(*********************************************************)
(**  SPRITEWG.PAS                                       **)
(**  Sprite object library                              **)
(**                                                     **)
(**  Copyright (c) 1996 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

interface

uses
  Objects, WinTypes, WinProcs, WinG, DirtRect;

type
  UPoint = record
    X, Y : Cardinal;
  end;

  PBitmapInfo8Bit = ^TBitmapInfo8Bit;
  TBitmapInfo8Bit = record
    Hdr : TBitmapInfoHeader;
    Cols : array[0..255] of TRGBQuad;
  end;

  PPlayer = ^TPlayer;

  PYposLUT = ^TYposLUT;
  TYposLUT = array[0..4095] of longint;

  PProp = ^TProp;

  { TSTAGE - A rectangular playfield for the Actors (sprites).
    Contains Actors, Props (background/foreground scenery),
    and controls the timing and movement of the Actors.
  }
  PStage = ^TStage;
  TStage = object(TObject)
  private
    PalEnt : array[0..255] of TPaletteEntry;
    BackdropInfo : PBitmapInfo8Bit;
    ForeProps : TCollection;
  public
    Objs,
    NewObjs,
    Props : TCollection;
    TempDC : HDC;
    GDC,BkgndDC : HDC; { WING DC }
    HBack,HBkgnd : HBitmap; { WING back buffer, background }
    BackdropBits : pointer;{ pretty picture for background }
    BackBits,BkgndBits : pointer; { pointer to back buffer }
    OldBackBMP,OldBkgndBMP : HBitmap; { old mono bitmaps -- a drag }
    ByteWidth,ByteOffset : integer; { width of back buffer, in bytes }
    BitsPerPixel,BytesPerPixel : integer;
    ylut : PYposLUT; { LUT for ypos of screen }
    ViewOrg : TPoint;
    ViewSize : UPoint;
    XRes, YRes : integer;
    Dirty, OldDirty : PDirtyRegion;
    Options : word;
  private
    MergedDirty : PDirtyRegion;
    ScreenRect : TRect;
  public
    constructor Init;
    destructor Done; virtual;
    procedure Clear;
    procedure Show(DC : HDC);
    procedure Update(DC : HDC);
    procedure Add(p : PPlayer);
    procedure DrawForeground(DC : HDC); virtual;
    procedure DrawBackground(DC : HDC); virtual;
    procedure TransCoords(var P : TPoint; var X, Y : integer);
    procedure ScreenToStage(var P : TPoint);
    procedure SendMessage(Command, wParam : word; lParam : longint);
    procedure SetViewingArea(X1, Y1, X2, Y2, XS, YS : integer);
    procedure AddForeProp(Prop : PProp);
    procedure ClearForeProp(Prop : PProp);
    function HasForeProp(Prop : PProp) : boolean;
    procedure ClearForeProps;
    { new WING functions }
    procedure DisplayBackBuf(DC : HDC);
    procedure DisplayBackBufDirty(DC : HDC);
    procedure PutPixel(x,y : integer; Color : TColorRef);
    procedure LoadBackdrop(Filename : PChar);
    function CreateDDBitmap(var Info : TBitmapInfo8Bit;
      width, height : integer; var Bits : pointer) : HBitmap;
    procedure BackToBkgndCopy(const R : TRect);
    procedure ClearRect(const R : TRect);
    procedure MakeNewDirtyRgn;
  end;

  { TCOSTUME - a visual form for the Actors
    This is a generic object.
  }
  PCostume = ^TCostume;
  TCostume = object(TObject)
    Size : TPoint;
    procedure Draw(Stage : PStage;
      X, Y, sX, sY, Rot, Frame : integer; ROP : longint); virtual;
    { draws the costume at a specified location, at a specified size,
      and with a specified rotation or frame #, with a specified ROP
      (raster op). }
    procedure DrawMask(Stage : PStage;
      X, Y, sX, sY, Rot, Frame : integer; ROP : longint); virtual;
    { does the same thing, but only draws the silohuette of the shape. }
    procedure GetRect(var R : TRect; X, Y, sX, sY, Rot : integer); virtual;
    { returns the bounding rectangle of the shape, given the
      same parameters }
  end;

  { TBITCOSTUME - A costume defined as a bitmap
  }
  PBitCostume = ^TBitCostume;
  TBitCostume = object(TCostume)
    HMask : HBitmap;
    MemDC : HDC;
    SpritePtr : pointer; { pointer to sprite data }
    NumFrames, YDiv : integer;
    constructor Init(Instance : THandle; Name : PChar; DispDC : HDC;
      AFrames : integer; Hue : integer);
    { Initializes the costume with a specified bitmap.
      NAME is the instance of the bitmap, and INSTANCE is the module
        in which it is located.
      DISPDC is the device context where the bitmaps will be displayed.
        If the bitmaps require a palette, it should be selected into
        this device context.
      AFRAMES is the number of frames of the bitmap. The bitmap will
        be divided vertically into this many frames, like a filmstrip.
        The rotation or frame # parameter passed to DRAW controls which
        frame is displayed.
      HUE is an integer, which if nonzero, controls the hue of the
        sprite. For each $100 a 90-degree hue shift is performed.
    }
    destructor Done; virtual;
    procedure Draw(Stage : PStage;
      X, Y, sX, sY, Rot, Frame : integer; ROP : longint); virtual;
    procedure DrawMask(Stage : PStage; X, Y, sX, sY, Rot, Frame : integer; ROP : longint); virtual;
  end;

  { TPROP - A background or foreground static object.
    Props must remain in a fixed position.
  }
  TProp = object(TObject)
    PropDirty : boolean; { tells whether the prop has to be redrawn }
    constructor Init;
{    destructor Done; virtual;}
    procedure Update(Stage : PStage); virtual;
    { This procedure is called every frame the prop is onscreen.
      If the visual appearance of the prop should change, it should
      be reflected here. }
    procedure Draw(Stage : PStage); virtual;
    { Displays the prop on DC }
    procedure GetRect(var R : TRect); virtual;
    { Returns the bounding rectangle of the prop }
  end;

  { TPLAYER - A sprite object. Wears a TCOSTUME; performs on a TSTAGE.
    Has position, velocity, rotation, size, and all kinda neat flags.
  }
  TPlayer = object(TObject)
    Stage : PStage;        { stage where object is contained }
    Costume : PCostume;    { costume assigned to object }
    Status : word;         { see plyr_xxxx flags for details }
    Pos : TPoint;          { position }
    Vel : TPoint;          { velocity }
    Size : TPoint;         { size - ($100,$100) is normal size }
    Frame,                 { frame # }
    Rot,                   { rotation value - $100 is 90 degrees }
    RotVel : integer;      { rotation velocity }
    Color : TColorRef;     { color for masks }
    {$IFDEF rgncollide}
    Collision : boolean;
    {$ENDIF}
    HaveMoved : boolean;
    LastGetRect : TRect;   { cached bounding rectangle for GetRect }
    constructor Init(TheStage : PStage; X, Y : integer; Cost : PCostume);
    procedure Setup; virtual;
    procedure Draw(ROP : longint); virtual;
    procedure DrawMask(ROP : longint); virtual;
    procedure Move; virtual;
    procedure Cue; virtual;
    procedure Update;
    function ChkCollide : boolean; virtual;
    { Returns TRUE if it is possible for the object to have a collision }
    function Collide(p : PPlayer) : boolean; virtual;
    { Returns TRUE if the object collides with player P }
    procedure GetRect(var R : TRect); virtual;
    { Returns bounding rectangle }
    procedure Kill; virtual;
    { called to kill the object. Sets the plyr_Dead flag }
    function Message(Command, wParam : word; lParam : longint) : longint;
      virtual;
  end;

const
  plyr_Cloaked = 1;             { player is invisible }
  plyr_Invulnerable = 2;        { player cannot have collisions }
  plyr_Hidden = plyr_Cloaked or plyr_Invulnerable;
  plyr_Frozen = 4;              { player cannot move }
  plyr_MaskOnly = 8;            { player's mask is drawn in lieu of the
                                  actual costume }
  plyr_NoRgnAdd = 16;           { player leaves 'trails' }
  plyr_WrapAroundX = 32;        { player wraps around the stage horizontally }
  plyr_WrapAroundY = 64;        { player wraps around the stage vertically }
  plyr_WrapAround = plyr_WrapAroundX or plyr_WrapAroundY;
  plyr_Dead = 128;              { player is deceased, and will be removed
                                  from the stage on next update }
  pmsg_Kill = $8880;

{function AddRgn(var DestRgn : HRgn; Rgn : HRgn) : HRgn;}
{ OR's the region RGN with DESTRGN and stores the result in
  DESTRGN. Returns RGN. }
procedure ShiftHue(var cols; numcols, hue : word);
{ Shifts an array of TRGBTRIPLEs by HUE degrees ($100 = 90 degrees) }

procedure ClearSystemPalette;

function MakeSpriteFromBMP(const Info : TBitmapInfo; Bits : pointer;
  bytwid : integer; upsidedown : boolean{; var Size : longint}) : pointer;
procedure SpriteDraw(Stage : PStage; Src, Dest : pointer; DestX, DestY,
  SrcY, SrcHeight : integer);
procedure SpriteDrawMask(Stage : PStage; Src, Dest : pointer; DestX, DestY,
  SrcY, SrcHeight : integer; Color : TColorRef);

procedure Check(b : Bool);

implementation

uses
  IMath, HTTables, Strings, GameLib{$IFDEF profile}, MMSystem{$ENDIF}
  {$IFDEF leak}, LeakFind{$ENDIF};

{$IFNDEF WIN32}
procedure AHIncr; far; external 'KERNEL' index 114;

function AddSelector(p : pointer; Cnt : longint) : pointer; assembler;
asm
  xor  ax,ax
  mov  cx,word ptr [p]
  add  cx,word ptr [Cnt]
  adc  ax,word ptr [Cnt+2]
  mul  SelectorInc
  add  ax,word ptr [p+2]
  mov  dx,ax
  mov  ax,cx
end;

function PtrCvt(ASeg : word; AOfs : longint) : pointer; assembler;
asm
  mov  ax,word ptr [AOfs+2]
  mul  SelectorInc
  add  ax,ASeg
  mov  dx,ax
  mov  ax,word ptr [AOfs]
end;

procedure Move32align4(SrcSeg, DestSeg : word; SrcDestOfs, Size,
  LineOffset : longint; LineCount : integer); assembler;
asm
  push ds
  mov  ds,SrcSeg
  mov  es,DestSeg
  mov  dx,LineCount
  db   66h
  mov  ax,word ptr LineOffset
  db   66h
  mov  si,word ptr SrcDestOfs
  db   66h
  mov  di,word ptr SrcDestOfs
@@1:
  db   66h
  mov  cx,word ptr Size
  db   66h
  shr  cx,2
  db   66h
  db   67h
  rep  movsw { rep movsd }
  db   66h
  add  si,ax
  db   66h
  add  di,ax
  dec  dx
  jnz  @@1

  pop  ds
end;
procedure Move32(SrcSeg, DestSeg : word; SrcOfs, DestOfs, Size : longint); assembler;
asm
  push ds
  mov  ds,SrcSeg
  mov  es,DestSeg
  db   66h
  mov  si,word ptr SrcOfs
  db   66h
  mov  di,word ptr DestOfs
  db   66h
  mov  cx,word ptr Size
  db   67h
  test cx,3
  jz   @@1
  db   67h
  rep  movsb
@@1:
  db   66h
  shr  cx,2
  db   66h
  db   67h
  rep  movsw
  pop  ds
end;
procedure Fill32(DestSeg : word; DestOfs, Size : longint; Value : byte); assembler;
asm
  mov  es,DestSeg
  mov  al,Value
  mov  ah,al
  db   66h
  rol  ax,16
  mov  al,Value
  mov  ah,al
  db   66h
  mov  di,word ptr DestOfs
  db   66h
  mov  cx,word ptr Size
  db   67h
  test cx,3
  jz   @@1
  db   67h
  rep  stosb
@@1:
  db   66h
  shr  cx,2
  db   66h
  db   67h
  rep  stosw
end;
{$ENDIF}

procedure Check(b : Bool);
{ Checks the result of a Windows function.
  If zero, gives runtime error when R+. }
{$IFOPT R+}
begin
  if not b then
    RunError(217);
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure CheckNil(p : pointer);
begin
  if p = nil then RunError(219);
end;

procedure CheckRgn(res : integer);
{$IFOPT R+}
begin
  if res = ERROR then
    RunError(218);
end;
{$ELSE}
begin
end;
{$ENDIF}

{$IFDEF profile}
const
  ProfStats : record
    TotalTests, RectTests, BitmapTests : longint;
    MergedDirtyNum, ZoneListNum : integer;
    UpdateTime, MergeTime, ForeTime, BltTime, CopyBackTime, StartTime : longint;
  end = ();
procedure AddProfTime(var a : longint);
var
  time : longint;
begin
  time := timeGetTime;
  a := 0;
  inc(a, time-ProfStats.StartTime);
  ProfStats.StartTime := time;
end;
{$ENDIF}

procedure TStage.PutPixel(x,y : integer; Color : TColorRef);
begin
  { make sure pixel's within bounds }
  if (cardinal(y) < YRes) and (cardinal(x) < XRes) then
    {$IFDEF win32}
    PByte(PChar(BackBits)+ylut^[y]+x)^ :=
    {$ELSE}
    PByte(PtrCvt(PtrRec(BackBits).Seg, ylut^[y]+x))^ :=
    {$ENDIF}
      ClosestRGBtoIndex(TPaletteEntry(Color));
end;

procedure ClearSystemPalette;
  { A dummy palette setup }
var
  pal : record
    palVersion : word;
    palNumEntries : word;
    aEntries : array[0..255] of TPaletteEntry;
  end;
  ScreenPalette : HPalette;
  ScreenDC : HDC;
  Counter : integer;
begin
  { Reset everything in the system palette to black }
  pal.palVersion := $300;
  pal.palNumEntries := 256;
  FillChar(pal.aEntries, sizeof(pal.aEntries), 0);

  { Create, select, realize, deselect, and delete the palette }
  ScreenDC := GetDC(0);
  ScreenPalette := CreatePalette(PLogPalette(@pal)^);

  if ScreenPalette > 0 then begin
    ScreenPalette := SelectPalette(ScreenDC,ScreenPalette,FALSE);
    RealizePalette(ScreenDC);
    ScreenPalette := SelectPalette(ScreenDC,ScreenPalette,FALSE);
    DeleteObject(ScreenPalette);
  end;

  ReleaseDC(0, ScreenDC);
end;

{$IFNDEF win32}
function _hread(hf : THandle; hpv : pointer; cbBuffer : longint) : longint;
far; external 'KERNEL' index 349;
{$ENDIF}

procedure TStage.LoadBackdrop(Filename : PChar);
type
  TBitmapFile = record
    filehdr : TBitmapFileHeader;
    info : TBitmapInfo8Bit;
    data : array[0..0] of byte;
  end;
var
  BitmapPtr : pointer;
  Info : ^TBitmapFile;
  DC : HDC;
  Palette : THandle;
  HFile : integer;
  size : longint;
begin
  HFile := _lopen(GetRandomFile(Filename), OF_READ);
  if HFile < 0 then
    Exit;
  size := _llseek(HFile, 0, 2);
  BitmapPtr := GlobalAllocPtr(GMEM_MOVEABLE, size);
  if BitmapPtr = nil then
    Exit;
  _llseek(HFile, 0, 0);
  size := _hread(HFile, BitmapPtr, size);
  _lclose(HFile);
  if size < 0 then
    Exit;
  Info := BitmapPtr;
  with Info^ do begin
    if (filehdr.bfType <> $4D42) or (info.hdr.biBitCount <> 8) then
      Exit;
  end;
  BackdropBits := @Info^.Data;
  BackdropInfo := @Info^.Info;
end;

function TStage.CreateDDBitmap(var Info : TBitmapInfo8Bit;
  width, height : integer; var Bits : pointer) : HBitmap;
begin
  FillChar(Info, sizeof(Info), 0);
  with Info.Hdr do begin
    biSize := sizeof(Info.Hdr);
    biWidth := width;
    biHeight := height;
    biPlanes := 1;
    biBitCount := BitsPerPixel;
    biCompression := BI_RGB;
  end;
  Move(PalEnt, Info.Cols, sizeof(Info.Cols));
  Result := WinGCreateBitmap(GDC, @Info, @Bits);
end;

constructor TStage.Init;
var DC : HDC;
    R : TRect;
begin
  inherited Init;
  Objs.Init(256, 256);
  NewObjs.Init(64, 64);
  Props.Init(0, 64);
  ForeProps.Init(0, 64);
  DC := GetDC(0);
  TempDC := CreateCompatibleDC(DC);
  {
  case GetDeviceCaps(DC, BITSPIXEL) of
    0..8 : BitsPerPixel := 8;
    9..16 : BitsPerPixel := 16;
  else
    BitsPerPixel := 24;
  end;
  }
  BitsPerPixel := 8;
  BytesPerPixel := (BitsPerPixel+7) div 8;
  ReleaseDC(0, DC);

  GDC := WinGCreateDC;
  BkgndDC := WinGCreateDC;

  BackBits := nil;
  BkgndBits := nil;
  ylut := nil;
  HBkgnd := 0;
  HBack := 0;
  OldBkgndBMP := 0;
  OldBackBMP := 0;
  XRes := 0; YRes := 0;
  SetRectEmpty(ScreenRect);
  New(Dirty);
  Dirty^.Setup(ScreenRect);
  New(MergedDirty);
end;

destructor TStage.Done;
begin
  ForeProps.Done;
  Props.Done;
  NewObjs.Done;
  Objs.Done;
  Dispose(MergedDirty);
{  if DrawRgn <> 0 then
    Check(DeleteObject(DrawRgn));}
  DeleteDC(TempDC);
  if (HBack <> 0) then
    DeleteObject(SelectObject(GDC, OldBackBMP));
  DeleteDC(GDC);
  if (HBkgnd <> 0) then
    DeleteObject(SelectObject(BkgndDC, OldBkgndBMP));
  DeleteDC(BkgndDC);
  if (BackdropBits <> nil) then
    GlobalFreePtr(BackdropBits);
  inherited Done;
end;

procedure TStage.SetViewingArea;
var
  Fmt : TBitmapInfo8Bit;
  Pal : HPalette;
  i,y : integer;
begin
  if ylut <> nil then
    FreeMem(ylut, sizeof(longint)*YRes);
  ViewOrg.X := X1;
  ViewOrg.Y := Y1;
  ViewSize.X := word(X2-X1);
  ViewSize.Y := word(Y2-Y1);
  XRes := XS;
  YRes := YS;
  SetRect(ScreenRect, 0, 0, XRes, YRes);
  { allocate the back buffer }
  with Fmt, Hdr do begin
    if WinGRecommendDIBFormat(@Fmt) then
    begin
      biWidth := XRes;
      biHeight := biHeight * YRes;
      biBitCount := BitsPerPixel;
      biCompression := BI_RGB;
    end else begin
      FillChar(Fmt, sizeof(Fmt), 0);
      biSize := sizeof(Fmt.Hdr);
      biWidth := XRes;
      biHeight := YRes;
      biPlanes := 1;
      biBitCount := BitsPerPixel;
      biCompression := BI_RGB;
    end;
  end;
  { copy the palette into the DIB }
  Pal := WinGCreateHalftonePalette;
  GetPaletteEntries(Pal, 0, 256, PalEnt);
  for i := 0 to 255 do with PalEnt[i], Fmt.Cols[i] do begin
    rgbRed := peRed;
    rgbGreen := peGreen;
    rgbBlue := peBlue;
    rgbReserved := 0;
  end;
  DeleteObject(Pal);

  { set up y lookup table }
  ByteWidth := (((XRes*Fmt.hdr.biBitCount)+31) div 32)*4;
  ByteOffset := ByteWidth;
  if Fmt.hdr.biHeight >= 0 then
    ByteOffset := -ByteOffset;
  GetMem(ylut, sizeof(longint)*YRes);
  for y := 0 to YRes-1 do
    if Fmt.hdr.biHeight < 0 then
      ylut^[y] := longint(y)*ByteWidth
    else
      ylut^[y] := longint(YRes-y-1)*ByteWidth;

  { create the WinG back bitmap }
  HBack := WinGCreateBitmap(GDC, @Fmt, nil);
  if OldBackBMP = 0 then
    OldBackBMP := SelectObject(GDC, HBack)
  else
    DeleteObject(SelectObject(GDC, HBack)); { delete the old bitmap }
  BackBits := WinGGetDIBPointer(HBack, nil);
  CheckNil(BackBits);
  { create the background bitmap }
  HBkgnd := WinGCreateBitmap(GDC, @Fmt, nil);
  if OldBkgndBMP = 0 then
    OldBkgndBMP := SelectObject(BkgndDC, HBkgnd)
  else
    DeleteObject(SelectObject(BkgndDC, HBkgnd));
  BkgndBits := WinGGetDIBPointer(HBkgnd, nil);
  CheckNil(BkgndBits);
end;

procedure TStage.Clear;
begin
  Props.FreeAll;
  NewObjs.FreeAll;
  Objs.FreeAll;
  ClearForeProps;
end;

procedure TStage.DisplayBackBuf(DC : HDC);
begin
  if not WinGBitBlt(DC, 0, 0, XRes, YRes, GDC, 0, 0) then
    Check(BitBlt(DC, 0, 0, XRes, YRes, GDC, 0, 0, SRCCOPY));
end;


procedure TStage.BackToBkgndCopy(const R : TRect);
{ copies a rectangle from the background to the back buffer }
var y : integer;
    o : longint;
begin
  with R do begin
    o := (right-left)*BytesPerPixel;
    Move32align4(PtrRec(bkgndbits).Seg, PtrRec(backbits).Seg,
      (ylut^[top]+left)*BytesPerPixel,
      o, ByteOffset-o, bottom-top);
  end;
  (*
    for y := top to bottom-1 do begin
      {$IFDEF win32}
      o := (ylut^[y]+left)*BytesPerPixel;
      Move((PChar(bkgndbits)+o)^, (PChar(backbits)+o)^, (right-left)*BytesPerPixel);
      {$ELSE}
      o := (ylut^[y]+left)*BytesPerPixel;
      Move32(PtrRec(bkgndbits).Seg, PtrRec(backbits).Seg, o, o, (right-left)*BytesPerPixel);
      {$ENDIF}
    end;
  end;
  *)
end;

procedure TStage.DisplayBackBufDirty(DC : HDC);
var
  i : cardinal;
  PR : PRect;

  procedure ShowDirtyOutlines;
  begin
    i := 0;
    SelectObject(DC, GetStockObject(NULL_BRUSH));
    SelectObject(DC, GetStockObject(WHITE_PEN));
    while MergedDirty^.ForEach(i, PR) do with PR^ do begin
      Rectangle(DC, left, top, right, bottom);
    end;
  end;
begin
  MergedDirty^ := Dirty^;
  { merge old updates with current updates }
  if (OldDirty <> nil) then
    MergedDirty^.MergeWith(OldDirty^);
  {$IFDEF profile}AddProfTime(ProfStats.MergeTime);{$ENDIF}

  DrawForeground(GDC);
{  MergedDirty^.Optimize;}
  {$IFDEF seedirty}ShowDirtyOutlines;{$ENDIF}

  {$IFDEF profile}
  AddProfTime(ProfStats.MergeTime);
  ProfStats.MergedDirtynum := MergedDirty^.NumRects;
{  ProfStats.ZoneListNum := MergedDirty^.ZoneListCount;}
  {$ENDIF}

  { copy back buffer to screen, dirty rectangles only }
  i := 0;
  while MergedDirty^.ForEach(i, PR) do with PR^ do
  begin
    if not WinGBitBlt(DC, left, top, right-left, bottom-top, GDC, left, top) then
      Check(BitBlt(DC, left, top, right-left, bottom-top, GDC, left, top, SRCCOPY));
  end;
  {$IFDEF profile}AddProfTime(ProfStats.BltTime);{$ENDIF}

{  MergedDirty^ := Dirty^;}
{  MergedDirty^.Optimize;}
  { erase mess in back buffer -- copy background bitmap to back buffer }
  i := 0;
  while Dirty^.ForEach(i, PR) do with PR^ do
  begin
{    BitBlt(GDC, left, top, right-left, bottom-top, BkgndDC, left, top, SRCCOPY);}
    BackToBkgndCopy(PR^);
  end;
  {$IFDEF profile}AddProfTime(ProfStats.CopyBackTime);{$ENDIF}
end;

procedure TStage.MakeNewDirtyRgn;
begin
  if OldDirty <> nil then Dispose(OldDirty);
  OldDirty := Dirty;
  New(Dirty);
  Dirty^.Setup(ScreenRect);
end;

procedure TStage.Show(DC : HDC);
var i : integer;
    R : TRect;
begin
{  CheckRgn(SelectClipRgn(DC, 0));}
  { draw the background }
  MakeNewDirtyRgn;
  MergedDirty^.Setup(ScreenRect);
  DrawBackground(BkgndDC);
  Check(BitBlt(GDC, 0, 0, XRes, YRes, BkgndDC, 0, 0, SRCCOPY));
  { draw the players }
  if Objs.Count > 0 then
    for i := 0 to Objs.Count-1 do
      PPlayer(Objs.At(i))^.Draw(SRCCOPY);
  { draw the foreground props }
  if ForeProps.Count > 0 then
    for i := 0 to ForeProps.Count-1 do
      with PProp(ForeProps.At(i))^ do begin
        Draw(@Self);
        PropDirty := false;
      end;
  DisplayBackBuf(DC);
end;

procedure TStage.Update(DC : HDC);
{ Does a frame of the act }
var i : integer;
    R : TRect;
    Prop : PProp;

  {$IFDEF profile}
  procedure ShowProfile;
  const
    StatusString = '# dirty rects: %4d'#13+'# zone items: %4d'#13+
      'update: %6ld'#13'merge: %6ld'#13'fore: %6ld'#13'blt: %6ld'#13'copyback: %6ld';
  var
    S : array[0..511] of char;
    R : TRect;
  begin
    wvsprintf(S, StatusString, ProfStats.MergedDirtynum);
    GetClipBox(DC, R);
    DrawText(DC, S, StrLen(S), R, DT_LEFT);
  end;
  {$ENDIF}
begin
  {$IFDEF profile}ProfStats.StartTime := timeGetTime;{$ENDIF}
  MakeNewDirtyRgn;

  { place new players into the Objs collection }
  if NewObjs.Count > 0 then begin
    for i := 0 to NewObjs.Count-1 do begin
      Objs.Insert(NewObjs.At(i));
    end;                                { add the new players }
    NewObjs.DeleteAll;
  end;

  { get rid of dead players }
  i := 0;
  while (i < Objs.Count) do with PPlayer(Objs.At(i))^ do begin
    if Status and plyr_Dead > 0 then Objs.Free(Objs.At(i))
    else inc(i);
  end;                                  { kill off the dead ones }

{  CheckRgn(SelectClipRgn(GDC, OldRgn));
  DrawBackground(GDC);
  CheckRgn(SelectClipRgn(GDC, 0));}

  if Objs.Count > 0 then for i := 0 to Objs.Count-1 do
    PPlayer(Objs.At(I))^.Update;         { update all players }
  if Props.Count > 0 then for i := 0 to Props.Count-1 do
  begin
    Prop := PProp(Props.At(i));
    with Prop^ do begin
      Update(@Self);          { update all bkgnd props }
      if PropDirty then begin
        Draw(@Self);
        GetRect(R);
        Dirty^.AddRect(R);
        PropDirty := false;
      end;
    end;
  end;
  if Objs.Count > 0 then begin
    for i := 0 to Objs.Count-1 do
      PPlayer(Objs.At(I))^.Cue;           { give players their cues }
  end;
  {$IFDEF profile}AddProfTime(ProfStats.UpdateTime);{$ENDIF}

  DisplayBackBufDirty(DC);
  {$IFDEF profile}
  ShowProfile;
  {$ENDIF}
end;

function AddRgn(var DestRgn : HRgn; Rgn : HRgn) : HRgn;
begin
  AddRgn := Rgn;
  if Rgn = 0 then Exit;
  if DestRgn = 0 then begin
    DestRgn := CreateRectRgn(-32767, -32767, 32767, 32767);
    CheckRgn(CombineRgn(DestRgn, DestRgn, Rgn, RGN_AND));
  end else
    CheckRgn(CombineRgn(DestRgn, DestRgn, Rgn, RGN_OR));
end;

procedure TStage.DrawForeground(DC : HDC);
var R : TRect;
    p : PProp;
    i : integer;
    ClipRgn, DestRgn, Rgn : HRgn;
begin
  if ForeProps.Count = 0 then Exit;
  ClipRgn := 0;
  for i := 0 to ForeProps.Count-1 do begin
    p := PProp(ForeProps.At(i));
    with p^ do begin
      Update(@Self);
      GetRect(R);
      { if another obj. is drawing over us, we're dirty }
      if not PropDirty then begin
        if MergedDirty^.Contains(R) then
          PropDirty := true;
      end else
        MergedDirty^.AddRect(R);
      if PropDirty then begin
        Draw(@Self);
        PropDirty := false;
      end;
    end;
  end;
end;

procedure TStage.DrawBackground(DC : HDC);
var i : integer;
    p : PProp;
    R : TRect;
    old : HBitmap;
begin
  if (BackdropBits = nil) then begin
    CheckRgn(GetClipBox(DC, R));
    FillRect(DC, R, GetStockObject(BLACK_BRUSH));
  end else begin
    with BackdropInfo^.Hdr do
      Check(StretchDIBits(DC, 0, 0, XRes, YRes, 0, 0, biWidth, biHeight, BackdropBits,
        PBitmapInfo(BackdropInfo)^, DIB_RGB_COLORS, SRCCOPY) > 0);
  end;
  if Props.Count = 0 then Exit;
  for i := 0 to Props.Count-1 do begin
    p := PProp(Props.At(i));
{    p^.GetRect(R);}
    p^.Draw(@Self);
  end;
end;

{$IFNDEF WIN32}
function LongUDiv(X: Longint; Y: Word): word; { long unsigned div }
inline ($59/$58/$5A/$F7/$F1);
function LongUMul(X: Word; Y: Word): longint; { long unsigned mul }
inline ($5A/$58/$F7/$E2);
{$ENDIF}

procedure TStage.TransCoords(var P : TPoint; var X, Y : integer);
begin
{  X := integer(LongUDiv(LongUMul(P.X-ViewOrg.X, XRes), ViewSize.X));
  Y := integer(LongUDiv(LongUMul(P.Y-ViewOrg.Y, YRes), ViewSize.Y));}
  X := (longint(P.X)-ViewOrg.X)*XRes div ViewSize.X;
  Y := (longint(P.Y)-ViewOrg.Y)*YRes div ViewSize.Y;
end;

procedure TStage.ScreenToStage(var P : TPoint);
begin
  P.X := integer(longint(P.X)*ViewSize.X div XRes);
  P.Y := integer(longint(P.Y)*ViewSize.Y div YRes);
end;

procedure TStage.SendMessage(Command, wParam : word; lParam : longint);
var i : integer;
begin
  if Objs.Count > 0 then for i := 0 to Objs.Count-1 do
    PPlayer(Objs.At(i))^.Message(Command, wParam, lParam);
  if NewObjs.Count > 0 then for i := 0 to NewObjs.Count-1 do
    PPlayer(NewObjs.At(i))^.Message(Command, wParam, lParam);
end;

procedure TStage.Add(p : PPlayer);
begin
  NewObjs.Insert(p);
end;


(* COSTUMES -- Things for the players to wear *)


procedure TCostume.Draw;
begin
end;

procedure TCostume.DrawMask;
begin
end;

procedure TCostume.GetRect;
var w,h : integer;
begin
  {$IFDEF WIN32}
  w := (Size.X*sX) shr 8;
  h := (Size.Y*sY) shr 8;
  {$ELSE}
  w := LongMulShr8(Size.X, sX);
  h := LongMulShr8(Size.Y, sY);
  {$ENDIF}
  R.left := X-w shr 1;
  R.right := R.left+w;
  R.top := Y-h shr 1;
  R.bottom := R.top+h;
end;

function MakeMask(DC : HDC; BitsPtr : pointer; var Info : TBitmapInfo)
  : HBitmap;
{ changes 24-bit DIB to 1-bit mask }
type TRGBArr = array[0..$fff] of TRGBTriple;
     PRGBArr = ^TRGBArr;
     {$IFDEF WIN32}
     TLongArr = array[0..$ffffff] of longint;
     PLongArray = ^TLongArr;
     {$ENDIF}
var
  x, x2, y : integer;
  Width, Height : integer;
  LineWidth : word;
  DestSize : word;
  Dest : pointer;
  Mask : HBitmap;
  MaskInfo : TBitmap;
  a : longint;
begin
  Width := info.bmiHeader.biWidth;
  Height := info.bmiHeader.biHeight;
  LineWidth := (((Width * info.bmiHeader.biBitCount) + 31) div 32) * 4;
  Mask := CreateBitmap(Width, Height, 1, 1, nil);
  if Mask = 0 then begin
    MakeMask := 0; Exit;
  end;
  GetObject(Mask, sizeof(MaskInfo), @MaskInfo);
  DestSize := MaskInfo.bmWidthBytes*MaskInfo.bmHeight;
  GetMem(Dest, DestSize);
  if Dest <> nil then begin
    for y := 0 to Height-1 do begin
    {$IFDEF WIN32}
      a := 0;
      for x := 0 to Width-1 do begin
        if (PChar(BitsPtr)+(Height-y)*MaskInfo.bmWidthBytes+x)^ >= #2 then
          a := a or (1 shl (x and 31));
        if (x and 31) = 31 then begin
          PLongArray(Dest)^[x shr 5] := a;
          a := 0;
        end;
      end;
    {$ELSE}
      asm
        mov   cx,y
        mov   ax,MaskInfo.bmWidthBytes
        mul   cx
        les   di,Dest
        add   di,ax  { get offset into dest. mask }

        mov   cx,Height
        sub   cx,y
        dec   cx
        mov   ax,LineWidth
        mul   cx
        mov   cx,Width
        push  ds
        lds   si,BitsPtr  { get ofs into src. DIB }
        add   si,ax
        mov   bx,ds
        adc   dx,0        { number of segments to add }
        mov   ax,dx
        mov   dx,offset AHIncr
        mul   dl
        add   bx,ax       { ... and add segment }
        mov   ds,bx

        mov   dh,8
      @@loop:
        mov   al,[si]
        inc   si
        je    @@4
        cmp   al,2      { if color is >= 2, put a dot in the mask }
        cmc
        rcl   dl,1
        dec   dh
        je    @@2
        loop  @@loop
        mov   cl,dh
        sal   dl,cl
        mov   [es:di],dl
        jmp   @@3
      @@4:
        mov   bx,ds
        add   bx,offset AHIncr
        mov   ds,bx
      @@2:
        mov   [es:di],dl
        inc   di
        mov   dh,8
        loop  @@loop
      @@3:
        pop   ds
      end;
      {$ENDIF}
    end;
    SetBitmapBits(Mask, DestSize, Dest);
    FreeMem(Dest, DestSize);
    MakeMask := Mask;
  end else begin
    DeleteObject(Mask);
    MakeMask := 0;
  end;
end;

procedure ShiftHue(var cols; numcols, hue : word);
{$IFNDEF WIN32}
assembler;
asm
  les   di,cols
@@1:
  mov   ax,[es:di]
  mov   dl,[es:di+2]
  mov   cx,hue
  cmp   cx,18h
  jb    @@11
  sub   cx,18h
  xchg  dl,al
@@11:
  jcxz  @@noshift
@@2:
  shl   ax,1
  rcl   dl,1
  adc   al,0
  loop  @@2
@@noshift:
  stosw
  mov   al,dl
  stosb
  inc   di
  dec   numcols
  jnz   @@1
end;
{$ELSE}
begin
end;
{$ENDIF}

type
  TYTable = array[0..$3ff0] of pointer;
  PSpriteHdr = ^TSpriteHdr;
  TSpriteHdr = record
    w,h : cardinal;
    siz : longint;
  end;
  PSpriteRec = ^TSpriteRec;
  TSpriteRec = record
    hdr : TSpriteHdr;
    ytable : TYTable;
  end;
const
  SpriteHdrSize = sizeof(TSpriteHdr);

procedure SpriteDraw(Stage : PStage; Src, Dest : pointer; DestX, DestY,
  SrcY, SrcHeight : integer);
var
  dp,sp : PByte;
  dofs,sofs : longint;
  rec : PSpriteRec;
  cnt,a,x,leftx,rightx : integer;
  doesclip : boolean;
begin
  rec := Src;
  { Q&D X clip }
  with PSpriteHdr(Src)^ do begin
    leftx := IMax(0, -DestX);
    rightx := IMin(w, Stage^.XRes-DestX);
    doesclip := (DestX < 0) or (DestX+w >= Stage^.ByteWidth);
  end;
  { Y clip from top }
  if (DestY < 0) then begin
    inc(SrcHeight, DestY);
    dec(SrcY, DestY);
    DestY := 0;
  end else
  { Y clip from bottom }
  if (DestY+SrcHeight > Stage^.YRes) then
    SrcHeight := Stage^.YRes-DestY;

  dp := Stage^.BackBits;
  while (SrcHeight > 0) do begin
    dofs := Stage^.ylut^[DestY]+DestX;
    sp := rec^.ytable[SrcY];
    x := 0;
      repeat
        { skip n bytes }
        cnt := sp^;
        inc(sp);
        inc(x, cnt);
        { copy n bytes, or exit if n = 0 }
        cnt := sp^;
        inc(sp);
        if cnt = 255 then Break;

        if (x < leftx) then { perform left clip }
        begin
          if (x+cnt > leftx) then
            Move32(PtrRec(sp).Seg, PtrRec(dp).Seg,
              PtrRec(sp).Ofs+(leftx-x), dofs+leftx, cnt-(leftx-x));
        end
        else if (x+cnt > rightx) then { perform right clip }
        begin
          if (x < rightx) then
            Move32(PtrRec(sp).Seg, PtrRec(dp).Seg, PtrRec(sp).Ofs, dofs+x, rightx-x);
        end
        else { no clip }
          Move32(PtrRec(sp).Seg, PtrRec(dp).Seg, PtrRec(sp).Ofs, dofs+x, cnt);

        inc(sp, cnt);
        inc(x, cnt);
      until false;
    inc(SrcY);
    inc(DestY);
    dec(SrcHeight);
  end;
end;

procedure SpriteDrawMask(Stage : PStage; Src, Dest : pointer; DestX, DestY,
  SrcY, SrcHeight : integer; Color : TColorRef);
var
  dp,sp : PByte;
  dofs,sofs : longint;
  rec : PSpriteRec;
  cnt,a,x,leftx,rightx : integer;
  fillbyte : byte;
  fill : longint;
begin
  rec := Src;
  fillbyte := ClosestRGBtoIndex(TPaletteEntry(Color));
  with PSpriteHdr(Src)^ do begin
    leftx := IMax(0, -DestX);
    rightx := IMin(w, Stage^.XRes-DestX);
  end;
  if (DestY < 0) then begin
    inc(SrcHeight, DestY);
    dec(SrcY, DestY);
    DestY := 0;
  end else
  { Y clip from bottom }
  if (DestY+SrcHeight > Stage^.YRes) then
    SrcHeight := Stage^.YRes-DestY;

  dp := Stage^.BackBits;
  while (SrcHeight > 0) do begin
    dofs := Stage^.ylut^[DestY]+DestX;
    sp := rec^.ytable[SrcY];
    x := 0;
      repeat
        { skip n bytes }
        cnt := sp^;
        inc(sp);
        inc(x, cnt);
        { copy n bytes, or exit if n = 0 }
        cnt := sp^;
        inc(sp);
        if cnt = 255 then Break;

        if (x < leftx) then { perform left clip }
        begin
          if (x+cnt > leftx) then
            Fill32(PtrRec(dp).Seg, dofs+leftx, cnt-(leftx-x), fillbyte);
        end
        else if (x+cnt > rightx) then { perform right clip }
        begin
          if (x < rightx) then
            Fill32(PtrRec(dp).Seg, dofs+x, rightx-x, fillbyte);
        end
        else { no clip }
          Fill32(PtrRec(dp).Seg, dofs+x, cnt, fillbyte);

        inc(sp, cnt);
        inc(x, cnt);
      until false;
    inc(SrcY);
    inc(DestY);
    dec(SrcHeight);
  end;
end;
(*
function ScaleSprite(SpriteData : pointer; DestW, DestH : integer) : pointer;
var
  src,dest : PSpriteRec;
  sp,dp : PByte;
  sx,sy,dx,dy : integer;
  cnt : byte;
begin
  src := PSpriteRec(SpriteData);
  dest := GlobalAllocPtr(GMEM_MOVEABLE, src^.hdr.siz);
  dest^.hdr.w := DestW;
  dest^.hdr.h := DestH;
  dp := PByte(dest);
  inc(dp, sizeof(TSpriteHdr));
  inc(dp, sizeof(pointer)*DestH); { make room for ytable }
  for dy := 0 to DestH-1 do begin
    sy := (dy*src^.hdr.h) div DestH;
    sx := 0;
    repeat
      cnt := sp^;
      inc(sp);
      inc(sx, cnt);
      dx := (sx*src^.hdr.x)
  end;
end;
*)
function MakeSpriteFromBMP(const Info : TBitmapInfo; Bits : pointer;
  bytwid : integer; upsidedown : boolean{; var Size : longint}) : pointer;
type
  TPalArr = array[0..255] of TRGBQuad;
var
  dest,repdest : PChar;
  hdr : PSpriteRec;
  i,x,y,pos : integer;
  yy : longint;
  maskrep : byte;
  maskcol : integer;
  buf : PByteArray;
  pal : ^TPalArr;
  Size : longint;

begin
  maskcol := 1;
  with info, bmiHeader do begin
    pal := @bmiColors;
    if bytwid = 0 then
      bytwid := (((biWidth*biBitCount)+31) div 32)*4;
    dest := GlobalAllocPtr(GMEM_MOVEABLE, sizeof(TSpriteHdr)+
      (bytwid+4)*longint(biHeight)+sizeof(pointer)*biHeight);
{    GetMem(dest, (bytwid+4) * biHeight * 1); { max. size of sprite }
    hdr := PSpriteRec(dest);
    hdr^.hdr.w := biWidth;
    hdr^.hdr.h := biHeight;
    inc(dest, sizeof(TSpriteHdr));
    inc(dest, sizeof(pointer)*biHeight); { make room for ytable }
    for y := 0 to biHeight-1 do
    begin
      x := 0;
      hdr^.ytable[y] := dest;
      if upsidedown then yy := y else yy := biHeight-1-y;
      {$IFDEF win32}
      buf := PByteArray(PChar(Bits) + bytwid*yy);
      {$ELSE}
      with PtrRec(Bits) do
        buf := PByteArray(PtrCvt(Seg, bytwid*yy+Ofs));
      {$ENDIF}
      repeat
        maskrep := 0;
        { *** GPF here ??? }
        { resource leak? }
        while (x < biWidth) and (maskrep < 254) and (buf^[0] <= maskcol) do
        begin
          inc(x);
          inc(maskrep);
          buf := AddSelector(buf, 1);
        end;
        byte(dest^) := maskrep; inc(dest);
        maskrep := 0;
        repdest := dest; inc(dest);
        while (x < biWidth) and (maskrep < 254) and (buf^[0] > maskcol) do
        begin
          with pal^[buf^[0]] do
            byte(dest^) := HalftoneRGBtoIndex(rgbRed, rgbGreen, rgbBlue, x, y);
          inc(x);
          inc(maskrep);
          buf := AddSelector(buf, 1);
          inc(dest);
        end;
        if (x >= biWidth) and (maskrep = 0) then begin
          byte(repdest^) := 255;
          Break;
        end;
        byte(repdest^) := maskrep;
      until false;
      {$IFNDEF win32}
      if (PtrRec(dest).ofs > $ffff-biWidth*2) then
        dest := Ptr(PtrRec(dest).Seg + SelectorInc, 0);
      {$ENDIF}
    end;
  end;
  {$IFDEF win32}
  hdr^.hdr.Siz := dest-hdr;
  {$ELSE}
  hdr^.hdr.Siz := ((Seg(dest^)-Seg(hdr^)) div SelectorInc)*$10000 + Ofs(dest^);
  {$ENDIF}
  Size := hdr^.hdr.Siz;
  Result := GlobalReallocPtr(hdr, Size, 0);
end;

constructor TBitCostume.Init(Instance : THandle; Name : PChar; DispDC : HDC;
   AFrames : integer; Hue : integer);
var SrcBit : HBitmap;
    BitmapPtr : pointer;
    BitsPtr : pointer;
    PalPtr : pointer;
    Info : PBitmapInfo;
    HRes : THandle;
    OldPal : pointer;
begin
  inherited Init;
  HRes := FindResource(Instance, Name, RT_BITMAP);
  SrcBit := LoadResource(Instance, HRes);
  if (SrcBit = 0) and (HRes <> 0) then begin
    GlobalCompact({SizeofResource(Instance, HRes)}-1);
    { compact heap, and try to load it again }
    SrcBit := LoadResource(Instance, HRes);
  end;
  BitmapPtr := LockResource(SrcBit);
  if (BitmapPtr <> nil) then begin
    Info := BitmapPtr;
    {$IFNDEF WIN32}
    BitsPtr := Ptr(PtrRec(BitmapPtr).Seg, sizeof(TBitmapInfoHeader) +
      sizeof(TRGBQuad) shl Info^.bmiHeader.biBitcount);
    PalPtr := Ptr(PtrRec(BitmapPtr).Seg, sizeof(TBitmapInfoHeader));
    {$ELSE}
    BitsPtr := PChar(BitmapPtr) + (sizeof(TRGBQuad) shl Info^.bmiHeader.biBitcount);
    PalPtr := PChar(BitmapPtr) + sizeof(TBitmapInfoHeader);
    {$ENDIF}

    if hue <> 0 then begin
      GetMem(OldPal, 1024);
      Move(PalPtr^, OldPal^, 1024);
      ShiftHue(PalPtr^, 256, $18);
      ShiftHue(PalPtr^, 256, hue mod $30);
      ShiftHue(PalPtr^, 256, $18);
    end;

    SpritePtr := MakeSpriteFromBMP(Info^, BitsPtr, 0, false);

    MemDC := CreateCompatibleDC(DispDC);
    NumFrames := AFrames;
    YDiv := 1024 div NumFrames;
    Size.X := Info^.bmiHeader.biWidth;
    Size.Y := Info^.bmiHeader.biHeight div NumFrames;
    HMask := MakeMask(MemDC, BitsPtr, Info^);
    Check(Bool(SelectObject(MemDC, HMask)));
    if hue <> 0 then begin
      Move(OldPal^, PalPtr^, 1024);
      FreeMem(OldPal, 1024);
    end;
    UnlockResource(SrcBit);
    FreeResource(SrcBit);
  end else
    Fail;
end;

destructor TBitCostume.Done;
begin
  GlobalFreePtr(SpritePtr);
  DeleteDC(MemDC);
  DeleteObject(HMask);
  inherited Done;
end;

procedure TBitCostume.Draw(Stage : PStage; X, Y, sX, sY, Rot, Frame : integer;
  ROP : longint);
var n : integer;
    R : TRect;
begin
  if Frame > 0 then n := Frame
  else n := ((Rot+(YDiv shr 1)) and 1023) div YDiv;
  GetRect(R, X, Y, sX, sY, Rot);
  if (sX = 256) and (sY = 256) then
    SpriteDraw(Stage, SpritePtr, Stage^.BackBits, R.left, R.top, n*Size.Y, Size.Y)
  else begin
    SetStretchBltMode(Stage^.GDC, STRETCH_DELETESCANS);
    Check(StretchBlt(Stage^.GDC, R.left, R.top, R.right-R.left, R.bottom-R.top,
      MemDC, 0, n*Size.Y, Size.X, Size.Y, ROP));
  end;
end;

procedure TBitCostume.DrawMask(Stage : PStage; X, Y, sX, sY, Rot, Frame : integer;
  ROP : longint);
var n : integer;
    OldBMP : HBitmap;
    R : TRect;
begin
  if Frame > 0 then n := Frame
  else n := ((Rot+(YDiv shr 1)) and 1023) div YDiv;
  GetRect(R, X, Y, sX, sY, Rot);
  if (sX = 256) and (sY = 256) then
    if Stage^.BackBits = nil then
      Check(BitBlt(Stage^.GDC, R.left, R.top, Size.X, Size.Y, MemDC, 0, n*Size.Y, ROP))
    else
      SpriteDrawMask(Stage, SpritePtr, Stage^.BackBits, R.left, R.top, n*Size.Y, Size.Y,
        GetBkColor(Stage^.GDC))
  else begin
    SetStretchBltMode(Stage^.GDC, STRETCH_DELETESCANS);
    Check(StretchBlt(Stage^.GDC, R.left, R.top, R.right-R.left, R.bottom-R.top,
      MemDC, 0, n*Size.Y, Size.X, Size.Y, ROP));
  end;
end;

(* THE PROPS -- Scenery for the stage. *)

constructor TProp.Init;
begin
  inherited Init;
  PropDirty := true;
end;

procedure TProp.Update;
begin
end;

procedure TProp.Draw(Stage : PStage);
begin
end;

procedure TProp.GetRect(var R : TRect);
begin
end;

(* THE PLAYERS -- All the world's a stage, and these are merely sprites. *)

constructor TPlayer.Init(TheStage : PStage; X, Y : integer; Cost : PCostume);
begin
  inherited Init;
  Stage := TheStage;
  Costume := Cost;
  Status := 0;
  Pos.X := X; Pos.Y := Y;
  Vel.X := 0; Vel.Y := 0;
  Size.X := 256; Size.Y := 256;
  Rot := 0; RotVel := 0;
  Frame := 0; Color := $FFFFFF;
  {$IFDEF rgncollide}
  Collision := false;
  {$ENDIF}
  HaveMoved := true;
  Setup;
end;

procedure TPlayer.Setup;
{ Optional ... setup & initialize special variables }
begin
end;

procedure TPlayer.Draw(ROP : longint);
var X, Y : integer;
    R : TRect;
    Rgn : HRgn;
begin
  if (Costume <> nil) and (Status and plyr_Cloaked = 0) then begin
    Stage^.TransCoords(Pos, X, Y);
{    Costume^.DrawMask(DC, X, Y, Size.X, Size.Y, Rot, Frame,
      SRCAND xor $FF0000);}
    if Stage^.GDC <> 0 then begin
      if (Status and plyr_MaskOnly > 0) then begin
        SetTextColor(Stage^.GDC, 0);
        SetBkColor(Stage^.GDC, Color);
        Costume^.DrawMask(Stage, X, Y, Size.X, Size.Y, Rot, Frame, ROP)
      end else
        Costume^.Draw(Stage, X, Y, Size.X, Size.Y, Rot, Frame, ROP);
    end;
    if (Status and plyr_NoRgnAdd = 0) then begin
      GetRect(R);
      {$IFDEF rgncollide}
      Collision := false;
      if (Status and plyr_Invulnerable = 0) and
        (ord(RectInRegion(Stage^.DrawRgn, R)) <> 0) then
      begin
        Collision := true;
      end;
      {$ENDIF}
      Stage^.Dirty^.AddRect(R);
    end;
  end;
end;

procedure TPlayer.DrawMask(ROP : longint);
var X, Y : integer;
begin
  if (Costume <> nil) then begin
    Stage^.TransCoords(Pos, X, Y);
    Costume^.DrawMask(Stage, X, Y, Size.X, Size.Y, Rot, 0, ROP);
  end;
end;

procedure TPlayer.Move;
{ Moves the player, but does nothing else . . . should be fast as possible. }
begin
  inc(Pos.X, Vel.X);
  inc(Pos.Y, Vel.Y);
  inc(Rot, RotVel);
  with Stage^ do begin
    if (Status and plyr_WrapAroundX > 0) then begin
      if Pos.X < ViewOrg.X then inc(Pos.X, ViewSize.X)
      else if Pos.X > ViewOrg.X+ViewSize.X then dec(Pos.X, ViewSize.X);
    end;
    if (Status and plyr_WrapAroundY > 0) then begin
      if Pos.Y < ViewOrg.Y then inc(Pos.Y, ViewSize.Y)
      else if Pos.Y > ViewOrg.Y+ViewSize.Y then dec(Pos.Y, ViewSize.Y);
    end;
  end;
  HaveMoved := true;
end;

procedure TPlayer.Cue;
{ Stage cues . . . strategy, change of velocity, whatever. }
begin
end;

procedure TPlayer.Update;
{ Move him and draw him. }
begin
  if Status and plyr_Cloaked = 0 then Draw(SRCPAINT);
  if Status and plyr_Frozen = 0 then Move;
end;

procedure TPlayer.GetRect(var R : TRect);
var X, Y : integer;
begin
  if HaveMoved then begin
    Stage^.TransCoords(Pos, X, Y);
    { *** GPF HERE DURING NETPLAY *** }
    Costume^.GetRect(R, X, Y, Size.X, Size.Y, Rot);
    LastGetRect := R;
    HaveMoved := false;
  end else begin
    R := LastGetRect;
  end;
end;

function TPlayer.ChkCollide : boolean;
{ Is the player ALLOWED TO collide? }
begin
  ChkCollide := (Status and (plyr_Dead or plyr_Invulnerable) = 0);
end;

function IsEmpty(p : pointer; size : cardinal) : boolean; assembler;
{ NOTE : SIZE parameter must be EVEN! }
{$IFDEF WIN32}
asm
  mov   edi,p
  mov   ecx,size
  xor   eax,eax
  shr   cx,1
  repz  scasw
  jne   @@1
  inc   eax
@@1:
end;
{$ELSE}
asm
  les   di,p
  mov   cx,size
  xor   ax,ax
  shr   cx,1
  repz  scasw
  jne   @@1
  inc   ax
@@1:
end;
{$ENDIF}

function TPlayer.Collide(p : PPlayer) : boolean;
{ Check for collision both ways }
var DC, OldDC, DispDC : HDC;
    DCStage : TStage;
    X,Y : integer;
    OldBitmap, Test : HBitMap;
    R1, R2 : TRect;
    Info : TBitmap;
    Buf : pointer;
    siz : word;
begin
  Collide := false;
  if {$IFDEF rgncollide} (Collision or p^.Collision) and {$ENDIF}
    ChkCollide and p^.ChkCollide then
  begin
    {$IFDEF profile}inc(ProfStats.TotalTests);{$ENDIF}
    { see if it's there, and if there's any CHANCE of a collision }
    if word(abs(Pos.X-p^.Pos.X)+abs(Pos.Y-p^.Pos.Y)) > $2000 then
      Exit;
    {$IFDEF profile}inc(ProfStats.RectTests);{$ENDIF}
    { now test the 2 rectangles }
    GetRect(R1);
    p^.GetRect(R2);
    if Bool(IntersectRect(R1, R1, R2)) then begin
      {$IFDEF testcoll}Result := true; Exit;{$ENDIF}
      {$IFDEF profile}inc(ProfStats.BitmapTests);{$ENDIF}
    { find the common rectangle between the two }
      {$IFDEF diag}
      MessageBeep($FFFF);
      DispDC := CreateDC('DISPLAY', nil, nil, nil);
      {$ENDIF}
      Test := CreateBitmap(R1.right-R1.left, R1.bottom-R1.top, 1, 1, nil);
      if (Test <> 0) and (GetObject(Test, sizeof(Info), @Info) > 0) then
      begin
       siz := (Info.bmWidthBytes*Info.bmHeight+1) and (not 1);
       GetMem(Buf, siz);
       if Buf <> nil then begin
        FillChar(Buf^, siz, 0);
        SetBitmapBits(Test, siz, Buf);
        { clear the test bitmap buffer so no extraneous crap on the edges }

        DC := Stage^.TempDC;
        OldBitmap := SelectObject(DC, Test);

        SetWindowOrgEx(DC, R1.left, R1.top, nil);

        { draw the 1st object AND'ed with the 2nd }
        DCStage.GDC := DC;
        DCStage.BackBits := nil;
        Stage^.TransCoords(Pos, X, Y);
        Costume^.DrawMask(@DCStage, X, Y, Size.X, Size.Y, Rot, Frame, SRCCOPY);
        with p^ do begin
          Stage^.TransCoords(Pos, X, Y);
          Costume^.DrawMask(@DCStage, X, Y, Size.X, Size.Y, Rot, Frame, SRCAND);
        end;

        SetWindowOrgEx(DC, 0, 0, nil);
        {$IFDEF diag}
        SetRect(R2, 0, 0, 64, 64);
        FillRect(DispDC, R2, GetStockObject(GRAY_BRUSH));
        BitBlt(DispDC, 0, 0, R1.right-R1.left, R1.bottom-R1.top,
          DC, 0, 0, SRCCOPY);
        {$ENDIF}
        if GetBitmapBits(Test, siz, Buf) <> 0 then
          Collide := not IsEmpty(Buf, siz);
        { if the resulting bitmap is not empty, we've got collisionage }

        {$IFDEF diag}
{        if not IsEmpty(Buf, siz) then MessageBeep($FFFF);
        Collide := false;}
        {$ENDIF}
        SelectObject(DC, OldBitmap);
        FreeMem(Buf, siz);
       end;
      end;
      DeleteObject(Test);
      {$IFDEF diag} DeleteDC(DispDC); {$ENDIF}
    end;
  end;
end;

procedure TPlayer.Kill;
{ Kills him off -- you can override }
begin
  Status := Status or plyr_Dead;
end;

function TPlayer.Message(Command, wParam : word; lParam : longint) : longint;
begin
  Result := 0;
end;

procedure TStage.AddForeProp(Prop : PProp);
var
  R : TRect;
begin
  ForeProps.Insert(Prop);
  with Prop^ do begin
    GetRect(R);
    Dirty^.AddRect(R);
  end;
end;

procedure TStage.ClearRect(const R : TRect);
var
  NR : TRect;
begin
  Dirty^.AddRect(R);
  NR := R;
  { align to dword boundaries }
  with NR do begin
    left := left and not 3;
    right := (right+3) and not 3;
  end;
  BackToBkgndCopy(NR);
end;

procedure TStage.ClearForeProp(Prop : PProp);
var
  R : TRect;
begin
  if ForeProps.IndexOf(Prop) < 0 then
    Exit;
  with Prop^ do
  begin
    GetRect(R);
    if Bool(IntersectRect(R, ScreenRect, R)) and not IsRectEmpty(R) then
      ClearRect(R);
  end;
  ForeProps.Free(Prop);
end;

procedure TStage.ClearForeProps;
var
  i : integer;            
begin
  with ForeProps do
    while Count > 0 do
      ClearForeProp(PProp(At(Count-1)));
end;

function TStage.HasForeProp(Prop : PProp) : boolean;
begin
  Result := ForeProps.IndexOf(Prop) >= 0;
end;


