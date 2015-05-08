(*********************************************************)
(**  JOYSTICK.PAS                                       **)
(**  Windows joystick routines                          **)
(**                                                     **)
(**  Copyright (c) 1994 HAMCO Software                  **)
(**                                                     **)
(*********************************************************)

unit Joystick;

interface

uses
  MMSystem;

type
  PUPoint = ^TUPoint;
  TUPoint = record x,y : word end;

function GetJoyNumDevs : word;
function GetJoyPos(JoyNum : word; var Info : TJoyInfo) : boolean;

implementation

function GetJoyNumDevs : word; 
begin
  GetJoyNumDevs := joyGetNumDevs;
end;

function GetJoyPos(JoyNum : word; var Info : TJoyInfo) : boolean; 
begin
  GetJoyPos := joyGetPos(JoyNum, @Info) = JOYERR_NOERROR;
end;

end.
