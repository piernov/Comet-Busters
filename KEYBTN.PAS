(*********************************************************)
(**  KEYBTN.PAS                                         **)
(**  Custom control - keyboard button                   **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit KeyBtn;

interface

uses WinTypes, WinProcs, Messages;

procedure SetKeyBtnColor(Wnd : HWnd; Color : TColorRef);

implementation

uses
  Strings;

const
  KbdBtnClassName = 'KbdButton';

const
  ofState       = 0;
  ofColor       = 2;
  ofSize        = 6; { Amount of window extra bytes to use }

const
  bsDisabled    = $0001;
  bsFocus       = $0002;
  bsKeyDown     = $0004;
  bsMouseDown   = $0008;
  bsMouseUpDown = $0010;
  bsDefault     = $0020;

  DarkBtnColor  = $C0C0C0;
  LightBtnColor = $E0E0E0;

var
  BtnFont : word;

procedure SetKeyBtnColor(Wnd : HWnd; Color : TColorRef);
begin
  SetWindowLong(Wnd, ofColor, Color);
end;

function KbdButtonWinFn(HWindow: HWnd; Message: Word; wParam: Word;
  lParam: Longint): Longint; export;{$IFDEF win32}stdcall;{$ENDIF}
var
  DC: HDC;
  BitsNumber: Integer;
  Bitmap: TBitmap;
  Rect: TRect;
  Pt: TPoint;
  PS: TPaintStruct;

function Get(Ofs: Integer): Word;
begin
  Get := GetWindowWord(HWindow, Ofs);
end;

procedure SetWord(Ofs: Integer; Val: Word);
begin
  SetWindowWord(HWindow, Ofs, Val);
end;

function State: Word;
begin
  State := Get(ofState);
end;

function GetState(AState: Word): Boolean;
begin
  GetState := (State and AState) = AState;
end;

procedure Paint(DC: HDC);
const
  rw=4;rh=2;
var
  BorderBrush, OldBrush: HBrush;
  OldFont : HFont;
  Frame: TRect;
  Height, Width: Integer;
  bdBorderWidth : integer;
  Txt : array[0..20] of char;
  Color : longint;
begin
  { Draw border }
  GetClientRect(HWindow, Frame);
  Height := Frame.bottom - Frame.top;
  Width := Frame.right - Frame.left;

  Color := GetWindowLong(HWindow, ofColor);
  OldBrush := SelectObject(DC, GetStockObject(BLACK_BRUSH));

  bdBorderWidth := ord(GetState(bsDefault))+1;
  PatBlt(DC, Frame.left, Frame.top, Width, bdBorderWidth, PatCopy);
  PatBlt(DC, Frame.left, Frame.top, bdBorderWidth, Height, PatCopy);
  PatBlt(DC, Frame.left, Frame.bottom - bdBorderWidth, Width,
    bdBorderWidth, PatCopy);
  PatBlt(DC, Frame.right - bdBorderWidth, Frame.top, bdBorderWidth,
    Height, PatCopy);
  InflateRect(Frame, -bdBorderWidth, -bdBorderWidth);
  InflateRect(Frame, -rw, -rh);
  if (State and (bsMouseDown + bsKeyDown) <> 0) and
      not GetState(bsMouseUpDown) then begin
    inc(Frame.left, 2);
    inc(Frame.top, 2);
  end;

  BorderBrush := CreateSolidBrush(Color);
  FillRect(DC, Frame, BorderBrush);
  SelectObject(DC, OldBrush);

  SetBkMode(DC, TRANSPARENT);
  SetBkColor(DC, Color);
  OldFont := SelectObject(DC, BtnFont);
  GetWindowText(HWindow, Txt, sizeof(Txt));
  DrawText(DC, Txt, -1, Frame, DT_LEFT);
  SelectObject(DC, OldFont);

  DeleteObject(BorderBrush);
end;

procedure Repaint;
var
  DC: HDC;
begin
  DC := GetDC(HWindow);
  Paint(DC);
  ReleaseDC(HWindow, DC);
end;

procedure SetState(AState: Word; Enable: Boolean);
var
  OldState: Word;
begin
  OldState := State;
  if Enable then SetWord(ofState, State or AState)
  else SetWord(ofState, State and not AState);
  if State <> OldState then Repaint;
end;

function InMe(lPoint: Longint): Boolean;
var
  R: TRect;
  Point: TPoint absolute lPoint;
begin
  GetClientRect(HWindow, R);
  InMe := PtInRect(R, Point);
end;

procedure ButtonPressed;
begin
  SetState(bsMouseDown + bsMouseUpDown + bsKeyDown, False);
  SendMessage(GetParent(HWindow), wm_Command, GetDlgCtrlID(HWindow),
    Longint(HWindow));
end;

begin
  KbdButtonWinFn := 0;
  case Message of
    wm_Create:
      begin
        if GetWindowLong(HWindow, GWL_STYLE) and BS_DEFPUSHBUTTON > 0 then
          SetKeyBtnColor(HWindow, DarkBtnColor)
        else
          SetKeyBtnColor(HWindow, LightBtnColor);
      end;
    wm_Paint:
      begin
        BeginPaint(HWindow, PS);
        Paint(PS.hDC);
        EndPaint(HWindow, PS);
      end;
    wm_EraseBkGnd:
      begin
      end;
    wm_Enable:
      SetState(bsDisabled, wParam <> 0);
    wm_SetFocus:
      SetState(bsFocus, True);
    wm_KillFocus:
      SetState(bsFocus, False);
    wm_KeyDown:
      if (wParam = $20) and not GetState(bsKeyDown) and
          not GetState(bsMouseDown) then
        SetState(bsKeyDown, True);
    wm_KeyUP:
      if (wParam = $20) and GetState(bsKeyDown) then
        ButtonPressed;
    wm_LButtonDblClk, wm_LButtonDown:
      if InMe(lParam) and not GetState(bsKeyDown) then
      begin
        if GetFocus <> HWindow then SetFocus(HWindow);
        SetState(bsMouseDown, True);
        SetCapture(HWindow);
      end;
    wm_MouseMove:
      if GetState(bsMouseDown) then
        SetState(bsMouseUpDown, not InMe(lParam));
    wm_LButtonUp:
      if GetState(bsMouseDown) then
      begin
        ReleaseCapture;
        if not GetState(bsMouseUpDown) then ButtonPressed
        else SetState(bsMouseDown + bsMouseUpDown, False);
      end;
    wm_GetDlgCode:
      if GetState(bsDefault) then
        KbdButtonWinFn:= dlgc_DefPushButton
      else
        KbdButtonWinFn := dlgc_UndefPushButton;
    bm_SetStyle:
      SetState(bsDefault, wParam = bsDefault);
  else
    KbdButtonWinFn := DefWindowProc(HWindow, Message, wParam, lParam);
  end;
end;

procedure RegClass;
var
  AClass: TWndClass;
  Font: TLogFont;
begin
  with AClass do
  begin
    lpszClassName := KbdBtnClassName;
    hCursor       := LoadCursor(0, idc_Arrow);
    lpszMenuName  := nil;
    style         := cs_HRedraw or cs_VRedraw or cs_DblClks or cs_GlobalClass;
    lpfnWndProc   := TFarProc(@KbdButtonWinFn);
    hInstance     := System.hInstance;
    hIcon         := 0;
    cbWndExtra    := ofSize;
    cbClsExtra    := 0;
    hbrBackground := 0;
  end;
  RegisterClass(AClass);
  FillChar(Font, sizeof(Font), 0);
  StrCopy(Font.lfFaceName, 'HELV');
  Font.lfHeight := 8;
  BtnFont := CreateFontIndirect(Font);
end;

begin
  RegClass;
end.
