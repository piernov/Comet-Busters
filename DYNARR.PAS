unit DynArr;
{$IFDEF FIXUNITS}
{$C FIXED PRELOAD PERMANENT}
{$ENDIF}

{$UNDEF NOWINAPI}
{$IFDEF MSDOS}
{$DEFINE NOWINAPI}
{$ENDIF}
{$IFDEF OS2}
{$DEFINE NOWINAPI}
{$ENDIF}
{$IFDEF LOCALDYNARR}
{$DEFINE NOWINAPI}
{$ENDIF}

interface

uses
  IMath, {$IFNDEF NOWINAPI}{$IFNDEF VER80}WinAPI, {$ENDIF}{$ENDIF}Objects
  {$IFDEF VER80}, WinTypes, WinProcs, Classes{$ENDIF}
  {$IFDEF hugearr}, MemHRtn{$ENDIF};

type
  DynIndex = word;

  DynArrayPtr = ^DynArray;
  DynArray = object(Objects.TObject)                   { dynamic array }
    Items : pointer;
    Count : word;
    Limit : word;
    Delta : word;
    ItemSize : word;
    constructor Init(ADelta, AItemSize : word);
    constructor Load({$IFNDEF VER80}var {$ENDIF}S : TStream);
    procedure Store({$IFNDEF VER80}var {$ENDIF}S : TStream);
    destructor Done; virtual;
    function At(Index : word) : pointer;
    procedure AtDelete(Index : word);
    procedure AtInsert(Index : word; const Item);
    procedure AtGet(Index : word; var Item);
    procedure AtPut(Index : word; const Item);
    procedure Append(const Item);
    function Next(p : pointer) : pointer;
    function ForEach(var p; var Iterator : word) : boolean;
    procedure Truncate;
    procedure DeleteAll;
    procedure SetLimit(ALimit : word);
    function GetNewLimit : word;
    procedure MoveItems(SrcIndex, DestIndex, NumItems : word);
    constructor Clone(const Source : DynArray);
    {$IFNDEF NOWINAPI}
    procedure Fix;
    procedure Unfix;
    {$ENDIF}
  private
    ItemsPerSeg : word;
  {$IFNDEF NOWINAPI}
    HMem : THandle;
  {$ENDIF}
    function GetAllocSize(NumItems : word) : longint;
  end;
  DynSortArrayPtr = ^DynSortArray;
  DynSortArray = object(DynArray)
    function Compare(const v1, v2) : integer; virtual;
    function Search(const Item; var Index : word) : boolean;
    function Insert(const Item) : word;
    function Replace(var Item) : word;
    procedure QuickSort;
    procedure ShellSort;
 end;
  DynStrArrayPtr = ^DynStrArray;
  DynStrArray = object(DynSortArray)
    function Compare(const v1, v2) : integer; virtual;
    destructor Done; virtual;
    {$IFDEF VER80}
    constructor Load({$IFNDEF VER80}var {$ENDIF}S : TStream);
    procedure Store({$IFNDEF VER80}var {$ENDIF}S : TStream);
    {$ENDIF}
  end;
  DynQueuePtr = ^DynQueue;
  DynQueue = object(DynArray)
    Head, Tail : integer;
    constructor Init(AQueueSize, AItemSize : word);
    function Put(const AItems; NumItems : integer) : boolean;
    function Get(var AItems; NumItems : integer) : boolean;
    function Peek(var AItems; NumItems : integer) : boolean;
    function Skip(NumItems : integer) : boolean;
    function ItemCount : integer;
    procedure Clear;
  end;

implementation

uses
  Strings;

{$IFNDEF NOWINAPI}
const
  GHND = gmem_Moveable or gmem_ZeroInit;
{$ENDIF}

constructor DynArray.Init(ADelta, AItemSize : word);
begin
  inherited Init;
  Delta := ADelta; ItemSize := AItemSize;
  Limit := 0; Count := 0;
  Items := nil;
  ItemsPerSeg := {$IFDEF hugearr}$10000{$ELSE}$FFF0{$ENDIF} div ItemSize;
  {$IFNDEF NOWINAPI}
  HMem := 0;
  {$ENDIF}
end;

procedure DynArray.Store({$IFNDEF VER80}var {$ENDIF}S : TStream);
var
  i : word;
  p : pointer;
