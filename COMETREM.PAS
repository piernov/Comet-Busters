unit CometRem;

interface

uses
  Objects, WinTypes, WinProcs, Strings, Win31, Sprite24, GameLib,
  CometLib, CometIni, CometDlg, {$IFNDEF WIN32}Modem,{$ENDIF}
  Net, Messages, GameSock;

procedure RemoteConnect(Originate : boolean);
procedure RemoteDisconnect;

{$IFDEF commfile}
var
  commf : text;
{$ENDIF}

implementation

{$IFDEF nocomm}

procedure RemoteConnect(Originate : boolean);
begin
end;
procedure RemoteDisconnect;
begin
end;

{$ELSE}

(*
   Send signature
   Wait for remote signature
   Send version
   Compare to remote version
   Write & read playfield size
   Person w/ larger playfield adjusts to smaller

   WHEN GAME IS STARTED:

   Send "GAME START" message
   Write # local players
   Read # remote players
   Write stats on local players
   Read stats from remote players
*)
const
  CRLF = #13;
  CometSigRes : array[0..1] of PChar = ('COMETBUSTERS responding','COMETBUSTERS originating');
  ModemResults : array[0..6] of PChar =
    ('OK'+CRLF,'RING'+CRLF,'CONNECT','ERROR'+CRLF,'NO CARRIER'+CRLF,'VOICE'+CRLF,'BUSY'+CRLF);
const
  CometVer : word = $104;

var
  OtherVer : word;
  WaitDlg : HWnd;

{procedure WriteText(s : PChar);
begin
  RS^.Write(s^, strlen(s));
end;}

function WaitDlgFunc(Dialog: HWnd; Message, WParam: Word;
  LParam: longint): Bool; export;
var
  B: boolean;
  R : TRect;
  P : PChar;
begin
  WaitDlgFunc := true;
  case Message of
    WM_COMMAND : begin
      case wParam of
        id_Cancel:
          begin
            case RemoteParams.ConnectType of
              {$IFNDEF WIN32}
              0 : { modem connection } PModemStream(RS)^.WriteText(CRLF);
              {$ENDIF}
              2 : { network } PNetStream(RS)^.Cancel;
            end;
            EndDialog(Dialog, wParam);
            WaitDlg := 0;
            Exit;
          end;
      end;
    end;
  end;
  WaitDlgFunc := false;
end;

procedure MakeWaitDialog;
begin
  WaitDlg := CreateDialog(HStrLib, PChar(DLG_WAIT), MainWnd, @WaitDlgFunc);
  EnableWindow(MainWnd, false);
  CenterWindow(WaitDlg, nil);
  ShowWindow(WaitDlg, SW_SHOW);
  SetFocus(WaitDlg);
end;

procedure KillWaitDialog;
begin
  EnableWindow(MainWnd, true);
  DestroyWindow(WaitDlg);
end;

procedure WaitMsg(Msg : PChar);
begin
  SetWindowText(GetDlgItem(WaitDlg, 101), Msg);
  UpdateWindow(WaitDlg);
end;

function IdleWaitFunc : boolean; far;
begin
  WaitMessage;
  IdleWaitFunc := false;
end;

function WaitFunc : boolean; far;
var
  Msg : TMsg;
begin
  if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;
  WaitFunc := WaitDlg = 0;
end;

procedure RemoteDisconnect;
begin
  if RS <> nil then begin
    MakeWaitDialog;
    WaitMsg(LoadStr(STR_DISCONNECTING));
{    RS^.SetNotify(0, 1, -1, EV_RXCHAR);}
    Dispose(RS, Done);
    RS := nil;
    KillWaitDialog;
  end;
end;

procedure RemoteConnect;
var
  p : PChar;
  a : byte;
  err : word;

procedure InitRemoteStream;
begin
  with RemoteParams do begin
    if RS <> nil then
      Dispose(RS, Done);
    if ConnectType = 2 then begin { network }
      if Originate then
        RS := New(PNetStream, Init(IPPort, 'CMT1', StrPas(RemoteName)))
      else
        RS := New(PNetStream, Init(IPPort, 'CMT1', ''));
    end else begin { serial }
      {$IFNDEF WIN32}
      RS := New(PModemPktStream, Init(Port{$IFDEF loopback}+ord(HPrevInst=0){$ENDIF}));
      with PModemStream(RS)^ do
        SetParams(sprintf('COM1:%ld,N,8,1', BaudRate));
      {$ENDIF}
    end;
    if (RS^.Status = stOk) then
    begin
      RS^.IdleFunc := WaitFunc;
      if ConnectType = 2 then
        PNetStream(RS)^.Connect;
    end;
  end;
