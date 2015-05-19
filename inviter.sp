#pragma semicolon 1

#include <sourcemod>
#include <steamcore>

#define PLUGIN_URL ""
#define PLUGIN_VERSION "1.0"
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

new Handle:disabledClients;
new ReplySource:sources[32];

public OnPluginStart()
{
	// Cvars
	CreateConVar("inviter_version", PLUGIN_VERSION, "Force Picker Version", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	cvarGroupID = CreateConVar("in_steamgroupid", "", "Group id where people is going to be invited.", FCVAR_PLUGIN);
	cvarAdminFlags = CreateConVar("in_adminflags", "b", "Administrator flags to bypass the restrictions.", FCVAR_PLUGIN);
	cvarAllInviteThemselves = CreateConVar("in_allcaninvitethemselves.", "1", "Allows everybody to send invites to them themselves.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	cvarAllInviteOthers = CreateConVar("in_allcaninviteothers.", "0", "Allows everybody to send invites to other clients.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	cvarTimeBetweenInvites = CreateConVar("in_timebetweeninvites", "240", "Time between invites that non-admins must wait to send more invites.", FCVAR_PLUGIN, true, 0.0, true, 7200.0);
	
	RegConsoleCmd("sm_invite", cmdInvite, "Sends a group invite");

	disabledClients = CreateArray();
	
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
	
	if (!isAdmin)
	{
		new id = GetSteamAccountID(client);
		if (FindValueInArray(disabledClients, id) != -1)
		{
			ReplyToCommand(client, "\x07FFF047You must wait \x01%i \x07FFF047seconds or less to send another invite.", GetConVarInt(cvarTimeBetweenInvites));
			return Plugin_Handled;
		}
		new Float:interval = GetConVarInt(cvarTimeBetweenInvites);
		PushArrayCell(disabledClients, id);
		CreateTimer(interval, cooldown, id);
	}
	
	if (args == 0)
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
			SteamGroupInvite(client, steamID64, steamGroup, callback);
			return Plugin_Handled;
		}
		ReplyToCommand(client, "\x07FFF047You do not have access to this command.");
		return Plugin_Handled;
	}
	else if (args == 1)
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
			SteamGroupInvite(client, steamID64, steamGroup, callback);
			return Plugin_Handled;
		}
		ReplyToCommand(client, "\x07FFF047You are not allowed to invite other people.");
		return Plugin_Handled;
	}
	ReplyToCommand(client, "\x07FFF047Incorrect syntax, usage: \x01%s [#userid|name]");
	return Plugin_Handled;
}

public Action:cooldown(Handle:timer, any:id)
{
	new i;
	if ((i = FindValueInArray(disabledClients, id)) != -1)
		RemoveFromArray(disabledClients, i);
}

public callback(client, bool:success, errorCode, any:data)
{
	if (client != 0 && !IsClientInGame(client)) return;
	
	SetCmdReplySource(sources[client]);
	if (success) ReplyToCommand(client, "\x07FFF047The group invite has been sent.");
	else
	{
		if (errorCode < 0x10 || errorCode == 0x23)
		{
			new id = GetSteamAccountID(client);
			new i;
			if ((i = FindValueInArray(disabledClients, id)) != -1)
				RemoveFromArray(disabledClients, i);
		}
		if (errorCode == 0x01) ReplyToCommand(client, "\x07FFF047Server is busy with another task at this time, try again in a few seconds.");
		else if (errorCode == 0x02) ReplyToCommand(client, "\x07FFF047There was a timeout in your request, try again.");
		else if (errorCode == 0x23) ReplyToCommand(client, "\x07FFF047Session expired, retry to reconnect.");
		else if (errorCode == 0x27) ReplyToCommand(client, "\x07FFF047Target has already received an invite or is already on the group.");
		else ReplyToCommand(client, "\x07FFF047There was an error \x010x%02x \x07FFF047while sending your invite :(", errorCode);
	}
}

public bool:IsClientAdmin(client)
{
	decl String:strFlags[32];
	GetConVarString(cvarAdminFlags, strFlags, sizeof strFlags);
	new flags = ReadFlagString(strFlags);
	if (flags & GetUserFlagBits(client) || ADMFLAG_ROOT & GetUserFlagBits(client))
		return true;
	return false;
}