begin
  S.Write(Count, 6);
  S.Write(ItemSize, 4);
  i := 0;
  while ForEach(p, i) do
    S.Write(p^, ItemSize);
end;

constructor DynArray.Load({$IFNDEF VER80}var {$ENDIF}S : TStream);
var
  Lim : word;
  I,j : word;
  p : pointer;
begin
  S.Read(Count, 6);
  S.Read(ItemSize, 4);
  Items := nil;
  Lim := Limit;
  Limit := 0;
  {$IFDEF NOWINAPI}
  {$ELSE}
  HMem := 0;
  {$ENDIF}
  SetLimit(Lim);
  (*
  i := 0;
  while ForEach(p, i) do
    S.Read(p^, ItemSize);
  *)
  i := 0;
  while i < Count do begin
    p := At(i);
    j := IMin(ItemsPerSeg, Count-i);
    S.Read(p^, j*ItemSize);
    inc(i,j);
  end;
end;

destructor DynArray.Done;
begin
  DeleteAll;
  inherited Done;
end;

function DynArray.GetAllocSize(NumItems : word) : longint; assembler;
asm
    les  bx,Self
    xor  si,si
    mov  ax,NumItems
    xor  dx,dx
    div  es:[bx+ItemsPerSeg]    { find out which segment it's in }
    xchg ax,dx                  { quotient = segment, remainder = offset }
    push dx
    mul  es:[bx+ItemSize]    { now find segment offset }
    pop  dx
end;

{$IFNDEF NOWINAPI}
procedure MoveSegs(Src, Dest : THandle; Size : longint);
begin
  while Size > 0 do begin
    if Size >= $10000 then begin
      asm
        push ds
        mov  ds,Src
        xor  si,si
        mov  es,Dest
        xor  di,di
        mov  cx,8000h
        cld
        rep  movsw
        pop  ds
      end;
      dec(Size, $10000);
      inc(Src, SelectorInc);
      inc(Dest, SelectorInc);
    end else begin
      asm
        push ds
        mov  ds,Src
        xor  si,si
        mov  es,Dest
        xor  di,di
        mov  cx,word ptr Size
        shr  cx,1
        cld
        rep  movsw
        pop  ds
      end;
      Size := 0;
    end;
  end;
end;
{$ENDIF}

procedure DynArray.SetLimit(ALimit : word);
var NewItems : pointer;
    {$IFDEF DPMI}
    HNewMem : THandle;
    {$ENDIF}
begin
  if ALimit < Count then ALimit := Count;
  if ALimit <> Limit then begin
    {$IFDEF NOWINAPI}
    if Limit = 0 then begin
      GetMem(Items, GetAllocSize(ALimit));
      {$IFOPT R+}
      if Items = nil then RunError(214);
      {$ENDIF}
    end else begin
      if ALimit > 0 then begin
        GetMem(NewItems, GetAllocSize(ALimit));
        {$IFOPT R+}
        if NewItems = nil then RunError(214);
        {$ENDIF}
        Move(Items^, NewItems^, GetAllocSize(Limit));
      end;
      FreeMem(Items, GetAllocSize(Limit));
      Items := NewItems;
    end;
    if ALimit = 0 then Items := nil;
    {$ELSE}
    if HMem = 0 then begin
      HMem := GlobalAlloc(GHND, GetAllocSize(ALimit));
    end else begin
      GlobalUnlock(HMem);
      if ALimit = 0 then
        HMem := GlobalFree(HMem)
      else begin
        {$IFNDEF DPMI}
        HMem := GlobalRealloc(HMem, GetAllocSize(ALimit), GHND);
        {$ELSE}
        { *** bug to get around crappy DPMI!!! }
        HNewMem := GlobalAlloc(GHND, GetAllocSize(ALimit));
        if ALimit > Limit then
          MoveSegs(HMem, HNewMem, GetAllocSize(Limit))
        else
          MoveSegs(HMem, HNewMem, GetAllocSize(ALimit));
        GlobalFree(HMem);
        HMem := HNewMem;
        {$ENDIF}
      end;
    end;
    if (HMem > 0) then begin
      Items := GlobalLock(HMem);
      if Items = nil then RunError(214);
    end else begin
      if ALimit > 0 then RunError(214);
      Items := nil;
    end;
    {$ENDIF}
    Limit := ALimit;
  end;
end;

procedure DynErr;
begin
  RunError(213);
end;

function DynArray.At(Index : word) : pointer; assembler;
asm
    les  bx,Self
    mov  ax,Index
{$IFOPT R+}
    cmp  ax,word ptr es:[bx+Count]
    jb   @@1
    call DynErr
@@1:
{$ENDIF}
    xor  si,si
    cmp  ax,es:[bx+ItemsPerSeg]
    jb   @@2
    xor  dx,dx
    div  es:[bx+ItemsPerSeg]    { find out which segment it's in }
    mov  cx,dx                  { save remainder }
    mul  SelectorInc            { compute segment }
    mov  si,ax
    mov  ax,cx
@@2:
    mul  es:[bx+ItemSize]    { now find segment offset }
    mov  dx,si
    add  ax,word ptr es:[bx+Items]
    add  dx,word ptr es:[bx+Items+2]
end;

procedure DynArray.AtGet(Index : word; var Item);
begin
  Move(At(Index)^, Item, ItemSize);
end;

procedure DynArray.AtPut(Index : word; const Item);
begin
  Move(Item, At(Index)^, ItemSize);
end;

procedure DynArray.AtInsert(Index : word; const Item);
begin
  while Count >= Limit do SetLimit(Limit+Delta);
  inc(Count);
  if Index+1 < Count then begin
    MoveItems(Index, Index+1, Count-Index-1);
  end;
  AtPut(Index, Item);
end;

procedure DynArray.AtDelete(Index : word);
begin
  if Index+1 < Count then begin
    MoveItems(Index+1, Index, Count-Index-1);
  end;
  Dec(Count);
  if (Count = 0) or (Count+Delta < Limit) then SetLimit(Count);
end;

procedure DynArray.Append(const Item);
begin
  AtInsert(Count, Item);
end;

procedure DynArray.Truncate;
begin
  SetLimit(Count);
end;

function DynArray.Next;
begin
  inc(PtrRec(p).Ofs, ItemSize);
  Next := p;
end;

function DynArray.ForEach(var p; var Iterator : word) : boolean;
{ start w/ iterator = 0 }
begin
  if Iterator < Count then begin
    pointer(p) := At(Iterator); ForEach := true;
    inc(Iterator);
  end else begin
    Iterator := 0; ForEach := false;
  end;
end;

function DynArray.GetNewLimit : word;
{ computes new limit from only delta and count }
begin
  GetNewLimit := ((Count+Delta-1) div Delta)*Delta;
end;

procedure DynArray.DeleteAll;
begin
  Count := 0;
  SetLimit(Count);
end;

{$IFNDEF NOWINAPI}
procedure DynArray.Fix;
begin
  GlobalFix(HMem);
end;

procedure DynArray.Unfix;
begin
  GlobalUnfix(HMem);
end;
{$ENDIF}

procedure DynArray.MoveItems(SrcIndex, DestIndex, NumItems : word);
{ MUST WORK! }
{$IFDEF hugearr}var i : word;{$ENDIF}
begin
  {$IFDEF hugearr}
  if SrcIndex > DestIndex then
    for i := 0 to NumItems-1 do
      Move(At(SrcIndex+i)^, At(DestIndex+i)^, ItemSize)
  else
  if SrcIndex < DestIndex then
    for i := NumItems-1 downto 0 do
      Move(At(SrcIndex+i)^, At(DestIndex+i)^, ItemSize);
  {$ELSE}
  Move(At(SrcIndex)^, At(DestIndex)^, NumItems*ItemSize);
  {$ENDIF}
end;

constructor DynArray.Clone(const Source : DynArray);
var
  i : word;
  p : pointer;
begin
  Move(Source, Self, sizeof(Source));
  Limit := 0;
  SetLimit(Source.Limit);
  i := 0;
  while Source.ForEach(p, i) do
    AtPut(i-1, p^);
end;

function DynSortArray.Compare(const v1, v2) : integer;
{ Returns > 1 if v1 > v2, 0 if v1 = v2, -1 if v1 < v2 }
begin
  Compare := 0;
end;

function DynSortArray.Search(const Item; var Index : word) : boolean;
var
  L, H : word;
  I, C: Integer;
begin
  Search := False;
  if Count = 0 then begin { if array has no items, exit w/ false }
    Index := 0;
    Exit
  end;
  I := Compare(Item, At(Count-1)^);
  if (I >= 0) then begin { first check against last item of array }
    Index := Count-ord(i = 0); Search := (i = 0);
    Exit
  end;
  L := 0;
  H := Count - 1;
  while L < H do
  begin
    asm
      mov  ax,L
      add  ax,H
      rcr  ax,1
      mov  I,ax
    end;
{    I := (L + H) shr 1;}
    C := Compare(At(I)^, Item);
{    Writeln('l: ',l,'  h: ',h,'  i: ',i,'  comp: ',c);}
    if C <= 0 then begin
      L := I + ord(I < Count-1);
      if C = 0 then begin
        Search := True;
        L := I;
        Break;
      end;
    end else begin
      H := I;
    end;
  end;
  Index := L;
end;
(*
function DynSortArray.Search(var Item; var Index : word) : boolean;
var f,l,i : integer;
    c : integer;
begin
  Search := false;
  if (Count = 0) then begin
    Index := 0; Exit;
  end;
  i := Compare(Item, At(0)^);
  if (i <= 0) then begin
    Index := 0; Search := (i = 0); Exit;
  end;
  i := Compare(Item, At(Count-1)^);
  if (i >= 0) then begin
    Index := Count-ord(i=0); Search := (i = 0); Exit;
  end;
  f := 0; l := Count-1;
  i := 0;
  while (f <> l) and (f <> l-1) do begin
    i := (f+l) shr 1;
    c := Compare(Item, At(i)^);
    if c = 0 then begin
      while (i > 0) and (Compare(Item, At(i-1)^) = 0) do
        dec(i);
      Search := true;
      Index := i;
      Exit;
    end else begin
      if c > 0 then f := i
               else l := i;
    end;
  end;
  if (i < Count) and (Compare(Item, At(i)^) > 0) then inc(i);
  Index := i;
end;
*)
function DynSortArray.Insert(const Item) : word;
var
  Index : word;
begin
  if Search(Item, Index) then inc(Index);
  AtInsert(Index, Item);
  Insert := Index;
end;

function DynSortArray.Replace(var Item) : word;
var
  Index : word;
begin
  if Search(Item, Index) then
    AtPut(Index, Item)
  else
    AtInsert(Index, Item);
  Replace := Index;
end;

procedure DynSortArray.QuickSort;
var
  tmp : pointer;

procedure srt(l,r: word);
var
  i, j : word;
  x : pointer; { pivot }
begin
  i := l; j := r;
  x := At((l+r) div 2);
  while i <= j do begin
    while (Compare(At(i)^, x^) < 0) do inc(i);
    while (Compare(x^, At(j)^) < 0) do dec(j);
    if i <= j then
    begin
      AtGet(i, tmp^);
      AtPut(i, At(j)^);
      AtPut(j, tmp^);
      inc(i); dec(j);
    end;
  end;
  if l < j then srt(l,j);
  if i < r then srt(i,r);
end;

begin
  if Count < 2 then Exit;
  GetMem(tmp, ItemSize);
  srt(0,Count-1);
  FreeMem(tmp, ItemSize);
end;

procedure DynSortArray.ShellSort;
var
  i,j,jump : word;
  fini : boolean;
  tmp : pointer;
begin
  GetMem(tmp, ItemSize);
  jump := Count-1;
  while jump > 0 do begin
    jump := jump div 2;
    repeat
      fini := true;
      for j := 0 to Count - jump - 1 do begin
        i := j + jump;
        if Compare(At(j)^, At(i)^) > 0 then begin { swap }
          AtGet(i, tmp^);
          AtPut(i, At(j)^);
          AtPut(j, tmp^);
          fini := false;
        end;
      end;
    until fini;
  end;
  FreeMem(tmp, ItemSize);
end;

function DynStrArray.Compare(const v1, v2) : integer;
begin
  Compare := StrComp(PChar(v1), PChar(v2));
end;

destructor DynStrArray.Done;
var
  i : word;
  p : ^PChar;
begin
  i := 0;
  while ForEach(p, i) do
    StrDispose(p^);
  inherited Done;
end;

{$IFDEF VER80}
procedure DynStrArray.Store({$IFNDEF VER80}var {$ENDIF}S : TStream);
const
  b : byte = 0;
var
  i,j : word;
  l : byte;
  p : ^PChar;
  cnt : word;
  buf : array[0..255] of char;
  totallen,oldpos,endpos : longint;
begin
  S.Write(Count, 6);
  oldpos := S.Position;
  S.Position := S.Position + sizeof(totallen);
  i := 0;
  totallen := 0;
  while ForEach(p, i) do begin
    l := StrLen(p^);
    if l > 0 then S.Write(p^^, l);
    S.Write(b, 1);
    inc(totallen, l+1);
  end;
  endpos := S.Position;
  S.Position := oldpos;
  S.Write(totallen, sizeof(totallen));
  S.Position := endpos;
end;

constructor DynStrArray.Load({$IFNDEF VER80}var {$ENDIF}S : TStream);
type
  PPChar = ^PChar;
var
  Lim : word;
  I : word;
  l : byte;
  endbuf,lastbuf,buf : PChar;
  p : ^PChar;
  cursize,size : integer;
  totallen : longint;
begin
  S.Read(Count, 6);
  i := Count;
  inherited Init(Delta, 4);
  SetLimit(i);
  Count := i;
  S.Read(totallen, sizeof(Totallen));
  i := 0;
  size := 0;
  endbuf := nil;
  lastbuf := nil;
  repeat
    S.Position := S.Position - (endbuf-lastbuf);
    inc(totallen, endbuf-lastbuf);
    if totallen > $7fff then size := $7fff
    else size := totallen;
    GetMem(buf, size+1);
    S.Read(buf^, size);
    dec(totallen, size);
    endbuf := buf+size;
    PChar(endbuf)^ := #0;
    while (size > 0) do begin
      PPChar(At(i))^ := buf;
      lastbuf := buf;
      l := StrLen(buf);
      dec(size,l+1);
      inc(i);
      buf := buf+l+1;
    end;
    dec(i);
  until totallen <= 0;
{  i := 0;
  while ForEach(p, i) do begin
    S.Read(l, 1);
    if l > 0 then begin
      GetMem(p^, l+1);
      S.Read(p^^, l);
      p^[l] := #0;
    end else
      p := nil;
  end;}
end;
{$ENDIF}

constructor DynQueue.Init(AQueueSize, AItemSize : word);
begin
  inherited Init(0, AItemSize);
  Count := AQueueSize;
  SetLimit(AQueueSize);
  Clear;
end;

procedure DynQueue.Clear;
begin
  Head := 0;
  Tail := 0;
end;

function DynQueue.Put(const AItems; NumItems : integer) : boolean;
var
  i : integer;
  src,dest : pointer;
begin
  Put := false;
  if Limit - ItemCount < NumItems then
    Exit;
  src := @AItems;
  while numitems > 0 do begin
    i := Limit-Tail;
    if i > numitems then i := numitems;
    dest := At(Tail);
    Move(src^, dest^, i*ItemSize);
    inc(PChar(src), i*ItemSize);
    inc(Tail, i);
    dec(numitems, i);
    if Tail >= Limit then Tail := 0;
  end;

  {
  p := PChar(@AItems);
  while numitems > 0 do begin
    AtPut(Tail, p^);
    inc(Tail);
    if Tail >= Limit then Tail := 0;
    dec(numitems);
    inc(p, ItemSize);
  end;
  }
  Put := true;
end;

function DynQueue.Peek(var AItems; NumItems : integer) : boolean;
var
  oldhd : integer;
begin
  oldhd := Head;
  Get(AItems, NumItems);
  Head := oldhd;
end;

function DynQueue.Get(var AItems; NumItems : integer) : boolean;
var
  src,dest : pointer;
  i : integer;
begin
  Get := false;
  if ItemCount < NumItems then
    Exit;
  dest := @AItems;
  while numitems > 0 do begin
    i := Limit-Head;
    if i > numitems then i := numitems;
    src := At(Head);
    Move(src^, dest^, i*ItemSize);
    inc(PChar(dest), i*ItemSize);
    inc(Head, i);
    dec(numitems, i);
    if Head >= Limit then Head := 0;
  end;
  Get := true;
end;

function DynQueue.Skip(NumItems : integer) : boolean;
var
  p : PChar;
begin
  Skip := false;
  if ItemCount < NumItems then
    Exit;
  Head := (Head + NumItems) mod Limit;
  Skip := true;
end;

function DynQueue.ItemCount : integer;
begin
  ItemCount := (Tail + Limit - Head) mod Limit;
end;

end.
