(*********************************************************)
(**  COMETDLG.PAS                                       **)
(**  Comet Busters! dialog procedures                   **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit CometDlg;

interface

uses
  WinTypes, WinProcs, Win31, Messages;

{ the functions for the dialog boxes for the buttons on the button bar }

{$IFNDEF scrnsave}
{ GAME button }
function GameDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool; export; {$IFDEF win32}stdcall;{$ENDIF}
{ PLAYER button }
function PlayerDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool; export; {$IFDEF win32}stdcall;{$ENDIF}
{ KEYBOARD SETUP dialog }
function KeysDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool; export; {$IFDEF win32}stdcall;{$ENDIF}
{ JOYSTICK SETUP dialog }
function JoystickDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool; export; {$IFDEF win32}stdcall;{$ENDIF}
procedure DefineJoyNumbers;
{$IFNDEF nocomm}
{ REMOTE SETUP dialog}
function RemoteDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool; export; {$IFDEF win32}stdcall;{$ENDIF}
{$ENDIF}
{$ELSE}
function ScrnSaveSetDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool; export; {$IFDEF win32}stdcall;{$ENDIF}
{$ENDIF}

implementation

{$IFNDEF scrnsave}
uses
  GameLib, CometLib, IMath, KeyWnd, KeyBtn, Joystick, MMSystem, GameCtrl;

var
  CurDlgPlyr : integer;      { what player is selected in the Players
                               dialog box }
  KeysWnd : HWnd;            { handle of the keyboard window }
  TotalNumSticks : integer;

procedure MoveWindowUnderButton(Wnd : HWnd; id : integer);
var
  R : TRect;
begin
  GetWindowRect(GetDlgItem(BtnBarWnd, id), R);
  SetWindowPos(Wnd, 0, R.left, R.bottom, 0, 0,
    SWP_NOACTIVATE or SWP_NOSIZE or SWP_NOZORDER);
end;

function NumFreeSticks : integer;
{ returns the number of joysticks that can be assigned to
  other players }
var
  i,sticks : integer;
begin
  sticks := TotalNumSticks;
  for i := 0 to MaxPlayers-1 do with Metrics[i] do
    if (ControlType = control_Joystick) and (CurDlgPlyr <> i) then
      dec(sticks);
  NumFreeSticks := sticks;
end;

procedure DefineJoyNumbers;
{ assign joystick numbers to players }
var
  i,num : integer;
begin
  num := 0;
  for i := 0 to MaxPlayers-1 do with Metrics[i] do
    if (ControlType = control_Joystick) then begin
      JoyNumber := num;
      inc(num);
    end;
end;

{ colors of each player's keys on the keyboard window }
const
  KbdColors : array[0..MaxPlayers-1] of TColorRef =
    ($FF8080, $8080FF, $80FF80, $80FFFF);

procedure TurnAppropriateKeysRed;
{ Color all the keys other players are using }
var
  Key : GameKeyType;
  i : integer;
begin
  for i := 0 to MaxPlayers-1 do with Metrics[i] do begin
    if (CurDlgPlyr <> i) and (ControlType = control_Keyboard) then
    for Key := Low(GameKeyType) to High(GameKeyType) do if Key <> gcDown then begin
      SetKeyBtnColor(GetDlgItem(KeysWnd, Keys[Key]), KbdColors[i]);
    end;
  end;
end;

function KeysDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool;

  procedure GetPlyrKeys;
  { Put the proper key names into the combo boxes }
  var
    Key : GameKeyType;
    Buf : array[0..79] of char;
    idx : integer;
  begin
   with Metrics[CurDlgPlyr] do
    for Key := Low(GameKeyType) to High(GameKeyType) do if Key <> gcDown then begin
      if GetKeyNameText(MakeHigh(Keys[Key]), Buf, sizeof(Buf)) > 0 then
      begin
        { Try to match the key name in list box, if we can't
          just set the edit control = to the key name. }
        idx := SendDlgItemMessage(Dialog, ID_KEYBOXFIRST+ord(Key),
          CB_FINDSTRINGEXACT, word(-1), longint(@Buf));
        if idx <> CB_ERR then
          SendDlgItemMessage(Dialog, ID_KEYBOXFIRST+ord(Key), CB_SETCURSEL,
            idx, 0)
        else
          SendDlgItemMessage(Dialog, ID_KEYBOXFIRST+ord(Key), WM_SETTEXT, 0,
            longint(@Buf));
      end;
    end;
  end;

  function SetPlyrKeys : boolean;
  { Get the proper key names from the combo boxes }
  var
    Key : GameKeyType;
    KeysToSet : TGameKeys;
    Buf : array[0..79] of char;
    Code : integer;
  begin
    for Key := Low(GameKeyType) to High(GameKeyType) do if Key <> gcDown then begin
      SendDlgItemMessage(Dialog, ID_KEYBOXFIRST+ord(Key), WM_GETTEXT,
        sizeof(Buf), longint(@Buf));
      Code := GetKeyCodeFromName(Buf);
      if Code < 0 then begin { could not match key name -- fail }
        SetPlyrKeys := false;
        Exit;
      end else
        KeysToSet[Key] := Code;
    end;
    Metrics[CurDlgPlyr].Keys := KeysToSet;
    SetPlyrKeys := true;
  end;

var
  R : TRect;
  i : integer;
  Ctrl : HWnd;
  Buf : array[0..79] of char;
begin
  KeysDlgProc := true;
  case Message of
    WM_INITDIALOG : begin
      GetWindowRect(GetDesktopWindow, R);
      { center the keyboard window in the bottom half of the screen }
      R.bottom := (R.top+R.bottom) div 2;
      CenterWindow(Dialog, @R);
      KeysWnd := CreateKeyboardWnd(HInstance, Dialog);
      { color keys that other players are using }
      TurnAppropriateKeysRed;
      { put the dialog in the top half of the screen }
      GetWindowRect(GetDesktopWindow, R);
      R.top := (R.top+R.bottom) div 2;
      CenterWindow(KeysWnd, @R);
      ShowWindow(KeysWnd, SW_RESTORE);
      { fill list boxes with key names }
      for i := ID_KEYBOXFIRST to ID_KEYBOXLAST do begin
        AddKeyNamesToBox(GetDlgItem(Dialog, i));
      end;
      GetWindowText(Dialog, Buf, sizeof(Buf));
      i := CurDlgPlyr + 1;
      SetWindowText(Dialog, sprintf(Buf, i));
      GetPlyrKeys;
      Exit;
    end;
    WM_KEYPICKED : begin
      { a key was selected from the keyboard window -- make it so
        in the keyboard dialog }
      SetActiveWindow(Dialog);
      if GetKeyNameText(MakeHigh(wParam), Buf, sizeof(Buf)) > 0 then
      begin
        Ctrl := GetFocus;
        if GetParent(Ctrl) <> Dialog then Ctrl := GetParent(Ctrl);
        case GetDlgCtrlID(Ctrl) of
          ID_KEYBOXFIRST..ID_KEYBOXLAST : begin
            { if the focused control is a combo box, set its text }
            SetWindowText(GetFocus, Buf);
            PostMessage(Dialog, WM_NEXTDLGCTL, 0, 0);
          end;
        end;
      end;
    end;
    WM_COMMAND :
      case wParam of
        id_OK:
          begin
            if SetPlyrKeys then begin
              EndDialog(Dialog, wParam);
            end else begin
              MessageBox(Dialog, LoadStr(STR_INVALIDKEYNAME), nil,
                MB_OK or MB_ICONEXCLAMATION);
            end;
            Exit;
          end;
        id_Cancel:
          begin
            EndDialog(Dialog, wParam);
            Exit;
          end;
      end;
  end;
  KeysDlgProc := false;
end;

function JoystickDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool;
var
  i : integer;
  Buf : array[0..79] of char;
  JoyInfo : TJoyInfo;
begin
  JoystickDlgProc := true;
  case Message of
    WM_INITDIALOG : begin
      GetWindowText(Dialog, Buf, sizeof(Buf));
      i := CurDlgPlyr + 1;
      SetWindowText(Dialog, sprintf(Buf, i));
    end;
    WM_COMMAND :
      case wParam of
        id_OK:
          with Metrics[CurDlgPlyr] do begin
            DefineJoyNumbers;
            if GetJoyPos(JoyNumber, JoyInfo) then begin
              JoyCenter.X := JoyInfo.wXpos;
              JoyCenter.Y := JoyInfo.wYpos;
            end;
            EndDialog(Dialog, wParam);
            Exit;
          end;
        id_Cancel:
          begin
            EndDialog(Dialog, wParam);
            Exit;
          end;
      end;
  end;
  JoystickDlgProc := false;
end;

function PlayerDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool;

  procedure GetSpecScrollBars;
  { transfer player attributes to scroll bar controls }
  var i : integer;
  begin
   with Metrics[CurDlgPlyr] do
    for i := ID_SBFIRST to ID_SBLAST do begin
      SetScrollPos(GetDlgItem(Dialog, i), SB_CTL,
        Specs[SpecType(i-ID_SBFIRST)], true);
    end;
  end;

  procedure SetSpecScrollBars;
  { transfer scroll bar positions to player attributes }
  var i : integer;
  begin
   with Metrics[CurDlgPlyr] do
    for i := ID_SBFIRST to ID_SBLAST do begin
      Specs[SpecType(i-ID_SBFIRST)] :=
        GetScrollPos(GetDlgItem(Dialog, i), SB_CTL);
    end;
  end;

  procedure SetPlyrParams(Plyr : integer);
  { set player attributes from dialog }
  begin
    with Metrics[Plyr] do begin
      SpecialType := WhichRadioButtonChecked(Dialog, ID_BNABILITYFIRST,
        ID_BNABILITYLAST)-ID_BNABILITYFIRST;
      ControlType := WhichRadioButtonChecked(Dialog, ID_BNCONTROLFIRST,
        ID_BNCONTROLLAST)-ID_BNCONTROLFIRST;
      SetSpecScrollBars;
    end;
  end;

  procedure GetPlyrParams(Plyr : integer);
  { set dialog controls from player attributes }
  begin
    with Metrics[Plyr] do begin
      CheckRadioButton(Dialog, ID_BNABILITYFIRST, ID_BNABILITYLAST,
        ID_BNABILITYFIRST+SpecialType);
      CheckRadioButton(Dialog, ID_BNCONTROLFIRST, ID_BNCONTROLLAST,
        ID_BNCONTROLFIRST+ControlType);
{      EnableWindow(GetDlgItem(Dialog, ID_BNKEYS), ControlType = 0);}
      EnableWindow(GetDlgItem(Dialog, ID_BNCONTROLFIRST+1), NumFreeSticks > 0);
      GetSpecScrollBars;
    end;
  end;

  procedure SetSpecBar(i, Value : integer);
  { changes player attribute I to new value VALUE }
  var Sum : longint;
      n : integer;
      Spec : SpecType;
      Bars : array[SpecType] of integer;
  begin
    Value := IMin(IMax(Value, 0), SpecLimit-1);
    Sum := 0;
    for Spec := Low(SpecType) to High(SpecType) do begin
      Bars[Spec] := GetScrollPos(GetDlgItem(Dialog, ord(Spec)+ID_SBFIRST), SB_CTL);
      if ord(Spec) <> i then inc(Sum, Bars[Spec]);
    end;
{   FORMULA: n(sum)+s1 = 128*5; n(sum) = 128*5-s1; n = (128*5-s1)/sum;    }
    if Sum = 0 then inc(Sum);
    for Spec := Low(SpecType) to High(SpecType) do begin
      if ord(Spec) <> i then begin
        n := longint(Bars[Spec])*(SpecLimit*5 div 2-Value) div Sum;
      end else
        n := Value;
      n := IMin(IMax(n, 0), SpecLimit-1);
      SetScrollPos(GetDlgItem(Dialog, ord(Spec)+ID_SBFIRST), SB_CTL, n, true);
    end;
  end;

  procedure CountJoysticks;
  var
    i : integer;
    JoyInfo : TJoyInfo;
  begin
    {$IFDEF ownjoy}
    if JoyCanAccess then TotalNumSticks := GetJoyNumDevs
    else TotalNumSticks := 0;
    {$ELSE}
    TotalNumSticks := 0;
    if GetJoyNumDevs > 0 then
      for i := 0 to GetJoyNumDevs-1 do
        if GetJoyPos(i, JoyInfo) then inc(TotalNumSticks);
    {$ENDIF}
  end;

var
  I,j,k : integer;
const
  PageAmt = SpecLimit div 8;
begin
  PlayerDlgProc := true;
  case Message of
    WM_INITDIALOG : begin
      MoveWindowUnderButton(Dialog, ID_PLAYERS);
      CountJoysticks;
      { add player x symbols to listbox }
      if RS <> nil then j := NumLocalPlayers
                   else j := MaxPlayers;
      for i := 1 to j do begin
        k := i;
        SendDlgItemMessage(Dialog, ID_LBPLYR, LB_ADDSTRING, 0,
          longint(sprintf(LoadStr(STR_PLAYERX), k)));
      end;
      { set range of scroll bars }
      for i := ID_SBFIRST to ID_SBLAST do begin
        SetScrollRange(GetDlgItem(Dialog, i), SB_CTL,
          1, SpecLimit-1, false);
      end;
      { SELECT PLAYER 1 DEFAULT }
      CurDlgPlyr := 0;
      GetPlyrParams(CurDlgPlyr);
      SendDlgItemMessage(Dialog, ID_LBPLYR, LB_SETCURSEL, 0, 0);
      Exit;
    end;
    WM_HSCROLL : with Metrics[CurDlgPlyr] do begin
      i := GetDlgCtrlID(HiWord(lParam))-ID_SBFIRST;
      case wParam of
        SB_THUMBTRACK : SetSpecBar(i, LoWord(lParam));
        SB_PAGELEFT,SB_LINELEFT : SetSpecBar(i,
          GetScrollPos(HiWord(lParam), SB_CTL)-PageAmt);
        SB_PAGERIGHT,SB_LINERIGHT : SetSpecBar(i,
          GetScrollPos(HiWord(lParam), SB_CTL)+PageAmt);
        SB_TOP : SetSpecBar(i, 0);
        SB_BOTTOM : SetSpecBar(i, SpecLimit-1);
      end;
    end;
    WM_COMMAND :
      case wParam of
        ID_LBPLYR : begin
          case HiWord(lParam) of
            LBN_SELCHANGE : begin
              if CurDlgPlyr >= 0 then
                SetPlyrParams(CurDlgPlyr);
              CurDlgPlyr := SendDlgItemMessage(Dialog, ID_LBPLYR,
                LB_GETCURSEL, 0, 0);
              GetPlyrParams(CurDlgPlyr);
              Exit;
            end;
          end;
        end;
{        ID_BNCONTROLFIRST..ID_BNCONTROLLAST : begin
          case HiWord(lParam) of
            BN_CLICKED : begin
              EnableWindow(GetDlgItem(Dialog, ID_BNKEYS),
                wParam = ID_BNCONTROLFIRST);
              Exit;
            end;
          end;
        end;}
        ID_BNKEYS : begin
          case WhichRadioButtonChecked(Dialog, ID_BNCONTROLFIRST,
              ID_BNCONTROLLAST)-ID_BNCONTROLFIRST of
            control_Keyboard :
              DialogBoxLib(HInstance, HStrLib, PChar(DLG_KEYS), Dialog, @KeysDlgProc);
            control_Joystick : begin
              DialogBoxLib(HInstance, HStrLib, PChar(DLG_JOYSTICK), Dialog, @JoystickDlgProc);
            end;
          end;
        end;
        ID_SPECRESET : begin
          for i := ID_SBFIRST to ID_SBLAST do begin
            SetScrollPos(GetDlgItem(Dialog, i), SB_CTL, SpecLimit div 2, true);
          end;
        end;
        id_OK:
          begin
            SetPlyrParams(CurDlgPlyr);
            EndDialog(Dialog, wParam);
            Exit;
          end;
        id_Cancel:
          begin
            EndDialog(Dialog, wParam);
            Exit;
          end;
        id_BtnHelp:
          WinHelp(MainWnd, 'COMET.HLP', HELP_CONTEXT, DLG_PLAYERS);
      end;
  end;
  PlayerDlgProc := false;
end;

function GameDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool;
var
  B: boolean;
  i : integer;
  {$IFDEF nocomm}R : TRect;{$ENDIF}
begin
  GameDlgProc := true;
  case Message of
    WM_INITDIALOG : with GameParams, VisualParams do begin
      MoveWindowUnderButton(Dialog, ID_GAME);
      CheckRadioButton(Dialog, ID_DIFF1, ID_DIFF3, ID_DIFF1+Difficulty-1);
      CheckDlgButton(Dialog, ID_FRAGEXPLODE, ord(FragmentExplosions));
      CheckDlgButton(Dialog, ID_PAUSEWHENINACT, ord(PauseWhenInactive));
      CheckDlgButton(Dialog, ID_DEADLY, ord(BulletsKillPlayers));
      CheckDlgButton(Dialog, ID_TOURNAMENT, ord(TournamentMode));
      CheckRadioButton(Dialog, ID_FIRSTTOURROCKS, ID_FIRSTTOURROCKS+2,
        ID_FIRSTTOURROCKS+TournamentRocks);
      CheckDlgButton(Dialog, ID_FULLSCREEN, ord(FullScreenDesired));
      EnableWindow(GetDlgItem(Dialog, ID_FULLSCREEN),
        (GameMode in gmode_AttractMode) and (word(GetVersion) > $311));
      {$IFDEF nocomm}
      GetWindowRect(Dialog, R);
      with R do MoveWindow(Dialog, left, top, right-left, bottom-top-
        HiWord(GetDialogBaseUnits)*42 div 8, false);
      {$ELSE}
      if RS = nil then
        EnableWindow(GetDlgItem(Dialog, ID_DISCONNECT), false)
      else begin
        for i := ID_DIAL to ID_REMOTESETUP do
          EnableWindow(GetDlgItem(Dialog, i), false);
        if (GameMode in gmode_Playing) then
          EnableWindow(GetDlgItem(Dialog, ID_OK), false);
      end;
      {$ENDIF}
      SetWindowText(GetDlgItem(Dialog, ID_UPDINTERVAL), sprintf('%d', UpdateInterval));
      Exit;
    end;
    WM_COMMAND : begin
      case wParam of
        {$IFNDEF nocomm}
        id_REMOTESETUP:
          begin
            DialogBoxLib(HInstance, HStrLib, PChar(DLG_REMOTESETUP), Dialog,
              @RemoteDlgProc);
          end;
        {$ENDIF}
        id_OK, id_Dial, id_Answer:
          with GameParams, VisualParams do begin
            Difficulty := WhichRadioButtonChecked(Dialog,
              ID_DIFF1, ID_DIFF3)-ID_DIFF1+1;
            FragmentExplosions :=
              WordBool(IsDlgButtonChecked(Dialog, ID_FRAGEXPLODE));
            PauseWhenInactive :=
              WordBool(IsDlgButtonChecked(Dialog, ID_PAUSEWHENINACT));
            BulletsKillPlayers :=
              WordBool(IsDlgButtonChecked(Dialog, ID_DEADLY));
            TournamentMode :=
              WordBool(IsDlgButtonChecked(Dialog, ID_TOURNAMENT));
            TournamentRocks := WhichRadioButtonChecked(Dialog,
              ID_FIRSTTOURROCKS, ID_FIRSTTOURROCKS+2)-ID_FIRSTTOURROCKS;
            FullScreenDesired :=
              WordBool(IsDlgButtonChecked(Dialog, ID_FULLSCREEN));
            UpdateInterval :=
              GetWindowInt(GetDlgItem(Dialog, ID_UPDINTERVAL), UpdateInterval);
            EndDialog(Dialog, wParam);
            Exit;
          end;
        id_Cancel, id_Disconnect:
          begin
            EndDialog(Dialog, wParam);
            Exit;
          end;
        id_BtnHelp:
          WinHelp(MainWnd, 'COMET.HLP', HELP_CONTEXT, DLG_GAME);
      end;
    end;
  end;
  GameDlgProc := false;
end;

{$IFNDEF nocomm}
function RemoteDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool;

  procedure EnableControls;
  var
    i,typ : integer;
    b : boolean;
  begin
    typ := WhichRadioButtonChecked(Dialog, ID_MODEM, ID_NETWORK)-ID_MODEM;
    for i := ID_COM1 to ID_IPPORT do begin
      b := ((typ = 2) and (i >= ID_REMOTEMACHINE)) or
        ((typ <> 2) and (i <= ID_COMLAST)) or
        ((typ = 0) and (i < ID_REMOTEMACHINE));
      EnableWindow(GetDlgItem(Dialog, i), b);
    end;
  end;

begin
  RemoteDlgProc := true;
  case Message of
    WM_INITDIALOG : with RemoteParams do begin
      CheckRadioButton(Dialog, ID_COM1, ID_COMLAST, ID_COM1+Port-1);
      CheckRadioButton(Dialog, ID_MODEM, ID_NETWORK, ID_MODEM+ConnectType);
      SetWindowText(GetDlgItem(Dialog, ID_INITSTRING), InitString);
      SetWindowText(GetDlgItem(Dialog, ID_DIALSTRING), DialString);
      SetWindowText(GetDlgItem(Dialog, ID_REMOTEMACHINE), RemoteName);
      SetWindowText(GetDlgItem(Dialog, ID_IPPORT), sprintf('%u', IPPort));
      CenterWindow(Dialog, nil);
      EnableControls;
    end;
    WM_COMMAND :
      case wParam of
        ID_MODEM..ID_NETWORK :
          EnableControls;
        id_OK:
          with RemoteParams do begin
            Port := WhichRadioButtonChecked(Dialog,
              ID_COM1, ID_COMLAST)-ID_COM1+1;
            ConnectType := WhichRadioButtonChecked(Dialog,
              ID_MODEM, ID_NETWORK)-ID_MODEM;
            GetWindowText(GetDlgItem(Dialog, ID_INITSTRING), InitString, sizeof(InitString));
            GetWindowText(GetDlgItem(Dialog, ID_DIALSTRING), DialString, sizeof(DialString));
            GetWindowText(GetDlgItem(Dialog, ID_REMOTEMACHINE), RemoteName, sizeof(RemoteName));
            IPPort := word(GetWindowInt(GetDlgItem(Dialog, ID_IPPORT), IPPort));
            EndDialog(Dialog, wParam);
            Exit;
          end;
        id_Cancel:
          begin
            EndDialog(Dialog, wParam);
            Exit;
          end;
        id_BtnHelp:
          WinHelp(MainWnd, 'COMET.HLP', HELP_CONTEXT, DLG_REMOTESETUP);
      end;
  end;
  RemoteDlgProc := false;
end;
{$ENDIF}

{$ELSE} { scrnsave }

uses
  GameLib, CometLib;

function ScrnSaveSetDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool;
var
  B: boolean;
  i : integer;
  {$IFDEF nocomm}R : TRect;{$ENDIF}
begin
  ScrnSaveSetDlgProc := true;
  case Message of
    WM_INITDIALOG : with GameParams, VisualParams do begin
      CheckRadioButton(Dialog, ID_DIFF1, ID_DIFF3, ID_DIFF1+Difficulty-1);
      CheckDlgButton(Dialog, ID_FRAGEXPLODE, ord(FragmentExplosions));
      CheckDlgButton(Dialog, ID_SOUND, ord(SoundOn = 0));
      CheckDlgButton(Dialog, ID_MUSIC, ord(MusicOn = 0));
      Exit;
    end;
    WM_COMMAND : begin
      case wParam of
        id_OK:
          with GameParams, VisualParams do begin
            Difficulty := WhichRadioButtonChecked(Dialog,
              ID_DIFF1, ID_DIFF3)-ID_DIFF1+1;
            FragmentExplosions :=
              WordBool(IsDlgButtonChecked(Dialog, ID_FRAGEXPLODE));
            SoundOn :=
              ord(IsDlgButtonChecked(Dialog, ID_SOUND) = 0)*sound_User;
            MusicOn :=
              ord(IsDlgButtonChecked(Dialog, ID_MUSIC) = 0)*sound_User;
            EndDialog(Dialog, wParam);
            Exit;
          end;
        id_Cancel, id_Disconnect:
          begin
            EndDialog(Dialog, wParam);
            Exit;
          end;
      end;
    end;
  end;
  ScrnSaveSetDlgProc := false;
end;

{$ENDIF}

end.
