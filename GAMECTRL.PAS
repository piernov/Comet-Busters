unit GameCtrl;

interface

uses
  WinTypes, WinProcs, Messages,
  Objects, Sprite24, MMSystem, Joystick, GameSock;

type
  GameKeyType =
    (gcLeft, gcRight, gcUp, gcDown, gcBtn1, gcBtn2);
  TGameKeys = array[GameKeyType] of integer;
  PGameKeys = ^TGameKeys;
  GameKeyState = set of GameKeyType;

  { A TControl is an object that implements a game controller. }
  PController = ^TController;
  TController = object(TObject)
    Client : PPlayer;
    OnState, OffState : GameKeyState;

    constructor Init(AClient : PPlayer);
    { receives message from a window's input queue }
    procedure Message(Command, wParam : word; lParam : longint); virtual;
    procedure SetState(OnS, OffS: GameKeyState);
    procedure Reset;
    function GetState : GameKeyState;

    procedure Process; virtual;
    { send new state to player object }
    procedure Update; virtual;
    { set new state, write to remote stream }
  private
    State : GameKeyState;
    NewOnState, NewOffState : GameKeyState;
  end;

  PKeybdController = ^TKeybdController;
  TKeybdController = object(TController)
    constructor Init(AClient : PPlayer; AKeys : PGameKeys);
    procedure Message(Command, wParam : word; lParam : longint); virtual;
  private
    Keys : PGameKeys;
  end;

  PJoyController = ^TJoyController;
  TJoyController = object(TController)
    constructor Init(AClient : PPlayer; AJoyNum : integer; ACen : PUPoint);
    procedure Update; virtual;
  private
    Cen : PUPoint;
    JoyNum : integer;
  end;

  TEscapeFunc = procedure(Msg : byte);
(*
  PRemoteController = ^TRemoteController;
  TRemoteController = object(TController)
    S : PStream;
    constructor Init(AClient : PPlayer; AStrm : PStream);
    procedure Process; virtual;
  end;
*)
  PRemoteController = ^TRemoteController;
  TRemoteController = object(TController)
    constructor Init(AClient : PPlayer; AStrm : PGameSocket);
  end;

implementation

constructor TController.Init(AClient : PPlayer);
begin
  Client := AClient;
  Reset;
  State := [];
  OnState := [];
  OffState := [];
end;

function TController.GetState : GameKeyState;
begin
  GetState := State;
end;

procedure TController.Reset;
begin
  NewOnState := [];
  NewOffState := [];
end;

procedure TController.Message(Command, wParam : word; lParam : longint);
begin
end;

(*
    Updates the states of the controller. Resets the new states to 0.
*)
procedure TController.Update;
begin
  OnState := NewOnState;
  OffState := NewOffState;
  NewOnState := [];
  NewOffState := [];
end;

(*
    Sends the states to the linked TPlayer.
*)
procedure TController.Process;
var
  i : GameKeyType;
begin
  if ((OnState <> []) or (OffState <> [])) and (Client <> nil) then begin
    for i := Low(GameKeyType) to High(GameKeyType) do
      { see if both triggered - if so, then reset the key }
      if (i in OnState) and (i in OffState) and not (i in State) then begin
        Client^.Message(WM_KEYDOWN, ord(i), 0);
        Exclude(OnState, i);
      end;
    for i := Low(GameKeyType) to High(GameKeyType) do
      if (i in OffState) then begin
        Client^.Message(WM_KEYUP, ord(i), 0);
      end;
    for i := Low(GameKeyType) to High(GameKeyType) do
      if (i in OnState) then begin
        Client^.Message(WM_KEYDOWN, ord(i), 0);
      end;
  end;
  State := State + OnState - OffState;
end;

procedure TController.SetState(OnS, OffS : GameKeyState);
begin
  NewOnState := OnS;
  NewOffState := OffS;
end;

constructor TKeybdController.Init(AClient : PPlayer; AKeys : PGameKeys);
begin
  inherited Init(AClient);
  Keys := AKeys;
end;

procedure TKeybdController.Message(Command, wParam : word; lParam : longint);
var
  i : GameKeyType;
begin
  case Command of
    WM_KEYDOWN, WM_KEYUP : begin
      for i := Low(GameKeyType) to High(GameKeyType) do begin
        if Keys^[i] = HiWord(lParam) and $1ff then begin
          if Command = WM_KEYDOWN then
            Include(NewOnState, i)
          else
            Include(NewOffState, i);
          Break;
        end;
      end;
    end;
  end;
end;

constructor TJoyController.Init(AClient : PPlayer; AJoyNum : integer; ACen : PUPoint);
begin
  inherited Init(AClient);
  JoyNum := AJoyNum;
  Cen := ACen;
end;

procedure TJoyController.Update;
var
  NewState : GameKeyState;
  JoyInfo : TJoyInfo;
begin
  NewState := [];
  if GetJoyPos(JoyNum, JoyInfo) then
  with JoyInfo, Cen^ do begin
    if wXpos < (X div 3)*2 then
      Include(NewState, gcLeft)
    else if wXpos > (X div 3)*4 then
      Include(NewState, gcRight);
    if wYpos < (Y div 3)*2 then
      Include(NewState, gcUp)
    else if wYpos > (Y div 3)*4 then
      Include(NewState, gcDown);
    if wButtons and JOY_BUTTON1 > 0 then
      Include(NewState, gcBtn1);
    if wButtons and JOY_BUTTON2 > 0 then
      Include(NewState, gcBtn2);
  end;
  NewOnState := NewState-State;
  NewOffState := State-NewState;
  inherited Update;
end;

constructor TRemoteController.Init;
begin
  inherited Init(AClient);
end;

(*
procedure TRemoteController.Process;
var
  NewState : GameKeyState;
begin
  NewState := [];
  S^.Read(NewState, sizeof(NewState));
  SetState(NewState);
end;
*)

end.
