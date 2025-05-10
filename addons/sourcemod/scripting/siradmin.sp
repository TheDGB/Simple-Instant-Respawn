/*****************************************************************************
--------------------------- Instant Respawn Admin ---------------------------
******************************************************************************/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <morecolors>
#include <tf2>

#define PLUGIN_NAME "Simple Instant Admin Respawn"
#define PLUGIN_AUTHOR "DGB"
#define PLUGIN_VERSION "1.5"

// Convars
ConVar g_Cvar_InstantRespawnHudEnable;
ConVar g_Cvar_InstantRespawnEnabled;

// Handlers
Handle g_hInstantRespawnHudTimer[MAXPLAYERS+1];

// Bools
bool g_bInstantRespawn[MAXPLAYERS+1];

public Plugin myinfo = 
{
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    version = PLUGIN_VERSION,
    url = ""
};

// ////////////////////////
// //                    //
// //    Plugin Start    //
// //                    //
// ////////////////////////

// Plugin Start

public void OnPluginStart()
{
    LoadTranslations("instantrespawnadmin.phrases");
    
    g_Cvar_InstantRespawnEnabled = CreateConVar("sm_instantrespawnadmin_enabled", "1", "Enable the Instant Respawn Admin.");
    g_Cvar_InstantRespawnHudEnable = CreateConVar("sm_instantrespawnadmin_hud", "1", "Enable the Instant Respawn Admin HUD.");
    
    RegAdminCmd("sm_norespawn", Command_NoRespawn, ADMFLAG_SLAY, "Enables instant respawn for yourself.");
    RegAdminCmd("sm_selfinstarespawn", Command_NoRespawn, ADMFLAG_SLAY, "Enables instant respawn for yourself.");
    
    RegAdminCmd("sm_instarespawn", Command_InstaRespawn, ADMFLAG_SLAY, "Enables instant respawn for a player.");
    RegAdminCmd("sm_setinstantrespawn", Command_InstaRespawn, ADMFLAG_SLAY, "Enables instant respawn for a player.");
	
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
}

// ////////////////////////
// //                    //
// //      Events        //
// //                    //
// ////////////////////////

// Events

public void OnClientDisconnect(int client)
{
    StopInstantRespawnHudTimer(client);
    g_bInstantRespawn[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && g_bInstantRespawn[client])
    {
        CreateTimer(0.1, Timer_RespawnPlayer, GetClientUserId(client));
    }
}

// /////////////////////////////////
// //                             //
// //      Commands Actions       //
// //                             //
// /////////////////////////////////

// Commands Actions

public Action Command_NoRespawn(int client, int args)
{
    if(!g_Cvar_InstantRespawnEnabled.BoolValue) {
        CPrintToChat(client, "%t", "#IRAPluginDisabled");
        return Plugin_Handled;
    }
    
    if (!IsClientInGame(client))
        return Plugin_Handled;

    g_bInstantRespawn[client] = !g_bInstantRespawn[client];

    if (g_bInstantRespawn[client])
    {
        CPrintToChat(client, "%t", "#IRAActivated");
        
        if(g_Cvar_InstantRespawnHudEnable.BoolValue) 
        {
            StartInstantRespawnHudTimer(client);
        }
    }
    else
    {
        CPrintToChat(client, "%t", "#IRADisabled");
        StopInstantRespawnHudTimer(client);
    }

    return Plugin_Handled;
}

public Action Command_InstaRespawn(int client, int args)
{
    if(!g_Cvar_InstantRespawnEnabled.BoolValue)
    {
        CPrintToChat(client, "%t", "#IRAPluginDisabled");
        return Plugin_Handled;
    }

    if(args < 1)
    {
        CPrintToChat(client, "{red}Usage: sm_instarespawn <name|#userid>");
        return Plugin_Handled;
    }

    char targetName[MAX_TARGET_LENGTH];
    GetCmdArg(1, targetName, sizeof(targetName));

    int target = FindTarget(client, targetName, true, false);
    if(target == -1) return Plugin_Handled;

    bool newState = !g_bInstantRespawn[target];
    g_bInstantRespawn[target] = newState;

    if(newState)
    {
        CPrintToChat(client, "%t %N", "#IRAAdminTarget", target);
        CPrintToChat(target, "%t", "#IRAAdminClient");
        
        if(g_Cvar_InstantRespawnHudEnable.BoolValue)
        {
            StartInstantRespawnHudTimer(target);
        }
    }
    else
    {
        CPrintToChat(client, "%t %N", "#IRAAdminTargetDisabled", target);
        CPrintToChat(target, "%t","#IRAAdminClientDisabled");
        StopInstantRespawnHudTimer(target);
    }

    return Plugin_Handled;
}

// ////////////////////////
// //                    //
// //      Timers        //
// //                    //
// ////////////////////////

// Timers

void StartInstantRespawnHudTimer(int client)
{
    StopInstantRespawnHudTimer(client);
    g_hInstantRespawnHudTimer[client] = CreateTimer(1.0, Timer_InstantRespawnHUD, GetClientUserId(client), TIMER_REPEAT);
}

void StopInstantRespawnHudTimer(int client)
{
    if (g_hInstantRespawnHudTimer[client] != null)
    {
        KillTimer(g_hInstantRespawnHudTimer[client]);
        g_hInstantRespawnHudTimer[client] = null;
    }
}

public Action Timer_InstantRespawnHUD(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    
    if (client == 0 || !IsClientInGame(client) || !g_bInstantRespawn[client])
    {
        g_hInstantRespawnHudTimer[client] = null;
        return Plugin_Stop;
    }

    SetHudTextParams(-0.10, -0.83, 1.1, 255, 0, 0, 255);
    ShowSyncHudText(client, CreateHudSynchronizer(), "%t", "#IRAHudText");
    
    return Plugin_Continue;
}

public Action Timer_RespawnPlayer(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client))
    {
        TF2_RespawnPlayer(client);
    }
    return Plugin_Continue;
}