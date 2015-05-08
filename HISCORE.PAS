(*********************************************************)
(**  HISCORE.PAS                                        **)
(**  Objects for retaining hi scores                    **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit HiScore;
{$P-}

interface

uses Objects, Sprite24, GameXtra, GameLib, WinTypes, WinProcs, SysUtils;

type
  InitialsStr = array[1..3] of char;
  PHiScoreEntry = ^THiScoreEntry;
  THiScoreEntry = object(TObject)
    Initials : InitialsStr;
    Score : longint;
    constructor Init(AName : InitialsStr; AScore : longint);
    constructor LoadFromText(Txt : PChar);
    procedure WriteToText(Txt : PChar);
  end;
  THiScoreList = object(TSortedCollection)
    constructor Init(ALimit, ADelta: Integer);
    function Compare(Key1, Key2: Pointer): Integer; virtual;
    procedure Insert(Item: Pointer); virtual;
    function IsHighScore(Score : longint) : integer;
    procedure Display(var Stage : TStage; var DispRect : TRect;
      ScoreCol, NameCol : TColorRef; FontName : PChar);
    procedure ReadFromINIFile(FileName, AppName : PChar);
    procedure WriteToINIFile(FileName, AppName : PChar);
  end;

implementation

const
  MaxNumHiScores = 10; 

function Sign(a : longint) : integer;
begin
  if a = 0 then Sign := 0
  else if a < 0 then Sign := -1
  else Sign := 1;
end;

constructor THiScoreList.Init(ALimit, ADelta: Integer);
begin
  TSortedCollection.Init(ALimit, ADelta);
  Duplicates := true;
end;

function THiScoreList.Compare(Key1, Key2: Pointer): Integer;
begin
  Compare := Sign(PHiScoreEntry(Key2)^.Score-PHiScoreEntry(Key1)^.Score);
end;

procedure THiScoreList.Insert(Item: Pointer);
begin
  TSortedCollection.Insert(Item);
  while Count > MaxNumHiScores do AtFree(Count-1);  { limit list to 10 items }
end;

function THiScoreList.IsHighScore(Score : longint) : integer;
var Test : THiScoreEntry;
    Index : integer;
begin
  Test.Init('   ', Score);
  Search(@Test, Index);
  if Index < Count then
    IsHighScore := Index+1
  else
    IsHighScore := 0;
end;

procedure StrComma(n : longint; var s : string);
var i : integer;
begin
  Str(n, s);
  i := length(s)-3;
  while i > 0 do begin
    if (s[i] >= '0') and (s[i] <= '9') then Insert(',', s, i+1);
    dec(i, 3);
  end;
end;

procedure THiScoreList.Display(var Stage : TStage; var DispRect : TRect;
  ScoreCol, NameCol : TColorRef; FontName : PChar);
var i : integer;
    LineSpac, CharSize : integer;
    s : string;
begin
  LineSpac := (DispRect.bottom-DispRect.top) div 10;
  CharSize := (DispRect.bottom-DispRect.top) div 12;
  for i := 0 to Count-1 do with PHiScoreEntry(At(i))^ do begin
    Str(i+1, s);
    s := s + '.'#0;
    Stage.AddForeProp(New(PBigText,
      Init(DispRect.left, DispRect.top+CharSize shr 1+i*LineSpac, @s[1],
        CharSize, FontName, 0, ScoreCol)));
    StrLCopy(@s[1], @Initials[1], 3);
    Stage.AddForeProp(New(PBigText,
      Init(DispRect.left+CharSize*2, DispRect.top+CharSize shr 1+i*LineSpac, @s[1],
        CharSize, FontName, 0, NameCol)));
    StrComma(Score, s);
    s := s + #0;
    Stage.AddForeProp(New(PBigText,
      Init((DispRect.left+DispRect.right*3) shr 2,
        DispRect.top+CharSize shr 1+i*LineSpac,
        @s[1], CharSize, FontName, 0, ScoreCol)));
  end;
end;

constructor THiScoreEntry.Init;
begin
  Initials := AName;
  Score := AScore;
end;

constructor THiScoreEntry.LoadFromText(Txt : PChar);
var
  chksum : word;
  Scor : longint;
  p : PChar;
begin
  p := @Initials[1];
  sscanf(Txt, '%3s,%lu,%u', p);
  Score := Scor;
  if (GetChksum(Score, 4) xor GetChksum(Initials, 3) <> chksum) then Fail;
end;

procedure THiScoreEntry.WriteToText(Txt : PChar);
var
  chksum : word;
  n : longint;
  Name : PChar;
begin
  Name := @Initials[1];
  n := Score;
  chksum := GetChkSum(n, 4) xor GetChkSum(Initials, 3);
  wvsprintf(Txt, '%3.3s,%lu,%u', Name);
end;

procedure THiScoreList.ReadFromINIFile(FileName, AppName : PChar);
var Txt : array[0..255] of char;
    Key : array[0..8] of char;
    Entry : PHiScoreEntry;
begin
  FreeAll;
  repeat
    wvsprintf(Key, 'Score%u', {$IFDEF WIN32}@{$ENDIF}Count);
    GetPrivateProfileString(AppName, Key, #0, Txt, sizeof(Txt), FileName);
    New(Entry);
    if not Entry^.LoadFromText(Txt) then Exit;
    Insert(Entry);
  until (Count >= MaxNumHiScores);
end;

procedure THiScoreList.WriteToINIFile(FileName, AppName : PChar);
var i : integer;
    Key : array[0..8] of char;
    Txt : array[0..255] of char;
begin
  for i := 0 to Count-1 do begin
    wvsprintf(Key, 'Score%u', {$IFDEF WIN32}@{$ENDIF}i);
    PHiScoreEntry(At(i))^.WriteToText(Txt);
    WritePrivateProfileString(AppName, Key, Txt, FileName);
  end;
end;

end.
