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

function GetJoyNumDevs : word;
function GetJoyPos(JoyNum : word; var Info : TJoyInfo) : boolean;

implementation

function GetJoyNumDevs; external 'SNDLIB' index 16;
function GetJoyPos; external 'SNDLIB' index 17;

end.
