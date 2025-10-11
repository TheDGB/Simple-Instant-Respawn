/*****************************************************************************
--------------------------- Instant Respawn Admin ---------------------------
******************************************************************************/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <morecolors>
#include <tf2>

#define PLUGIN_NAME "Simple Instant Admin Respawn"
#define PLUGIN_AUTHOR "DGB"
#define PLUGIN_VERSION "2.2"

// Convars
ConVar g_hCvarEnabled;
ConVar g_hCvarHudEnable;
ConVar g_hCvarWaitingForPlayers;
ConVar g_hCvarAdminOnly;
ConVar g_hCvarAdminFlag;
ConVar g_hCvarAutoEnableAll;
ConVar g_hCvarEnableBots;

// Handlers
Handle g_hInstantRespawnHudTimer[MAXPLAYERS+1];
Handle g_hHudSync;

// Bools
bool g_bInstantRespawn[MAXPLAYERS+1];
bool g_bWaitingForPlayers = false;

// Admin Flags
AdminFlag g_AdminFlag;

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

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("instantrespawnadmin.phrases");

    g_hCvarEnabled = CreateConVar("sm_instantrespawnadmin_enabled", "1", "Enable the Instant Respawn Admin plugin.", 0, true, 0.0, true, 1.0);
    g_hCvarHudEnable = CreateConVar("sm_instantrespawnadmin_hud", "1", "Enable the Instant Respawn Admin HUD.", 0, true, 0.0, true, 1.0);
    g_hCvarWaitingForPlayers = CreateConVar("sm_instantrespawnadmin_waitingforplayers", "1", "Enable instant respawn for everyone during 'Waiting for players' state.", 0, true, 0.0, true, 1.0);
    g_hCvarAdminOnly = CreateConVar("sm_instantrespawnadmin_adminonly", "0", "If enabled, only admins with the specified flag can receive instant respawn.", 0, true, 0.0, true, 1.0);
    g_hCvarAdminFlag = CreateConVar("sm_instantrespawnadmin_adminflag", "b", "Admin flag required to receive instant respawn if sm_instantrespawnadmin_adminonly is enabled.");
    g_hCvarAutoEnableAll = CreateConVar("sm_instantrespawnadmin_all", "0", "Automatically enable instant respawn for every player who joins the server.", 0, true, 0.0, true, 1.0);
    g_hCvarEnableBots = CreateConVar("sm_instantrespawnadmin_bots", "1", "Allow bots to have instant respawn.", 0, true, 0.0, true, 1.0);

    RegAdminCmd("sm_instarespawn", Command_InstaRespawn, ADMFLAG_SLAY, "Toggles instant respawn for target(s). Usage: sm_instarespawn <target> [1|0]");
    RegAdminCmd("sm_setinstantrespawn", Command_InstaRespawn, ADMFLAG_SLAY, "Alias for sm_instarespawn.");
    RegAdminCmd("sm_norespawn", Command_NoRespawn, ADMFLAG_SLAY, "Toggles instant respawn for yourself.");
    RegAdminCmd("sm_selfinstarespawn", Command_NoRespawn, ADMFLAG_SLAY, "Alias for sm_norespawn.");

    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

    g_hCvarAdminFlag.AddChangeHook(OnAdminFlagChanged);

    AutoExecConfig(true, "plugin.instantrespawnadmin");
}

public void OnMapStart()
{
    g_hHudSync = CreateHudSynchronizer();
}

public void OnConfigsExecuted()
{
    char sFlag[8];
    g_hCvarAdminFlag.GetString(sFlag, sizeof(sFlag));
    g_AdminFlag = view_as<AdminFlag>(ReadFlagString(sFlag));
}

public void OnAdminFlagChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    g_AdminFlag = view_as<AdminFlag>(ReadFlagString(newValue));
}

// ////////////////////////
// //                    //
// //      Forwards      //
// //                    //
// ////////////////////////

public void OnClientPutInServer(int client)
{
    g_bInstantRespawn[client] = false;
    StopInstantRespawnHudTimer(client);

    if (g_hCvarAutoEnableAll.BoolValue)
    {
        if (IsFakeClient(client) && !g_hCvarEnableBots.BoolValue)
        {
            return;
        }
        if (CanReceiveInstantRespawn(client))
        {
            g_bInstantRespawn[client] = true;
        }
    }

    if (g_bWaitingForPlayers && g_hCvarWaitingForPlayers.BoolValue)
    {
        StartInstantRespawnHudTimer(client);
    }
    else if (g_bInstantRespawn[client])
    {
        StartInstantRespawnHudTimer(client);
    }
}

public void OnClientDisconnect(int client)
{
    StopInstantRespawnHudTimer(client);
    g_bInstantRespawn[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || !IsClientInGame(client))
    {
        return;
    }

    if (g_bInstantRespawn[client] || (g_hCvarWaitingForPlayers.BoolValue && g_bWaitingForPlayers))
    {
        CreateTimer(0.1, Timer_RespawnPlayer, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

bool CanReceiveInstantRespawn(int client)
{
    if (!g_hCvarAdminOnly.BoolValue)
    {
        return true;
    }
    return CheckCommandAccess(client, "sm_instantrespawn_receive", view_as<int>(g_AdminFlag));
}

public void TF2_OnWaitingForPlayersStart()
{
    g_bWaitingForPlayers = true;
    if (g_hCvarWaitingForPlayers.BoolValue && g_hCvarHudEnable.BoolValue)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                StartInstantRespawnHudTimer(i);
            }
        }
    }
}

