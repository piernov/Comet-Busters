unit Net;
{$R-,Q-}

interface

uses
  WinTypes, WinProcs, Objects, Strings,
  Win31, DynArr, GameSock, WinSock, Messages;

const
  MaxCachedPackets = 63;
  PacketStarveTime : longint = 200; { time until send req. to resend }

type
  sockaddr_in = TSockAddrIn;
  in_addr = TInAddr;

type
  TPktTime = integer;

  PNetMsgBuf = ^TNetMsgBuf;
  TNetMsgBuf = record
    id : TFOURCC;
    time : TPktTime;
    data : array[0..255] of byte;
  end;

  PNetMsgNode = ^TNetMsgNode;
  TNetMsgNode = record
    Next : PNetMsgNode;
    Size : word;
    Pkt : TNetMsgBuf;
  end;

  PNetCacheBuf = ^TNetCacheBuf;
  TNetCacheBuf = record
    size : word;
    data : array[0..255] of byte;
  end;

  PNetStream = ^TNetStream;
  TNetStream = object(TGameSocket)
    sendtime : TPktTime;
    constructor Init(ASocketNum : word; const AMsgID : TFOURCC;
      const AHost : String);
    destructor Done; virtual;
    procedure Connect;
    function ReadPacket(var Buf; Count: Word) : word; virtual;
    procedure WritePacket(var Buf; Count : word); virtual;
    procedure SetNotify(Wnd : HWnd);
{    function Cancelled : boolean; virtual;}
    procedure Idle; virtual;
    procedure Cancel;
  private
    recvtime : TPktTime;
    FSocket : TSocket;
    FAddr : sockaddr_in;
    FirstBuf : PNetMsgNode; { holds out-of-order packets }
    UrgentID : TFOURCC; { id for urgent "resend" message }
    LastRecvTick : longint; { msec time of last packet receive }
    head : integer;
    cache : array[0..MaxCachedPackets] of PNetCacheBuf; { holds sent packets }
    Host : String;
    procedure FillSocket(var name, addr : string; port : u_short);
    function LookupName(const name : string) : in_addr;
    procedure AskToResend;
    procedure ResendPacketsSince(time : TPktTime);
    function CheckError : boolean;
    function Bound : boolean;
  end;

  TTCPStream = object(TStream)
    FSocket : TSocket;
    FAddr : sockaddr_in;
    constructor Init(APort : word; const AHost : String);
    destructor Done; virtual;
    procedure Read(var Buf; Count: Word); virtual;
    function ReadLine : String;
    procedure Write(var Buf; Count: Word); virtual;
    function CheckError : boolean;
  end;

implementation

{$IFDEF loopback}
{$DEFINE noise}
{$ENDIF}

{$IFDEF noise}
uses
  GameLib;