end;

 function CompareVersions : boolean;
 begin
  RS^.WritePacket(CometVer, sizeof(CometVer));
  repeat
    RS^.Read(OtherVer, sizeof(OtherVer));
  until (OtherVer <> $ddbb) or (RS^.status <> stOk);
  if CometVer <> OtherVer then begin
    err := STR_VERSIONMISMATCH;
    CompareVersions := false;
  end else
    CompareVersions := true;
 end;
 procedure ChooseScreenSize;
 var
   LR,RR,MainR : TRect;
   rx,ry : integer;
 begin
   { send our screen size }
   GetWindowRect(GameWnd, LR);
   { move it's UL corner to origin }
   OffsetRect(LR, -LR.left, -LR.top);
   RS^.WritePacket(LR, sizeof(LR));
   { read theirs }
   RS^.Read(RR, sizeof(RR));
   { if they're not equal, make them equal }
   if not EqualRect(LR, RR) then
   begin
     IntersectRect(RR, LR, RR);
     { shrink to intersection of both windows }
     if not EqualRect(RR, LR) then
     begin
       GetWindowRect(MainWnd, MainR);
       with MainR do begin
         right := right-LR.right+RR.right;
         bottom := bottom-LR.bottom+RR.bottom;
       end;
       with MainR do
         MoveWindow(MainWnd, left, top, right-left, bottom-top, true);
       InvalidateRect(GameWnd, nil, false);
     end;
   end;
 end;
label _error;
begin
  err := 0;
  MakeWaitDialog;
  WaitMsg(LoadStr(STR_INITMODEM));
  try
    InitRemoteStream;
    RS^.ErrorInfo := 0;
    if (RS^.Status <> stOk) then begin
      err := STR_NOINITPORT;
      goto _error;
    end;
    with RemoteParams do begin
      case ConnectType of
        {$IFNDEF WIN32}
        0 : begin
          with PModemStream(RS)^ do
          begin { modem connection }
            if InitModem(InitString) <> 0 then begin
              err := STR_NOINITMODEM;
              goto _error;
            end;
            if Originate then begin
              { dial number }
              p := @DialString;
              WaitMsg(sprintf(LoadStr(STR_DIALMODEM), p));
              WriteText(DialString);
              WriteText(CRLF);
            end else begin
              { wait for ring }
              WaitMsg(LoadStr(STR_WAITRING));
              if not Answer then begin
                err := STR_NOCARRIER;
                goto _error;
              end;
              WaitMsg(LoadStr(STR_WAITCONNECT));
            end;
            { wait for CONNECT }
            if not Connect then begin
              err := STR_NOCARRIER;
              goto _error;
            end;
          end;
          WaitMsg(LoadStr(STR_WAITANSWER));
          RS^.Sleep(2000);
          { send originating signature }
          if Originate then
            PModemStream(RS)^.WriteText(CometSigRes[1]);
          { wait for remote signature }
          if PModemStream(RS)^.WaitFor(CometSigRes, 20000) <> ord(not Originate) then begin
            err := STR_NOCARRIER;
            goto _error;
          end;
        { if answering, send originating signature 2nd }
          if not Originate then
            PModemStream(RS)^.WriteText(CometSigRes[0]);
        end;
        {$ENDIF}
        1..2 : begin
          WaitMsg(LoadStr(STR_WAITCONNECT));
          repeat
            RS^.Sleep(1000);
            if ConnectType = 2 then PNetStream(RS)^.sendtime := 0;
            err := $ddbb;
            RS^.WritePacket(err, 2);
            err := 0;
            if (RS^.ReadPacket(err, 2) = 2) and (err = $ddbb) then
              Break;
          until (RS^.Status <> stOk);
          if ConnectType = 2 then PNetStream(RS)^.sendtime := 0;
          err := $ddbb;
          RS^.WritePacket(err, 2);
        end;
      end;
    end;
    if RS^.Status <> stOk then begin
      err := STR_INFOERROR;
      goto _error;
    end;
    { compare program versions }
    WaitMsg('Comparing software versions...');
    if not CompareVersions then goto _error;
    { now choose the lowest screen size that will fit }
    WaitMsg('Arbitrating screen size...');
    ChooseScreenSize;
    if RS^.Status <> stOk then begin
      err := STR_INFOERROR;
      goto _error;
    end else begin
      WaitMsg('Tidying up...');
      a := 0;
      RS^.WritePacket(a, 1);
      RS^.Read(a, 1);
      if a <> 0 then goto _error;
      RS^.IdleFunc := IdleWaitFunc;
      (*
      case RemoteParams.ConnectType of
        0,1: PModemStream(RS)^.SetNotify(MainWnd, 1, -1, EV_RXCHAR);
        2 : PNetStream(RS)^.SetNotify(MainWnd);
      end;
      *)
      MessageBox(MainWnd, LoadStr(STR_CONNECTED), 'Connected!', MB_OK or MB_ICONEXCLAMATION);
    end;
    Exit;
  _error:
    {$IFDEF commfile}
    MessageBox(MainWnd, sprintf('Status: %d Info: %d', RS^.Status), '',MB_OK);
    {$ENDIF}
    WaitMsg(LoadStr(STR_DISCONNECTING));
    if RS <> nil then begin
      if err = 0 then
         err := word(RS^.ErrorInfo);
      Dispose(RS, Done);
      RS := nil;
    end;
    KillWaitDialog;
    if err > 0 then
      MessageBox(MainWnd, LoadStr(err), nil, MB_OK or MB_ICONEXCLAMATION);
  finally
    KillWaitDialog;
  end;
end;

{$ENDIF}

end.
