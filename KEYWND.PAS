(*********************************************************)
(**  KEYWND.PAS                                         **)
(**  Keyboard window functions                          **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit KeyWnd;

interface

uses
  WinTypes, WinProcs, Messages;

const
  WM_KEYPICKED = WM_USER+1;

function CreateKeyboardWnd(Instance : THandle; Parent : HWnd) : HWnd;
{ Create a window containing a keyboard with clickable keys
  The keys send WM_COMMAND messages with the virtual key code
  as the command }
function AddKeyNamesToBox(ComboBox : HWnd) : integer;
{ Adds all the key names to the specified combo box. Returns the number
  of strings added. }
function GetKeyCodeFromName(KeyName : PChar) : integer;
{ Returns the virtual key code of the combo box's edit control. }

implementation

uses
  Objects, SysUtils, IMath, KeyBtn;

{$I COMET.INC}

function KeyboardDlgProc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool; export;{$IFDEF win32}stdcall;{$ENDIF}
var
  Wnd : HWnd;
  i : integer;
  Buf : array[0..31] of char;
  sp : PChar;
begin
  KeyboardDlgProc := true;
  case Message of
    WM_INITDIALOG : begin
      for i := 0 to $1FF do begin
        if GetKeyNameText(MakeHigh(i), Buf, sizeof(Buf)) > 0 then begin
          sp := StrRScan(Buf, ' ');
          if sp = nil then sp := Buf;
          SendDlgItemMessage(Dialog, i, WM_SETTEXT, 0, longint(sp));
        end;
      end;
    end;
    WM_COMMAND : begin
      Wnd := GetParent(Dialog);
      PostMessage(Wnd, WM_KEYPICKED, wParam, lParam);
      Exit;
    end;
  end;
  KeyboardDlgProc := false;
end;

function CreateKeyboardWnd(Instance : THandle; Parent : HWnd) : HWnd;
var
  Wnd : HWnd;
begin
  Wnd := CreateDialog(Instance, PChar(DLG_KEYBOARD), Parent, @KeyboardDlgProc);
  CreateKeyboardWnd := Wnd;
end;

function AddKeyNamesToBox(ComboBox : HWnd) : integer;
var
  Buf : array[0..15] of char;
  i,num : integer;
begin
  num := 0;
  for i := 0 to $1FF do begin
    if GetKeyNameText(MakeHigh(i), Buf, sizeof(Buf)) > 1 then begin
      if SendMessage(ComboBox, CB_ADDSTRING, 0, longint(@Buf)) >= 0 then
        inc(num);
    end;
  end;
  AddKeyNamesToBox := num;
end;

function GetKeyCodeFromName(KeyName : PChar) : integer;
var
  Buf : array[0..15] of char;
  i : integer;
begin
  for i := 0 to $1FF do begin
    if GetKeyNameText(MakeHigh(i), Buf, sizeof(Buf)) > 0 then begin
      if StrLIComp(Buf, KeyName, sizeof(Buf)) = 0 then begin
        GetKeyCodeFromName := i;
        Exit;
      end;
    end;
  end;
{  if StrLen(KeyName) = 1 then begin
    GetKeyCodeFromName := ord(upcase(KeyName[0]));
  end else}
    GetKeyCodeFromName := -1;
end;

end.