const
  pktDupFreq = 5; { frequency to simulate dup'ing (every N packets) }
  pktLoseFreq = 5; { frequency to simulate lost packets (every N packets) }
  pktHitFreq = 5; { frequency to receive packets (1/N tries) }
{$ENDIF}

var
  bind : function(s: TSocket; var addr: sockaddr_in; namelen: integer) : integer;
  connect : function(s: TSocket; var addr: sockaddr_in; namelen: integer) : integer;
  gethostbyname : function(name: PChar) :  phostent;
  inet_addr : function(cp: PChar) : u_long;
  inet_ntoa : function(sin: in_addr) : PChar;
  htons: function(hostshort: u_short): u_short;
  ioctlsocket : function(s: TSocket; cmd: longint; var argp: longint) : integer;
  recvfrom : function(s: TSocket; var buf; len: integer; flags: integer;
    var from: sockaddr_in; var fromlen: integer) : integer;
  sendto : function(s: TSocket; var buf; len: integer; flags: integer;
    var saddrto: sockaddr_in; tolen: integer) : integer;
  socket : function(af: integer; stype: integer; protocol: integer) : TSocket;
  closesocket : function(s: TSocket): Integer;
  WSAStartup : function(wVersionRequired: word; var lpWSAData: TWSADATA) : integer;
  WSACleanup : function : integer;
  WSAGetLastError : function : integer;
  WSACancelBlockingCall : function : integer;
  WSAAsyncSelect : function(s: TSocket; handle: HWND; wMsg: u_int; lEvent: longint)
    : integer;

const
  WSlibrary : THandle = 0;
  WSlibRef : integer = 0;

const
  DefPort : word = 50001;

function LoadWinsock : boolean;
var
  myVerReqd : word;
  myWSAData : TWSADATA;
begin
  if WSlibRef = 0 then
  begin
    WSlibrary := LoadLibrary('WINSOCK.DLL');
    if WSlibrary >= HINSTANCE_ERROR then begin
      @bind := GetProcAddress(WSlibrary, 'bind');
      @connect := GetProcAddress(WSlibrary, 'connect');
      @gethostbyname := GetProcAddress(WSlibrary, 'gethostbyname');
      @inet_addr := GetProcAddress(WSlibrary, 'inet_addr');
      @inet_ntoa := GetProcAddress(WSlibrary, 'inet_ntoa');
      @htons := GetProcAddress(WSlibrary, 'htons');
      @ioctlsocket := GetProcAddress(WSlibrary, 'ioctlsocket');
      @recvfrom := GetProcAddress(WSlibrary, 'recvfrom');
      @sendto := GetProcAddress(WSlibrary, 'sendto');
      @socket := GetProcAddress(WSlibrary, 'socket');
      @closesocket := GetProcAddress(WSlibrary, 'closesocket');
      @WSAStartup := GetProcAddress(WSlibrary, 'WSAStartup');
      @WSACleanup := GetProcAddress(WSlibrary, 'WSACleanup');
      @WSAGetLastError := GetProcAddress(WSlibrary, 'WSAGetLastError');
      @WSACancelBlockingCall := GetProcAddress(WSlibrary, 'WSACancelBlockingCall');
      @WSAAsyncSelect := GetProcAddress(WSlibrary, 'WSAAsyncSelect');
    end else
      WSlibrary := 0;
    myVerReqd:=$0101;
    if (WSAStartup(myVerReqd, myWSAData) <> 0) then
      WSlibrary := 0;
  end;
  if WSlibrary > 0 then inc(WSlibRef);
  Result := WSlibRef > 0;
end;

function TNetStream.Bound : boolean;
begin
  Bound := FAddr.sin_addr.s_addr <> INADDR_NONE;
end;

function TNetStream.CheckError : boolean;
var
  errno : integer;
begin
  errno := WSAGetLastError;
  if (Status <> stOk) or (errno <> 0) then begin
    Error(stError, errno);
    CheckError := true;
  end else
    CheckError := false;
end;

{ LookupName -- try to look up host name }
function TNetStream.LookupName(const name : string) : in_addr;
var
  phe	: PHostEnt;
  pa	: PChar;
  sz	: array [1..64] of char;
  sa	: in_addr;
begin
   StrPCopy(@sz, name);
   phe := gethostbyname(@sz);
   if phe <> nil then
   begin
     pa := phe^.h_addr_list^;
     sa.S_un_b.s_b1:=pa[0];
     sa.S_un_b.s_b2:=pa[1];
     sa.S_un_b.s_b3:=pa[2];
     sa.S_un_b.s_b4:=pa[3];
     LookupName := sa;
   end
   else
       CheckError;
end;

procedure TNetStream.FillSocket(var name, addr : string; port : u_short);
var
	s	: array [1..64] of char;
begin
	{ Fill in address field }
	if name <> '' then						{ Host name given }
		begin
			StrPCopy(@s, name);
			FAddr.sin_addr.s_addr := inet_addr(@s);
                        if FAddr.sin_addr.s_addr = INADDR_NONE then
                        begin
                                FAddr.sin_addr := LookupName(name);        {KH 950712}
                                if Status <> stOk then Exit;
                      	        addr := StrPas(inet_ntoa(FAddr.sin_addr));
                        end;
 		end
	else if addr <> '' then				{ IP address given }
		begin
			FAddr.sin_addr.s_addr := 0;
			if addr <> '0.0.0.0' then	{ beware of Trumpet bug! }
				begin
					StrPCopy(@s, addr);
					FAddr.sin_addr.s_addr := inet_addr(@s);
				end;
		end
	else													{ Neither name or address given }
       	        Error(stInitError, 0);

	{ Fill in port number field }
		FAddr.sin_port := htons(port);
end;

constructor TNetStream.Init(ASocketNum : word; const AMsgID : TFOURCC;
      const AHost : String);
var
  laddr : sockaddr_in;
begin
  inherited Init(ASocketNum, AMsgID, $FF);

  FSocket := INVALID_SOCKET;
  if not LoadWinsock then begin
    Error(stInitError, WSASYSNOTREADY);
    Exit;
  end;

  sendtime := 0;
  recvtime := 0;
  FirstBuf := nil;
  UrgentID := AMsgID;
  UrgentID[0] := chr(ord(UrgentID[0]) xor $80);
  head := 0;
  fillchar(cache, sizeof(cache), 0);
  Host := AHost;

  FSocket := socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (FSocket = INVALID_SOCKET) and CheckError then Exit;
{   err := 1;
  setsockopt(FSocket, SOL_SOCKET, SO_DEBUG, @err, 2);}

  FAddr.sin_family := PF_INET;
  FAddr.sin_addr.s_addr := INADDR_ANY;
  FAddr.sin_port := htons(defport {$IFDEF loopback}+ord(HPrevInst = 0){$ENDIF});

  if (bind(FSocket, FAddr, SizeOf(FAddr)) <> 0) and CheckError then
    Exit;

  FAddr.sin_addr.s_addr := INADDR_NONE;
end;

procedure TNetStream.Connect;
var
  n,a : string;
begin
  n := Host;
  a := '';
  {$IFDEF loopback}
  if n <> '' then n := 'localhost';
  {$ENDIF}
  { don't have to connect w/ UDP }
  if n <> '' then
    FillSocket(n,a, defport {$IFDEF loopback}+ord(HPrevInst <> 0){$ENDIF})
  else
    FAddr.sin_addr.s_addr := INADDR_NONE;

{  connect(FSocket, FAddr, SizeOf(FAddr));
  if CheckError then Exit;}

  LastRecvTick := GetTickCount;
end;

destructor TNetStream.Done;
begin
  if FSocket <> INVALID_SOCKET then
    CloseSocket(FSocket);
  dec(WSlibRef);
  if WSlibRef = 0 then
    WSACleanup;
  inherited Done;
end;

var
  NetMsgBuf : TNetMsgBuf;
const
  NetMsgHdrSize = sizeof(TFOURCC)+sizeof(word);
  NetBufHdrSize = sizeof(pointer)+sizeof(word);

function TNetStream.ReadPacket(var Buf; Count: Word) : word;
var
  data : longint;
  prevbuf,newbuf : PNetMsgNode;
  datasize : word;
  InFAddr : sockaddr_in;
  FAddrSize : integer;
label another;
begin
  Result := 0;
  if Status <> stOk then Exit;

another:
  { first check out-of-order packets stored }
  prevbuf := nil;
  newbuf := FirstBuf;
  while newbuf <> nil do with newbuf^ do
  begin
    if (pkt.time <= recvtime) then begin
      { this is truly our next packet? }
      if pkt.time = recvtime then begin
        Move(pkt.Data, Buf, Size);
        Result := Size;
      end;
      { free the packet in the buffer }
      if prevbuf = nil then
        FirstBuf := next
      else
        prevbuf^.next := next;
      FreeMem(newbuf, Size + NetBufHdrSize);
      { was this was an earlier packet in the buffer? }
      if pkt.time = recvtime then begin
        inc(recvtime); { no, inc that thing }
        Exit;
      end else
        goto another; { yes, keep looking }
    end;
    prevbuf := newbuf;
    newbuf := Next;
  end;
  { now check the net }
  if (ioctlsocket(FSocket, FIONREAD, data) <> 0) and CheckError then
    Exit;
  { no data }
  if (data = 0) {$IFDEF noise}or (v_random(pktHitFreq) = 0){$ENDIF} then
  begin
    { see if we should start worrying about starvation }
    if GetTickCount - LastRecvTick > PacketStarveTime then begin
      LastRecvTick := GetTickCount;
      AskToResend;
    end;
    Exit;
  end;
  { yes data }
  if data > 0 then begin
    FaddrSize := sizeof(FAddr);
    datasize := recvfrom(FSocket, NetMsgBuf, sizeof(NetMsgBuf), 0,
      InFAddr, FAddrSize);
    if (datasize = SOCKET_ERROR) and CheckError then
      Exit;

    { see if it is urgent request }
    if longint(NetMsgBuf.id) = longint(UrgentID) then begin
      ResendPacketsSince(NetMsgBuf.time);
      Exit;
    end;
    { discard if not matching id }
    if longint(NetMsgBuf.id) <> longint(msgid) then begin
      goto another;
    end;

    { if we're not really connected to anything yet, got a new partner }
    if not Bound then
      FAddr := InFAddr
    else
    { otherwise, we'll make sure it's the same computer as last time }
      if FAddr.sin_addr.s_addr <> InFAddr.sin_addr.s_addr then goto another;

    datasize := datasize - NetMsgHdrSize;
    { see if this packet is the next one scheduled }
    if NetMsgBuf.time = recvtime then
    begin
      Move(NetMsgBuf.data, Buf, datasize);
      inc(recvtime);
      LastRecvTick := GetTickCount;
      ReadPacket := datasize;
      { success! }
    end else
    { discard if duplicate message (timestamp is earlier) }
    if NetMsgBuf.time < recvtime then begin
      goto another;
    end else begin
    { well it's out of order -- store it for later }
      GetMem(newbuf, NetMsgHdrSize + NetBufHdrSize + datasize);
      newbuf^.Next := FirstBuf;
      newbuf^.Size := datasize;
      Move(NetMsgBuf, newbuf^.Pkt, NetMsgHdrSize + datasize);
      FirstBuf := newbuf;
      goto another;
    end;
    Exit;
  end;
  { col. klink sez: "uhuhuhuuhhhh..." }
  Error(stInitError, WSAGetLastError);
end;

procedure TNetStream.WritePacket(var Buf; Count : word);
begin
  if not Bound or (Status <> stOk) then
    Exit;

  with NetMsgBuf do begin
    id := msgid;
    time := sendtime;
    Move(Buf, data, Count);

    {$IFDEF noise}
    if v_random(pktLoseFreq) <> 0 then {lost packet!}
    repeat
    {$ENDIF}
    if (sendto(FSocket, NetMsgBuf, Count+NetMsgHdrSize, 0, FAddr, sizeof(FAddr)) = SOCKET_ERROR)
      and CheckError
    then
      Exit;
    {$IFDEF noise}
    until v_random(pktDupFreq) <> 0; { dup packets? }
    {$ENDIF}

    { add packet to cache }
    if cache[head] <> nil then
      FreeMem(cache[head], cache[head]^.size + sizeof(word));
    GetMem(cache[head], Count + sizeof(word));
    with cache[head]^ do begin
      size := Count;
      Move(Buf, data, Count);
    end;
    inc(head);
    if head > MaxCachedPackets then head := 0;

    inc(sendtime);
  end;
end;

procedure TNetStream.SetNotify(Wnd : HWnd);
begin
  if (WSAAsyncSelect(FSocket, Wnd, WM_COMMNOTIFY, FD_READ) <> 0) and CheckError then
    Exit;
end;

(*
function TNetStream.Cancelled : boolean;
begin
  if inherited Cancelled then begin
    WSACancelBlockingCall;
    Cancelled := true;
  end else
    Cancelled := false;
end;
*)

procedure TNetStream.Idle;
begin
end;

procedure TNetStream.AskToResend;
{
  this function asks the remote computer to resend any packets
  from the recvtime'th packet and later
}
begin
  if not Bound or (Status <> stOk) then
    Exit;

  with NetMsgBuf do begin
    id := UrgentID;
    time := recvtime;
    {$IFDEF noise}
    if v_random(pktLoseFreq) <> 0 then {lost packet!}
    repeat
    {$ENDIF}
    sendto(FSocket, NetMsgBuf, NetMsgHdrSize, 0, FAddr, sizeof(FAddr));
    {$IFDEF noise}
    until v_random(pktDupFreq) <> 0; { dup packets? }
    {$ENDIF}
  end;
end;

procedure TNetStream.ResendPacketsSince(time : TPktTime);
{
  this function resends the packets since a specific time
}
var
  i : integer;
  tm : TPktTime;
begin
  if not Bound or (Status <> stOk) then
    Exit;

  if (sendtime - time) > MaxCachedPackets then begin
    { not enough back packets in cache! sorry... }
    Error(stError, 0);
    Exit;
  end;

  i := head;
  tm := sendtime;
  while tm > time do begin
    dec(i);
    dec(tm);
    if i < 0 then i := MaxCachedPackets;
    with cache[i]^ do
    begin
      NetMsgBuf.time := tm;
      NetMsgBuf.id := msgid;
      Move(data, NetMsgBuf.data, size);
      sendto(FSocket, NetMsgBuf, NetMsgHdrSize + size, 0, FAddr, sizeof(FAddr));
    end;
  end;
end;

procedure TNetStream.Cancel;
{ cancel blocking call }
begin
  WSACancelBlockingCall;
end;

function TTCPStream.CheckError : boolean;
var
  errno : integer;
begin
  errno := WSAGetLastError;
  if (Status <> stOk) or (errno <> 0) then begin
    Error(stError, errno);
    CheckError := true;
  end else
    CheckError := false;
end;

constructor TTCPStream.Init(APort : word; const AHost : String);
var
  s : array[0..64] of char;
begin
  inherited Init;

  FSocket := INVALID_SOCKET;
  if not LoadWinsock then begin
    Error(stInitError, WSASYSNOTREADY);
    Exit;
  end;

  FSocket := socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (FSocket = INVALID_SOCKET) and CheckError then
    Exit;
  FAddr.sin_addr.s_addr := INADDR_ANY;
  FAddr.sin_family := PF_INET;
  FAddr.sin_port := 0;
  if (bind(FSocket, FAddr, SizeOf(FAddr)) <> 0) and CheckError then
    Exit;
  StrPCopy(s, AHost);
  FAddr.sin_addr.s_addr := inet_addr(s);
  FAddr.sin_port := htons(APort);
  if (connect(FSocket, FAddr, SizeOf(FAddr)) <> 0) and CheckError then
    Exit;
end;

procedure TTCPStream.Read(var Buf; Count: Word);
var
  datasize : integer;
  FAddrSize : integer;
begin
  datasize := recvfrom(FSocket, Buf, Count, 0, FAddr, FAddrSize);
  if (datasize = SOCKET_ERROR) and CheckError then
    ;
end;

procedure TTCPStream.Write(var Buf; Count: Word);
begin
  if (sendto(FSocket, Buf, Count, 0, FAddr, sizeof(FAddr)) = SOCKET_ERROR)
    and CheckError
  then
    ;
end;

destructor TTCPStream.Done;
begin
  if FSocket <> INVALID_SOCKET then
    CloseSocket(FSocket);
  dec(WSlibRef);
  if WSlibRef = 0 then
    WSACleanup;
  inherited Done;
end;

function TTCPStream.ReadLine : String;
var
  c : char;
  i : integer;
begin
  i := 0;
  repeat
    Read(c, 1);
    if not (c in [#10,#13]) then
    begin
      inc(i);
      Result[i] := c;
    end;
  until (c = #10) or (i = 255);
  Result[0] := chr(i);
end;

end.