public void TF2_OnWaitingForPlayersEnd()
{
    g_bWaitingForPlayers = false;
    if (g_hCvarWaitingForPlayers.BoolValue && g_hCvarHudEnable.BoolValue)
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !g_bInstantRespawn[i])
            {
                StopInstantRespawnHudTimer(i);
            }
        }
    }
}

// /////////////////////////////////
// //                             //
// //      Commands Actions       //
// //                             //
// /////////////////////////////////

public Action Command_NoRespawn(int client, int args)
{
    if(!g_hCvarEnabled.BoolValue) {
        CPrintToChat(client, "%t", "#IRAPluginDisabled");
        return Plugin_Handled;
    }

    if (!IsClientInGame(client))
        return Plugin_Handled;

    if (!g_bInstantRespawn[client] && !CanReceiveInstantRespawn(client)) {
        CPrintToChat(client, "%t", "#IRANoPermission");
        return Plugin_Handled;
    }

    g_bInstantRespawn[client] = !g_bInstantRespawn[client];

    if (g_bInstantRespawn[client])
    {
        CPrintToChat(client, "%t", "#IRAActivated");
        StartInstantRespawnHudTimer(client);
    }
    else
    {
        CPrintToChat(client, "%t", "#IRADisabled");
        if (!g_bWaitingForPlayers || !g_hCvarWaitingForPlayers.BoolValue) {
            StopInstantRespawnHudTimer(client);
        }
    }

    return Plugin_Handled;
}

public Action Command_InstaRespawn(int client, int args)
{
    if (!g_hCvarEnabled.BoolValue)
    {
        CPrintToChat(client, "%t", "#IRAPluginDisabled");
        return Plugin_Handled;
    }

    if (args < 1)
    {
        CReplyToCommand(client, "[SM] Usage: sm_instarespawn <target> [1|0]");
        return Plugin_Handled;
    }

    char sTarget[MAX_TARGET_LENGTH];
    GetCmdArg(1, sTarget, sizeof(sTarget));

    int iState = -1;
    if (args > 1)
    {
        char sState[4];
        GetCmdArg(2, sState, sizeof(sState));
        iState = StringToInt(sState);
    }

    int[] iTargets = new int[MAXPLAYERS];
    int iTargetCount;
    char sTargetName[MAX_TARGET_LENGTH];
    bool bIsML;

    if ((iTargetCount = ProcessTargetString(sTarget, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
    {
        return Plugin_Handled;
    }

    int iAffectedCount = 0;
    for (int i = 0; i < iTargetCount; i++)
    {
        int iTargetClient = iTargets[i];

        if (!IsClientInGame(iTargetClient))
        {
            continue;
        }

        if (IsFakeClient(iTargetClient) && !g_hCvarEnableBots.BoolValue)
        {
            continue;
        }

        bool bNewState;
        if (iState == 0) bNewState = false;
        else if (iState == 1) bNewState = true;
        else bNewState = !g_bInstantRespawn[iTargetClient];

        if (bNewState && !CanReceiveInstantRespawn(iTargetClient))
        {
            if (client != 0)
            {
                CReplyToCommand(client, "%t", "#IRATargetNoFlag", iTargetClient);
            }
            continue;
        }

        g_bInstantRespawn[iTargetClient] = bNewState;
        iAffectedCount++;

        if (bNewState)
        {
            if (client != iTargetClient) CPrintToChat(client, "%t %N", "#IRAAdminTarget", iTargetClient);
            CPrintToChat(iTargetClient, "%t", "#IRAActivated");
            StartInstantRespawnHudTimer(iTargetClient);
        }
        else
        {
            if (client != iTargetClient) CPrintToChat(client, "%t %N", "#IRAAdminTargetDisabled", iTargetClient);
            CPrintToChat(iTargetClient, "%t", "#IRADisabled");
            if (!g_bWaitingForPlayers || !g_hCvarWaitingForPlayers.BoolValue) {
                 StopInstantRespawnHudTimer(iTargetClient);
            }
        }
    }

    if (iTargetCount > 1 && iAffectedCount > 0)
    {
        CPrintToChat(client, "%t", "#IRAAffectedCount", iAffectedCount);
    }

    return Plugin_Handled;
}

// ////////////////////////
// //                    //
// //      Timers        //
// //                    //
// ////////////////////////

void StartInstantRespawnHudTimer(int client)
{
    if (g_hCvarHudEnable.BoolValue && g_hInstantRespawnHudTimer[client] == null)
    {
        g_hInstantRespawnHudTimer[client] = CreateTimer(1.0, Timer_InstantRespawnHUD, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
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

    if (client == 0 || !IsClientInGame(client)
        || (!g_bInstantRespawn[client] && !(g_hCvarWaitingForPlayers.BoolValue && g_bWaitingForPlayers)))
    {
        if (client > 0 && client <= MaxClients)
        {
            g_hInstantRespawnHudTimer[client] = null;
        }
        return Plugin_Stop;
    }

    if (g_bInstantRespawn[client] || (g_hCvarWaitingForPlayers.BoolValue && g_bWaitingForPlayers))
    {
        SetHudTextParams(-0.10, -0.83, 1.1, 255, 0, 0, 255);
        ShowSyncHudText(client, g_hHudSync, "%t", "#IRAHudText");
    }

    return Plugin_Continue;
}

public Action Timer_RespawnPlayer(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client) && !IsPlayerAlive(client))
    {
        TF2_RespawnPlayer(client);
    }
    return Plugin_Handled;
}