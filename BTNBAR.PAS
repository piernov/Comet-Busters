unit BtnBar;

interface

uses WinTypes, WinProcs, Messages, Strings;

function RegisterBtnBarClass: Boolean;
procedure DoneBtnBar;
function BtnBarWndProc(Wnd: Hwnd; Message, WParam: Word;
  LParam: LongInt): longint; export;{$IFDEF win32}stdcall;{$ENDIF}
function BtnBarDlgProc(Wnd: Hwnd; Message, WParam: Word;
  LParam: LongInt): Bool; export;{$IFDEF win32}stdcall;{$ENDIF}

const
  WMBB_LOSEFOCUS = WM_USER+$1000;

implementation

var
  BarFont : HFont;

const
  BtnBarClassName = 'SpiffBtnBar';

function BtnBarWndProc(Wnd: Hwnd; Message, WParam: Word;
  LParam: LongInt): longint;
var
  Ctrl : HWnd;
  i : integer;
begin
  BtnBarWndProc := 0;
  case Message of
    WM_INITDIALOG : begin
      for i := 100 to 120 do
        SendDlgItemMessage(Wnd, i, WM_SETFONT, BarFont, 0);
    end;
    WM_COMMAND:
      if IsWindow(GetParent(Wnd)) then begin
        SendMessage(GetFocus, BM_SETSTYLE, BS_PUSHBUTTON, 1);
        SendMessage(GetParent(Wnd), Message, wParam, lParam);
      end;
    WMBB_LOSEFOCUS : begin
      SendMessage(GetFocus, BM_SETSTYLE, BS_PUSHBUTTON, 1);
      SetFocus(GetParent(Wnd));
    end;
  else
    BtnBarWndProc := DefWindowProc(Wnd, Message, wParam, lParam);
  end;
end;

function BtnBarDlgProc(Wnd: Hwnd; Message, WParam: Word;
  LParam: LongInt): Bool;
begin
{  BtnBarDlgProc := true;
  case Message of
    WM_MOUSEACTIVATE : ;
  else}
    BtnBarDlgProc := false;
{  end;}
end;

function RegisterBtnBarClass: Boolean;
var
  WC: TWndClass;
  LogFont : TLogFont;
begin
  with WC do
  begin
    style := CS_GLOBALCLASS;
    lpfnWndProc := @BtnBarWndProc;
    cbClsExtra := 0;
    cbWndExtra := DlgWindowExtra;
    hInstance := System.hInstance;
    hIcon := 0;
    hCursor := LoadCursor(0, IDC_ARROW);
    hbrBackground := COLOR_BTNFACE+1;
    lpszMenuName := nil;
    lpszClassName := BtnBarClassName;
  end;
  RegisterBtnBarClass := WordBool(RegisterClass(WC));
  FillChar(LogFont, sizeof(LogFont), 0);
  StrCopy(LogFont.lfFaceName, 'HELV');
  LogFont.lfHeight := 8;
  BarFont := CreateFontIndirect(LogFont);
end;

procedure DoneBtnBar;
begin
  DeleteObject(BarFont);
  Unregisterclass(BtnBarClassName, hInstance);
end;

end.
