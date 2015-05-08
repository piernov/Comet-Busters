unit BMPCache;

interface

uses
  WinTypes, WinProcs, Cache, Classes;

var
  TheBMPCache : TCache;

type
  TSpriteObj = class(TObject)
    Data : pointer;
    constructor Create(AData : pointer);
    destructor Destroy; override;
  end;

implementation

constructor TSpriteObj.Create(AData : pointer);
begin
  Data := AData;
end;

destructor TSpriteObj.Destroy;
begin
  if Data <> nil then
    GlobalFreePtr(Data);
end;

var
  OldExitProc : pointer;

procedure CacheExitProc; far;
begin
  ExitProc := OldExitProc;
  TheBMPCache.Free;
end;

initialization
  (*
  OldExitProc := ExitProc;
  ExitProc := @CacheExitProc;
  *)
  TheBMPCache := TCache.Create;
  TheBMPCache.MaxEntries := 80;
end.
