class S3RCon extends AOCRCon;

enum MessageType_New
{
	SERVER_CONNECT,
	SERVER_CONNECT_SUCCESS,
	PASSWORD,
	PLAYER_CHAT,
	PLAYER_CONNECT,
	PLAYER_DISCONNECT,
	SAY_ALL,
	SAY_ALL_BIG,
	SAY,
	MAP_CHANGED,
	MAP_LIST,
    CHANGE_MAP,
    ROTATE_MAP,
	TEAM_CHANGED,
	NAME_CHANGED,
    KILL,
	SUICIDE,
	KICK_PLAYER,
	TEMP_BAN_PLAYER,
	BAN_PLAYER,
	UNBAN_PLAYER,
	ROUND_END,
	PING,
	CHANGE_TEAM,
	SET_NAME
};

function HandleMessage(AOCRConPacket Packet)
{
	switch (RConState)
	{
		case RCON_Connecting:
			if ( Packet.MessageType == MessageType_New.PASSWORD )
			{
				HandlePassword(Packet);
			}
			else
			{
				CloseConnection();
			}
			break;

		case RCON_Connected:
			switch(Packet.MessageType)
			{
				case MessageType_New.SAY_ALL:
					HandleSayAll(Packet);
				break;
				case MessageType_New.SAY_ALL_BIG:
					HandleSayAllBIG(Packet);
				break;
				case MessageType_New.SAY:
					HandleSay(Packet);
				break;
				case MessageType_New.CHANGE_MAP:
					HandleChangeMap(Packet);
				break;
				case MessageType_New.ROTATE_MAP:
					HandleRotateMap(Packet);
				break;
				case MessageType_New.KICK_PLAYER:
					HandleKickPlayer(Packet);
				break;
				case MessageType_New.TEMP_BAN_PLAYER:
					HandleTempBanPlayer(Packet);
				break;
				case MessageType_New.BAN_PLAYER:
					HandleBanPlayer(Packet);
				break;
				case MessageType_New.UNBAN_PLAYER:
					HandleUnbanPlayer(Packet);
				break;
				case MessageType_New.CHANGE_TEAM:
					HandleChangeTeam(Packet);
				break;
				case MessageType_New.SET_NAME:
					HandleChangeName(Packet);
				break;
			}
			break;
	}
}

function SendCurrentGameInfo()
{
	// Send all players
	local PlayerReplicationInfo PRI;
	foreach WorldInfo.GRI.PRIArray(PRI)
	{
		GameEvent_PlayerConnect(PRI);
	}

	// Send current map
	GameEvent_MapChanged_New(AOCGame(Worldinfo.Game).GetCurrentMap());

	// Send map rotation list 이게 안보내진다.
	GameEvent_MapList(AOCGame(Worldinfo.Game).MapList);
}

function GameEvent_BroadcastMessage(PlayerReplicationInfo PRI, string Message, int Team)
{
	local AOCPlayerController PC;	
	local AOCRConPacket Packet;
	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
	{
		PC.ClientDisplayConsoleMessage("test");
	}
	Packet = new class'AOCRConPacket';
	Packet.SetMessageType(MessageType.PLAYER_CHAT);
	Packet.AddQWord(PRI.UniqueId.Uid);
	Packet.AddString(Message);
	Packet.AddInt(Team);
	SendPacket(Packet);
}

function GameEvent_MapChanged_New(string mapName)
{
	local AOCRConPacket Packet;
	Packet = new class'AOCRConPacket';

	Packet.SetMessageType(MessageType.MAP_CHANGED);
	Packet.AddString(mapName);
	SendPacket(Packet);
}

function GameEvent_TeamChanged_New(PlayerReplicationInfo PRI, int Team)
{
	local AOCRConPacket Packet;
	Packet = new class'AOCRConPacket';

	Packet.SetMessageType(MessageType.TEAM_CHANGED);
	Packet.AddQWord(PRI.UniqueId.Uid);
	Packet.AddInt(Team);
	Packet.AddInt(AOCPRI(PRI).MyRank);
	SendPacket(Packet);
}

function HandleSayAll(AOCRConPacket Packet)
{
	local array<string> lines;
	local string Message;
	local int i;

	Message = Packet.GetString();
	lines = SplitLines(Message);
	for (i = 0; i < lines.Length; i++)
	{
		AOCGame(Worldinfo.Game).BroadcastMessage(none, lines[i], EFAC_ALL, true);
	}
}

