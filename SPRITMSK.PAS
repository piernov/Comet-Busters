(*********************************************************)
(**  SPRITEMSK.PAS                                      **)
(**  Sprite object library                              **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit SpritMsk;

{ $DEFINE diag}
{ $DEFINE rgncollide}

interface

uses
  Objects, WinTypes, WinProcs;

type
  UPoint = record
    X, Y : Word;
  end;

  PPlayer = ^TPlayer;

  { TSTAGE - A rectangular playfield for the Actors (sprites).
    Contains Actors, Props (background/foreground scenery),
    and controls the timing and movement of the Actors.
  }
  PStage = ^TStage;
  TStage = object(TObject)
    Objs,
    NewObjs,
    Props,
    ForeProps : TCollection;
    TempDC : HDC;
    ViewOrg : TPoint;
    ViewSize : UPoint;
    XRes, YRes : integer;
    DrawRgn, OldRgn : HRgn;
    Options : word;
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
  end;

  { TCOSTUME - a visual form for the Actors
    This is a generic object.
  }
  PCostume = ^TCostume;
  TCostume = object(TObject)
    Size : TPoint;
    procedure Draw(DC : HDC; X, Y, sX, sY, Rot, Frame : integer; ROP : longint); virtual;
    { draws the costume at a specified location, at a specified size,
      and with a specified rotation or frame #, with a specified ROP
      (raster op). }
    procedure DrawMask(DC : HDC; X, Y, sX, sY, Rot, Frame : integer; ROP : longint); virtual;
    { does the same thing, but only draws the silohuette of the shape. }
    procedure GetRect(var R : TRect; X, Y, sX, sY, Rot : integer); virtual;
    { returns the bounding rectangle of the shape, given the
      same parameters }
  end;

  { TBITCOSTUME - A costume defined as a bitmap
  }
  PBitCostume = ^TBitCostume;
  TBitCostume = object(TCostume)
    HBits, HMask : HBitmap;
    MemDC : HDC;
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
    procedure Draw(DC : HDC; X, Y, sX, sY, Rot, Frame : integer; ROP : longint); virtual;
    procedure DrawMask(DC : HDC; X, Y, sX, sY, Rot, Frame : integer; ROP : longint); virtual;
  end;

  { TPROP - A background or foreground static object.
    Props must remain in a fixed position.
  }
  PProp = ^TProp;
  TProp = object(TObject)
{    constructor Init;}
    procedure Update(DC : HDC); virtual;
    { This procedure is called every frame the prop is onscreen.
      If the visual appearance of the prop should change, it should
      be reflected here. }
    procedure Draw(DC : HDC); virtual;
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
    procedure Draw(DC : HDC; ROP : longint); virtual;
    procedure DrawMask(DC : HDC; ROP : longint); virtual;
    procedure Move; virtual;
    procedure Cue; virtual;
    procedure Update(DC : HDC);
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

function AddRgn(var DestRgn : HRgn; Rgn : HRgn) : HRgn;
{ OR's the region RGN with DESTRGN and stores the result in
  DESTRGN. Returns RGN. }
procedure ShiftHue(var cols; numcols, hue : word);
{ Shifts an array of TRGBTRIPLEs by HUE degrees ($100 = 90 degrees) }

implementation

uses IMath;

procedure AHIncr; far; external 'KERNEL' index 114;

procedure Check(b : Bool);
{ Checks the result of a Windows function.
  If zero, gives runtime error when R+. }
{$IFOPT R+}
begin
  if not b then RunError(217);
end;
{$ELSE}
inline($58); { POP AX -- in other words, do nothing }
{$ENDIF}

procedure CheckRgn(res : integer);
{$IFOPT R+}
begin
  if res = ERROR then RunError(218);
end;
{$ELSE}
inline($58); { POP AX }
{$ENDIF}

constructor TStage.Init;
var DC : HDC;
begin
  Objs.Init(64, 64);
  NewObjs.Init(64, 64);
  Props.Init(0, 32);
  ForeProps.Init(0, 32);
  DrawRgn := 0; OldRgn := 0;
  DC := CreateDC('DISPLAY', nil, nil, nil);
  TempDC := CreateCompatibleDC(DC);
  Check(Bool(TempDC));
  Check(DeleteDC(DC));
end;

procedure TStage.SetViewingArea;
begin
  ViewOrg.X := X1;
  ViewOrg.Y := Y1;
  ViewSize.X := word(X2-X1);
  ViewSize.Y := word(Y2-Y1);
  XRes := XS;
  YRes := YS;
end;

destructor TStage.Done;
begin
  ForeProps.Done;
  Props.Done;
  NewObjs.Done;
  Objs.Done;
  if DrawRgn <> 0 then
    Check(DeleteObject(DrawRgn));
  Check(DeleteDC(TempDC));
  inherited Done;
end;

procedure TStage.Clear;
begin
  ForeProps.FreeAll;
  Props.FreeAll;
  NewObjs.FreeAll;
  Objs.FreeAll;
end;

procedure TStage.Show(DC : HDC);
var i : integer;
    R : TRect;
begin
  CheckRgn(SelectClipRgn(DC, 0));
  { draw the background }
  DrawBackground(DC);
  { draw the players }
  if Objs.Count > 0 then
    for i := 0 to Objs.Count-1 do
      PPlayer(Objs.At(i))^.Draw(DC, SRCCOPY);
  { draw the foreground props }
  if ForeProps.Count > 0 then
    for i := 0 to ForeProps.Count-1 do
      PProp(ForeProps.At(i))^.Draw(DC);
end;

procedure TStage.Update(DC : HDC);
{ Does a frame of the act }
var i : integer;
begin
  OldRgn := DrawRgn;
  DrawRgn := 0;

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

  DrawForeground(DC);

  if Objs.Count > 0 then for i := 0 to Objs.Count-1 do
    PPlayer(Objs.At(I))^.Update(DC);         { update all players }
  if Props.Count > 0 then for i := 0 to Props.Count-1 do
    PProp(Props.At(i))^.Update(DC);          { update all props }

  { Clip to the (last region - this region) and draw the background.
    This erases the junk left behind when the players move }
  if OldRgn > 0 then begin
    CheckRgn(CombineRgn(OldRgn, OldRgn, DrawRgn, RGN_DIFF));
    CheckRgn(SelectClipRgn(DC, OldRgn));
    DrawBackground(DC);
    CheckRgn(SelectClipRgn(DC, 0));
    Check(DeleteObject(OldRgn));
  end;

  if Objs.Count > 0 then begin
    for i := 0 to Objs.Count-1 do
      PPlayer(Objs.At(I))^.Cue;           { give players their cues }

  end;
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
    p^.Update(DC);
    p^.GetRect(R);
    Rgn := CreateRectRgnIndirect(R);
    Check(Bool(Rgn));
    AddRgn(DrawRgn, Rgn);
    Check(DeleteObject(Rgn));
  end;
  if DrawRgn <> 0 then begin
    GetClipBox(DC, R);
    ClipRgn := CreateRectRgnIndirect(R);
    Check(Bool(ClipRgn));
    CheckRgn(CombineRgn(ClipRgn, ClipRgn, DrawRgn, RGN_DIFF));
    CheckRgn(SelectClipRgn(DC, ClipRgn));
    Check(DeleteObject(ClipRgn));
  end;
end;

procedure TStage.DrawBackground(DC : HDC);
var i : integer;
    p : PProp;
    R : TRect;
    First : boolean;
    Rgn : HRgn;
begin
  First := true;
  CheckRgn(GetClipBox(DC, R));
  FillRect(DC, R, GetStockObject(BLACK_BRUSH));
  if Props.Count = 0 then Exit;
  for i := 0 to Props.Count-1 do begin
    p := PProp(Props.At(i));
    p^.GetRect(R);
    if RectVisible(DC, R) then begin
{      if First then begin
        SelectClipRgn(DC, ClipRgn);
        First := false;
      end;}
      p^.Draw(DC);
    end;
  end;
end;

function LongUDiv(X: Longint; Y: Word): word; { long unsigned div }
inline ($59/$58/$5A/$F7/$F1);
function LongUMul(X: Word; Y: Word): longint; { long unsigned mul }
inline ($5A/$58/$F7/$E2);

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
  w := LongMulShr8(Size.X, sX);
  h := LongMulShr8(Size.Y, sY);
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
var
  x, x2, y : integer;
  Width, Height : integer;
  LineWidth : word;
  DestSize : word;
  Dest : pointer;
  Mask : HBitmap;
  MaskInfo : TBitmap;
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

constructor TBitCostume.Init;
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
    BitsPtr := Ptr(PtrRec(BitmapPtr).Seg, sizeof(TBitmapInfoHeader) +
      sizeof(TRGBQuad) shl Info^.bmiHeader.biBitcount);
    PalPtr := Ptr(PtrRec(BitmapPtr).Seg, sizeof(TBitmapInfoHeader));
    if hue <> 0 then begin
      GetMem(OldPal, 1024);
      Move(PalPtr^, OldPal^, 1024);
      ShiftHue(PalPtr^, 256, $18);
      ShiftHue(PalPtr^, 256, hue mod $30);
      ShiftHue(PalPtr^, 256, $18);
    end;

    MemDC := CreateCompatibleDC(DispDC);
    Check(Bool(MemDC));
    NumFrames := AFrames;
    YDiv := 1024 div NumFrames;
    Size.X := Info^.bmiHeader.biWidth;
    Size.Y := Info^.bmiHeader.biHeight div NumFrames;
    HBits := CreateDIBitmap(DispDC, Info^.bmiHeader, CBM_INIT, BitsPtr,
      Info^, 0);
    HMask := MakeMask(MemDC, BitsPtr, Info^);
{    HMask := CreateBitmap(Info^.bmiHeader.biWidth, Info^.bmiHeader.biHeight,
      1, 1, nil);
    SetDIBits(MemDC, HMask, 0, Info^.bmiHeader.biHeight,
      BitsPtr, Info^, DIB_RGB_COLORS);}
    if hue <> 0 then begin
      Move(OldPal^, PalPtr^, 1024);
      FreeMem(OldPal, 1024);
    end;
    UnlockResource(SrcBit);
    FreeResource(SrcBit);
    if HBits > 0 then SelectObject(MemDC, HBits)
    else Fail;
  end else
    Fail;
end;

destructor TBitCostume.Done;
begin
  Check(DeleteDC(MemDC));
  Check(DeleteObject(HBits));
  Check(DeleteObject(HMask));
  inherited Done;
end;

procedure TBitCostume.Draw(DC : HDC; X, Y, sX, sY, Rot, Frame : integer;
  ROP : longint);
var n : integer;
    R : TRect;
begin
  if Frame > 0 then n := Frame
  else n := ((Rot+(YDiv shr 1)) and 1023) div YDiv;
  GetRect(R, X, Y, sX, sY, Rot);
  if (sX = 256) and (sY = 256) then
    Check(BitBlt(DC, R.left, R.top, Size.X, Size.Y, MemDC, 0, n*Size.Y, ROP))
  else begin
    SetStretchBltMode(DC, COLORONCOLOR);
    Check(StretchBlt(DC, R.left, R.top, R.right-R.left, R.bottom-R.top,
      MemDC, 0, n*Size.Y, Size.X, Size.Y, ROP));
  end;
end;

procedure TBitCostume.DrawMask(DC : HDC; X, Y, sX, sY, Rot, Frame : integer;
  ROP : longint);
var n : integer;
    NewDC : HDC;
    OldBMP : HBitmap;
    R : TRect;
begin
{  NewDC := CreateCompatibleDC(DC);}
  OldBMP := SelectObject(MemDC, HMask);
  NewDC := MemDC;
  if Frame > 0 then n := Frame
  else n := ((Rot+(YDiv shr 1)) and 1023) div YDiv;
  GetRect(R, X, Y, sX, sY, Rot);
  if (sX = 256) and (sY = 256) then
    Check(BitBlt(DC, R.left, R.top, Size.X, Size.Y, NewDC, 0, n*Size.Y, ROP))
  else begin
    SetStretchBltMode(DC, COLORONCOLOR);
    Check(StretchBlt(DC, R.left, R.top, R.right-R.left, R.bottom-R.top,
      NewDC, 0, n*Size.Y, Size.X, Size.Y, ROP));
  end;
{  DeleteDC(NewDC);}
  SelectObject(MemDC, OldBMP);
end;

(* THE PROPS -- Scenery for the stage. *)

procedure TProp.Update;
begin
end;

procedure TProp.Draw(DC : HDC);
begin
end;

procedure TProp.GetRect(var R : TRect);
begin
end;

(* THE PLAYERS -- All the world's a stage, and these are merely sprites. *)

constructor TPlayer.Init(TheStage : PStage; X, Y : integer; Cost : PCostume);
begin
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

procedure TPlayer.Draw(DC : HDC; ROP : longint);
var X, Y : integer;
    R : TRect;
    Rgn : HRgn;
begin
  if (Costume <> nil) and (Status and plyr_Cloaked = 0) then begin
    Stage^.TransCoords(Pos, X, Y);
{    Costume^.DrawMask(DC, X, Y, Size.X, Size.Y, Rot, Frame,
      SRCAND xor $FF0000);}
    if DC <> 0 then begin
      if (Status and plyr_MaskOnly > 0) then begin
        SetTextColor(DC, 0);
        SetBkColor(DC, Color);
        Costume^.DrawMask(DC, X, Y, Size.X, Size.Y, Rot, Frame, ROP)
      end else
        Costume^.Draw(DC, X, Y, Size.X, Size.Y, Rot, Frame, ROP);
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
      Rgn := CreateRectRgnIndirect(R);
      Check(Bool(Rgn));
      AddRgn(Stage^.DrawRgn, Rgn);
      Check(DeleteObject(Rgn));
    end;
  end;
end;

procedure TPlayer.DrawMask(DC : HDC; ROP : longint);
var X, Y : integer;
begin
  if (Costume <> nil) then begin
    Stage^.TransCoords(Pos, X, Y);
    Costume^.DrawMask(DC, X, Y, Size.X, Size.Y, Rot, 0, ROP);
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

procedure TPlayer.Update(DC : HDC);
{ Move him and draw him. }
begin
  if Status and plyr_Cloaked = 0 then Draw(DC, SRCCOPY);
  if Status and plyr_Frozen = 0 then Move;
end;

procedure TPlayer.GetRect(var R : TRect);
var X, Y : integer;
begin
  if HaveMoved then begin
    Stage^.TransCoords(Pos, X, Y);
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

function IsEmpty(p : pointer; size : word) : boolean; assembler;
{ NOTE : SIZE parameter must be EVEN! }
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

function TPlayer.Collide(p : PPlayer) : boolean;
{ Check for collision both ways }
var DC, DispDC : HDC;
    OldBitmap, Test : HBitMap;
    R1, R2 : TRect;
    Info : TBitmap;
    Buf : pointer;
    siz : word;
begin
  Collide := false;
  if {$IFDEF rgncollide} (Collision or p^.Collision) and {$ENDIF}
    ChkCollide and p^.ChkCollide then begin
  { see if it's there, and if there's any CHANCE of a collision }
    GetRect(R1);
    p^.GetRect(R2);
    if IntersectRect(R1, R1, R2) <> 0 then begin
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

        SetWindowOrg(DC, R1.left, R1.top);
        DrawMask(DC, SRCCOPY);
        p^.DrawMask(DC, SRCAND);

        { draw the 1st object AND'ed with the 2nd }
        SetWindowOrg(DC, 0, 0);
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
assembler;
{ For passing controls, etc. }
asm
  xor   ax,ax
  mov   dx,ax
end;

end.

