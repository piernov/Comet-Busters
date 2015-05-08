unit DirtRect;

interface

uses
  Objects, WinTypes, WinProcs;

const
  MaxDirtyRects = 256;
type
  TDirtyRect = object
    R : TRect;
  end;

  PDirtyRegion = ^TDirtyRegion;
  TDirtyRegion = object
    ScreenRect : TRect;
    NumRects : integer;
    UnionThreshold : integer;
    Rects : array[0..MaxDirtyRects-1] of TDirtyRect;
    procedure Setup(const AScrnRect : TRect);
    { adds a rectangle, returns True if it intersected another }
    procedure AddRect(const AR : TRect);
    function Contains(const AR : TRect) : boolean;
    function ForEach(var Index : cardinal; var R : PRect) : boolean;
    procedure MergeWith(var Rgn : TDirtyRegion);
  end;

implementation

procedure TDirtyRegion.Setup(const AScrnRect : TRect);
begin
  ScreenRect := AScrnRect;
  NumRects := 0;
  UnionThreshold := (ScreenRect.right div 32)*(ScreenRect.bottom div 32);
end;

function AreaOfRect(const R : TRect) : longint;
begin
  {$IFDEF win32}
  Result := (R.right-R.left)*(R.bottom-R.top);
  {$ELSE}
  Result := LongMul(R.right-R.left, R.bottom-R.top);
  {$ENDIF}
end;

function TDirtyRegion.Contains(const AR : TRect) : boolean;
var
  RR,IR : TRect;
  i : cardinal;
  pr : PRect;
begin
  Result := false;
  if not Bool(IntersectRect(RR, AR, ScreenRect)) then
    Exit; { clip to screen -- exit if rectangle is off screen }
  { align to dword boundaries }
  with RR do begin
    left := left and not 3;
    right := (right+3) and not 3;
  end;
  { test against every other rectangle }
  i := 0;
  while ForEach(i, pr) do begin
    if Bool(IntersectRect(IR, pr^, RR)) then
    begin
      Result := true; { we did intersect one }
      Exit;
    end;
  end;
end;

procedure TDirtyRegion.AddRect(const AR : TRect);
var
  IR, UR, RR : TRect; { RR = AR transformed }
  i : cardinal;
  pr : PRect;
begin
  if not Bool(IntersectRect(RR, AR, ScreenRect)) {or IsRectEmpty(RR)}
  then
    Exit; { clip to screen -- exit if rectangle is off screen }
  if (NumRects = MaxDirtyRects) then
    Exit; { unlikely, but must test }
  { align to dword boundaries }
  with RR do begin
    left := left and not 3;
    right := (right+3) and not 3;
  end;
  { test against every other rectangle }
  i := 0;
  while ForEach(i, pr) do begin
    if Bool(IntersectRect(IR, pr^, RR)) then
    begin
      if Bool(EqualRect(IR, RR)) then
        Exit; { AR was completely contained inside of another rectangle -- exit }
      if Bool(EqualRect(IR, pr^)) then begin
        pr^ := RR;
        Exit; { AR completely occluded another rectangle -- so replace the smaller
          one with the larger one }
      end;
      {
      if (IR.left = RR.left) and (IR.right = RR.right) then begin
        if (RR.top < pr^.top) and (RR.bottom < pr^.bottom) then begin
          RR.bottom := pr^.bottom;
          Break;
        end;
      end;
      }
      { see if we should merge these 2 rectangles }
      if Bool(UnionRect(UR, pr^, RR)) then begin
{        if AreaOfRect(UR)-AreaOfRect(IR) < UnionThreshold then begin}
        if AreaOfRect(UR)-AreaOfRect(RR)-AreaOfRect(pr^) < 0 then begin
          pr^ := UR;
          Exit;
        end;
      end;
    end;
  end;
  { if AddIfOverlap is true, exit if there were no intersections }
  Rects[NumRects].R := RR;
  inc(NumRects);
end;

function TDirtyRegion.ForEach(var Index : cardinal; var R : PRect) : boolean;
begin
  inc(Index);
  if Index > NumRects then
    Result := false
  else begin
    R := @Rects[Index-1].R;
    Result := true;
  end;
end;

procedure TDirtyRegion.MergeWith(var Rgn : TDirtyRegion);
var i : integer;
begin
  for i := 0 to Rgn.NumRects-1 do
    AddRect(Rgn.Rects[i].R);
end;

end.
