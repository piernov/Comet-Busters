unit Cache;
{$Q-}

interface

uses
  Classes;

type
  TCache = class(TStringList)
    constructor Create;
    destructor Destroy; override;
  private
    Queue : TList;
    FMaxEntries : integer;
    procedure SetMaxEntries(Value : integer);
    procedure FreeLRUEntries; virtual;
  protected
    procedure FreeObject(O : TObject); virtual;
  public
    function GetObject(const S : String) : TObject;
    function AddObject(const S : String; AObject : TObject) : integer;
    property MaxEntries : integer read FMaxEntries write SetMaxEntries;
  end;

implementation

constructor TCache.Create;
begin
  inherited Create;
  Queue := TList.Create;
  Sorted := true;
end;

destructor TCache.Destroy;
var
  i : integer;
begin
  if Count > 0 then
    for i := 0 to Count-1 do
      Objects[i].Free;
  Queue.Free;
end;

procedure TCache.FreeObject(O : TObject);
begin
  O.Free;
end;

procedure TCache.FreeLRUEntries;
var
  i : integer;
begin
  while (MaxEntries > 0) and (Count >= MaxEntries) do begin
    i := Random(Count);
    FreeObject(Objects[i]);
    Delete(i);
  end;
end;

function TCache.AddObject(const S : String; AObject : TObject) : integer;
begin
  FreeLRUEntries;
  inherited AddObject(S, AObject);
end;

procedure TCache.SetMaxEntries(Value : integer);
begin
  FMaxEntries := Value;
  FreeLRUEntries;
end;

function TCache.GetObject(const S : String) : TObject;
var
  i,j : integer;
begin
  if Find(S, i) then begin
    GetObject := Objects[i];
  end else
    GetObject := nil;
end;

end.