/*
 * Shows the large header at the top of the screen.
 * 
 * @param   Text        The text to show in the header
 * @param   Id          If this is not 'none', this header becomes a persistent header and will only hide when this Id is cleared
 * @param   SubHeading  Subheading text to show in the header
 * @param   bShowTimer  If TRUE, show the game timer in the header
 * @param   bShowObjectiveProgress  if TRUE, automatically set the two progress bars to the teams' progress; if false, hide the bars unless ManualProgressAgatha or ManualProgressMason is set
 * @param   ManualProgressAgatha    if >= 0, set the Agatha progress bar to this value (meaningless if bShowObjectiveProgress is TRUE) 
 * @param   ManualProgressMason     if >= 0, set the Mason progress bar to this value (meaningless if bShowObjectiveProgress is TRUE)
 * @param   ManualNameAgatha   if set, set "Agatha"'s name to this (must be pre-localized)
 * @param   ManualNameMason    if set, set "Mason"'s name to this (must be pre-localized)
 * */
 
function HandleSayAllBIG(AOCRConPacket Packet)
{
	//local array<string> lines;
	local AOCPlayerController PC;	
	local string Message;
	Message = Packet.GetString();
	//lines = SplitLines(Message);
	foreach WorldInfo.AllControllers(class'AOCPlayerController', PC)
	{
		PC.ClientShowLocalizedHeaderText("Admin",,Message,true,false);
	}
}

function HandleSay(AOCRConPacket Packet)
{
	local array<string> lines;
	local AOCPlayerController Controller;
	local string Message;
	local QWord PlayerId;
	local int i;

	PlayerId = Packet.GetGUID();
	Message = Packet.GetString();
	Controller = GetPlayerControllerFromGUID(PlayerId);
	lines = SplitLines(Message);
	for (i = 0; i < lines.Length; i++)
	{
		AOCGame(Worldinfo.Game).BroadcastMessageToPlayer(Controller, lines[i]);
	}
}

function HandleKickPlayer(AOCRConPacket Packet)
{
	local AOCPlayerController Controller;
	local string Message;
	local QWord PlayerId;

	PlayerId = Packet.GetGUID();
	Message = Packet.GetString();
	Controller = GetPlayerControllerFromGUID(PlayerId);
	Worldinfo.Game.AccessControl.KickPlayer(Controller, Message);
}

function HandleTempBanPlayer(AOCRConPacket Packet)
{
	local AOCPlayerController Controller;
	local string Message;
	local QWord PlayerId;
	local int Seconds;

	PlayerId = Packet.GetGUID();
	Message = Packet.GetString();
	Seconds = Packet.GetInt();
	Controller = GetPlayerControllerFromGUID(PlayerId);
	AOCAccessControl(Worldinfo.Game.AccessControl).KickBanGlobal(Controller, float(Seconds), Message);
}

function HandleBanPlayer(AOCRConPacket Packet)
{
	local AOCPlayerController Controller;
	local string Message;
	local QWord PlayerId;

	PlayerId = Packet.GetGUID();
	Message = Packet.GetString();
	Controller = GetPlayerControllerFromGUID(PlayerId);
	AOCAccessControl(Worldinfo.Game.AccessControl).KickBanGlobal(Controller, 0.0f, Message);
}

function HandleChangeTeam(AOCRConPacket Packet)
{
	local AOCPlayerController Controller;
//	local string Message;
	local QWord PlayerId;

	PlayerId = Packet.GetGUID();
//	Message = Packet.GetString();
	Controller = GetPlayerControllerFromGUID(PlayerId);
	RConChangeTeam(Controller);
}

function RConChangeTeam(AOCPlayerController Target)
{
	local int Offset, i;
	
	if(Target == none)
	{
		return;
	}
	
	if(Target.CurrentFamilyInfo.class == class'AOCFamilyInfo_Agatha_King' || Target.CurrentFamilyInfo.class == class'AOCFamilyInfo_Mason_King')
	{
		return;
	}
	
	if(Target.CurrentFamilyInfo.FamilyFaction == EFAC_Agatha)
	{
		Offset = 5;
	}
	else
	{
		Offset = -5;
	}
	
	for(i = 0; i < ArrayCount(AOCGRI(AOCGame(Worldinfo.Game).GameReplicationInfo).FamilyInfos) && AOCGRI(AOCGame(Worldinfo.Game).GameReplicationInfo).FamilyInfos[i] != Target.CurrentFamilyInfo; ++i);
	i += Offset;
	
	Target.SetNewClass(AOCGRI(AOCGame(Worldinfo.Game).GameReplicationInfo).FamilyInfos[i]);
}

function HandleChangeName(AOCRConPacket Packet)
{
	local AOCPlayerController Controller;
	local string Message;
	local QWord PlayerId;

	PlayerId = Packet.GetGUID();
	Message = Packet.GetString();
	Controller = GetPlayerControllerFromGUID(PlayerId);
	Controller.ClientDisplayConsoleMessage("CHN_Name");
	AOCGame(Worldinfo.Game).ChangeName(Controller,Message,true);
}