#pragma semicolon 1

#include <sourcemod>
#include <steamcore>

#define PLUGIN_URL "https://github.com/polvora/Inviter"
#define PLUGIN_VERSION "1.5"
#define PLUGIN_NAME "Inviter"
#define PLUGIN_AUTHOR "Statik"

public Plugin:myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = "Steam group invites via game commands.",
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

new Handle:cvarGroupID;
new Handle:cvarAdminFlags;
new Handle:cvarAllInviteThemselves;
new Handle:cvarAllInviteOthers;
new Handle:cvarTimeBetweenInvites;
new Handle:cvarRemoveFriends;

new Handle:disabledClients;
new Handle:removingClients;
new ReplySource:sources[32];

new pluginId = 4147279;

public OnPluginStart()
{
	// Cvars
	CreateConVar("inviter_version", PLUGIN_VERSION, "Inviter Version", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	cvarGroupID = CreateConVar("in_steamgroupid", "", "Group id where people is going to be invited.", 0);
	cvarAdminFlags = CreateConVar("in_adminflags", "b", "Administrator flags to bypass the restrictions.", 0);
	cvarAllInviteThemselves = CreateConVar("in_allcaninvitethemselves", "1", "Allows everybody to send invites to them themselves.", 0, true, 0.0, true, 1.0);
	cvarAllInviteOthers = CreateConVar("in_allcaninviteothers", "0", "Allows everybody to send invites to other clients.", 0, true, 0.0, true, 1.0);
	cvarTimeBetweenInvites = CreateConVar("in_timebetweeninvites", "240", "Time between invites that non-admins must wait to send more invites.", 0, true, 0.0, true, 7200.0);
	cvarRemoveFriends = CreateConVar("in_removefriends", "1", "Remove mfriends after inviting them to group.", 0, true, 0.0, true, 1.0);
	
	RegConsoleCmd("sm_invite", cmdInvite, "Sends a group invite");

	disabledClients = CreateArray();
	removingClients = CreateArray(); 
	
	LoadTranslations("common.phrases");
}

public Action:cmdInvite(client, args)
{
	new bool:isAdmin = IsClientAdmin(client);
	
	decl String:steamGroup[65];
	GetConVarString(cvarGroupID, steamGroup, sizeof(steamGroup));
	if (StrEqual(steamGroup, "")) 
	{
		ReplyToCommand(client, "\x07FFF047Steam group is not configured.");
		return Plugin_Handled;
	}
	
	if (!IsClientAuthorized(client)) ReplyToCommand(client, "\x07FFF047Server is not connected to Steam at this moment, try again in a few minutes.");
	if (!isAdmin)
	{
		new id = GetSteamAccountID(client);
		if (FindValueInArray(disabledClients, id) != -1)
		{
			ReplyToCommand(client, "\x07FFF047You must wait \x01%i \x07FFF047seconds or less to send another invite.", GetConVarInt(cvarTimeBetweenInvites));
			return Plugin_Handled;
		}
		PushArrayCell(disabledClients, id);
		CreateTimer(GetConVarFloat(cvarTimeBetweenInvites), cooldown, id);
	}
	
	switch(args)
	{
		case 0:
		{
			if (client == 0)
			{
				ReplyToCommand(client, "You cannot invite a server to a Steam group.");
				return Plugin_Handled;
			}
			if (isAdmin || GetConVarBool(cvarAllInviteThemselves))
			{
				new String:steamID64[32];
				GetClientAuthId(client, AuthId_SteamID64, steamID64, sizeof steamID64);
				sources[client] = GetCmdReplySource();
				SteamCommunityGroupInvite(steamID64, steamGroup, pluginId);
				return Plugin_Handled;
			}
			
			ReplyToCommand(client, "\x07FFF047You do not have access to this command.");
			return Plugin_Handled;			
		}
		
		case 1:
		{
			if (isAdmin || GetConVarBool(cvarAllInviteOthers))
			{
				decl String:arg[64];
				GetCmdArg(1, arg, sizeof arg);
				new target = FindTarget(client, arg, true, false);
				if (target == -1)
				{
					decl String:buffer[32];
					GetCmdArg(0, buffer, sizeof(buffer));
					ReplyToCommand(client, "\x07FFF047Incorrect target, usage: \x01%s [#userid|name]", buffer);
					return Plugin_Handled;
				}
				new String:steamID64[32];
				GetClientAuthId(target, AuthId_SteamID64, steamID64, sizeof steamID64);
				sources[client] = GetCmdReplySource();
				SteamCommunityGroupInvite(steamID64, steamGroup, pluginId);
				
				return Plugin_Handled;
			}
			
			ReplyToCommand(client, "\x07FFF047You are not allowed to invite other people.");
			return Plugin_Handled;						
		}	
	}
	
	ReplyToCommand(client, "\x07FFF047Incorrect syntax, usage: \x01%s [#userid|name]");
	return Plugin_Handled;
}

public OnCommunityGroupInviteResult(const String:invitee[], const String:group[], errorCode, any:pid)
{
	if (pid != pluginId) return;
	
	new client = FindClientFromSteamID64(invitee);
	if (client == 0) return;
	
	SetCmdReplySource(sources[client]);
	if (errorCode == 0x00) ReplyToCommand(client, "\x07FFF047The group invite has been sent.");
	else
	{
		if (errorCode == 0x28)
		{	
			SteamChatConnect();
			SteamCommunityAddFriend(invitee, pluginId);
		}
		else if(errorCode == 0x01) ReplyToCommand(client, "\x07FFF047Server logged out, try again in a few seconds.");
		else if(errorCode == 0x02) ReplyToCommand(client, "\x07FFF047There was a timeout in your request, try again.");
		else if(errorCode == 0x03) ReplyToCommand(client, "\x07FFF047Steam servers are down, try again in a few minutes.");
		else if (errorCode < 0x10)
		{
			new steamid = GetSteamAccountID(client);
			new i;
			if ((i = FindValueInArray(disabledClients, steamid)) != -1)
				RemoveFromArray(disabledClients, i);
		}
		else if(errorCode == 0x27) ReplyToCommand(client, "\x07FFF047Target has already received an invite or is already on the group.");
		else ReplyToCommand(client, "\x07FFF047There was an error \x010x%02x \x07FFF047while sending your invite :(", errorCode);
		
	}
}

public OnCommunityAddFriendResult(const String:friend[], errorCode, any:pid)
{
	if (pid != pluginId) return;
	
	new client = FindClientFromSteamID64(friend);
	if (client == 0) return;
	
	SetCmdReplySource(sources[client]);
	if (errorCode == 0x00) ReplyToCommand(client, "\x07FFF047Friend request sent, please accept it to get a group invite.");
	else if (errorCode == 0x31) ReplyToCommand(client, "\x07FFF047You ignored the friend request i sent you.");
	else if (errorCode == 0x32) ReplyToCommand(client, "\x07FFF047It seems you have blocked the account that sends you the invite.");
	else ReplyToCommand(client, "\x07FFF047There was an error \x010x%02x \x07FFF047while sending your invite :(", errorCode);
}

public OnChatRelationshipChange(const String:account[], SteamChatRelationship:relationship)
{
	if (relationship != SteamChatRelationshipFRIENDS) return;
	
	if (FindValueInArray(removingClients, SteamID64to32(account)) != -1) return;
	
	new String:steamGroup[65];
	GetConVarString(cvarGroupID, steamGroup, sizeof(steamGroup));
	
	SteamCommunityGroupInvite(account, steamGroup, pluginId); // We are now friends.
	SteamChatSendMessage(account, "Thanks for accepting the friend request, now please accept the group invite i sent you to finish :)", pluginId);
	
	if (GetConVarBool(cvarRemoveFriends))  CreateTimer(20.0, removeTimer, SteamID64to32(account));
}

public Action:removeTimer(Handle:timer, any:SteamID32)
{
	new String:SteamID64[32];
	SteamID32to64(SteamID32, SteamID64, sizeof SteamID64);
	
	SteamCommunityRemoveFriend(SteamID64);
}

public Action:cooldown(Handle:timer, any:id)
{
	new i;
	if ((i = FindValueInArray(disabledClients, id)) != -1)
		RemoveFromArray(disabledClients, i);
}

bool:IsClientAdmin(client)
{
	if (client == 0) return true;
	decl String:strFlags[32];
	GetConVarString(cvarAdminFlags, strFlags, sizeof strFlags);
	new flags = ReadFlagString(strFlags);
	if (flags & GetUserFlagBits(client) || ADMFLAG_ROOT & GetUserFlagBits(client))
		return true;
	return false;
}
