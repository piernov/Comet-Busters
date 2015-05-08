unit Leakfind;

interface

uses
  Objects, WinTypes, WinG;

function CreateDC(DriverName, DeviceName, OutPut: PChar; InitData: Pointer): HDC;
function CreateCompatibleDC(DC: HDC): HDC;
function GetDC(Wnd: HWnd): HDC;
function ReleaseDC(Wnd: HWnd; DC: HDC): Integer;
function DeleteDC(DC: HDC): Bool;

function WinGCreateDC : HDC;
function WinGCreateBitmap(WinGDC:hDC; pHeader:pBitmapInfo; ppBits:pointer):hBitmap;
function CreateBitmap(Width, Height: Integer; Planes, BitCount: Byte;  Bits: Pointer): HBitmap;
function CreateCompatibleBitmap(DC: HDC; Width, Height: Integer): HBitmap;
function CreateDIBitmap(DC: HDC; var InfoHeader: TBitmapInfoHeader; dwUsage: LongInt; InitBits:
  PChar; var InitInfo: TBitmapInfo; wUsage: Word): HBitmap;
function DeleteObject(Handle: THandle): Bool;

implementation

{$I-}

uses
  WinProcs, SysUtils;

type
  TGDITypes = (gdi_DC, gdi_Bitmap);
const
  GDINames : array[TGDITypes] of PChar = ('DC', 'Bitmap');
var
  Created : array[TGDITypes] of integer;
  HandlesUsed : TCollection;

var
  adds : string;
procedure Log(const S : String);
var
  f : text;
begin
  Assign(f, 'gdi.log');
  Append(f);
  if adds <> '' then begin
    Writeln(f, S, '; ', adds);
    adds := '';
  end else
    Writeln(f, S);

  Close(f);
end;
procedure LogC(typ : TGDITypes; id : THandle);
begin
  if (id <> 0) then begin
    inc(Created[typ]);
    adds := Format('%ss=%d', [GDINames[typ], Created[typ]]);
    HandlesUsed.Insert(pointer(id));
  end else
    adds := '** unsuccessful';
end;
procedure LogD(typ : TGDITypes; id : THandle; destroyed : boolean);
begin
  if (destroyed) then begin
    if HandlesUsed.IndexOf(pointer(id)) >= 0 then
    begin
      dec(Created[typ]);
      adds := Format('%ss=%d', [GDINames[typ], Created[typ]]);
      HandlesUsed.Delete(pointer(id));
    end else
      adds := '** invalid handle';
  end else
    adds := '** unsuccessful';
end;

function CreateDC(DriverName, DeviceName, OutPut: PChar; InitData: Pointer): HDC;
begin
  Result := CreateDC(DriverName, DeviceName, OutPut, InitData);
  LogC(gdi_DC, Result);
  Log(Format('CreateDC(%s, ...) -> %x', [StrPas(DriverName), Result]));
end;
function CreateCompatibleDC(DC: HDC): HDC;
begin
  Result := WinProcs.CreateCompatibleDC(DC);
  LogC(gdi_DC, Result);
  Log(Format('CreateCompatibleDC(%x) -> %x', [DC, Result]));
end;
function GetDC(Wnd: HWnd): HDC;
begin
  Result := WinProcs.GetDC(Wnd);
  LogC(gdi_DC, Result);
  Log(Format('GetDC(%x) -> %x', [Wnd, Result]));
end;
function ReleaseDC(Wnd: HWnd; DC: HDC): Integer;
begin
  Result := WinProcs.ReleaseDC(Wnd, DC);
  LogD(gdi_DC, DC, Bool(Result));
  Log(Format('ReleaseDC(%x, %x) -> %x', [Wnd, DC, Result]));
end;
function DeleteDC(DC: HDC): Bool;
begin
  Result := WinProcs.DeleteDC(DC);
  LogD(gdi_DC, DC, Bool(Result));
  Log(Format('DeleteDC(%x) -> %x', [DC, integer(Result)]));
end;
function WinGCreateDC : HDC;
begin
  Result := WinG.WinGCreateDC;
  LogC(gdi_DC, Result);
  Log(Format('WinGCreateDC -> %x', [Result]));
end;
function WinGCreateBitmap(WinGDC:hDC; pHeader:pBitmapInfo; ppBits:pointer):hBitmap;
begin
  Result := WinG.WinGCreateBitmap(WinGDC, pHeader, ppBits);
  LogC(gdi_Bitmap, Result);
  Log(Format('WinGCreateBitmap(%x, %p, %p) -> %x', [WinGDC, pHeader, ppBits, Result]));
end;
function CreateBitmap(Width, Height: Integer; Planes, BitCount: Byte;  Bits: Pointer): HBitmap;
begin
  Result := WinProcs.CreateBitmap(Width, Height, Planes, BitCount, Bits);
  LogC(gdi_Bitmap, Result);
  Log(Format('CreateBitmap(%d, %d, %d, %d, %p) -> %x', [Width, Height, Planes, BitCount, Bits, Result]));
end;
function CreateCompatibleBitmap(DC: HDC; Width, Height: Integer): HBitmap;
begin
  Result := WinProcs.CreateCompatibleBitmap(DC, Width, Height);
  LogC(gdi_Bitmap, Result);
  Log(Format('CreateCompatibleBitmap(%x, %d, %d) -> %x', [DC, Width, Height, Result]));
end;
function CreateDIBitmap(DC: HDC; var InfoHeader: TBitmapInfoHeader; dwUsage: LongInt; InitBits:
  PChar; var InitInfo: TBitmapInfo; wUsage: Word): HBitmap;
begin
  Result := CreateDIBitmap(DC, InfoHeader, dwUsage, InitBits, InitInfo, wUsage);
  LogC(gdi_Bitmap, Result);
  Log(Format('CreateDIBitmap(%x, ...) -> %x', [DC, Result]));
end;
function DeleteObject(Handle: THandle): Bool;
begin
  Result := WinProcs.DeleteObject(Handle);
  LogD(gdi_Bitmap, Handle, Bool(Result));
  Log(Format('DeleteObject(%x) -> %x', [Handle, integer(Result)]));
end;

procedure NewLog;
var
  f : text;
begin
  Assign(f, 'gdi.log');
  Rewrite(f);
  Close(f);
end;

begin
  NewLog;
  HandlesUsed.Init(256, 256);
end.
