#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Frederik Petersen"
#define PLUGIN_VERSION "0.1.0"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <ripext>
#include <convars>

#pragma newdecls required

EngineVersion g_Game;
ConVar g_cvEnabled;
ConVar g_cvEndpoint;
HTTPClient g_httpClient;

public Plugin myinfo = 
{
    name = "TS Mover",
    author = PLUGIN_AUTHOR,
    description = "Allows moving players to teamspeak channels according to teams. Only works with appropiate web service.",
    version = PLUGIN_VERSION,
    url = "https://github.com/FrederikP/csgo-ts-mover"
};

public void OnPluginStart()
{
    g_Game = GetEngineVersion();
    if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
    {
        SetFailState("This plugin is for CSGO/CSS only.");	
    }
    g_cvEnabled = CreateConVar("sm_ts_mover_enabled", "1", "Team updates will be sent to web service.");
    g_cvEndpoint = CreateConVar("sm_ts_mover_endpoint", "http://localhost:6666", "The endpoint of the required web service.");
    
    HookEvent("round_start", Event_RoundStart);
    
    AutoExecConfig(true, "ts_mover");
    char sBuf[128];
    g_cvEndpoint.GetString(sBuf, sizeof(sBuf));
    g_httpClient = new HTTPClient(sBuf);
    g_cvEndpoint.AddChangeHook(OnEndpointChange);
}

public void OnEndpointChange(ConVar convar, char[] oldValue, char[] newValue) {
    g_httpClient = new HTTPClient(newValue);
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast) {
    if (g_cvEnabled.IntValue == 1) {
        JSONArray ts = new JSONArray();
        JSONArray cts = new JSONArray();
        for (int i = 1; i < MaxClients; i++) {
            if (IsValidClient(i)) {
                char steamID[18];
                GetClientAuthId(i, AuthId_SteamID64, steamID, sizeof(steamID));
                if (GetClientTeam(i) == CS_TEAM_CT) {
                    cts.PushString(steamID);
                } else if (GetClientTeam(i) == CS_TEAM_T) {
                    ts.PushString(steamID);
                }
            }
        }
        JSONObject resultObject = new JSONObject();
        resultObject.Set("cts", cts);
        resultObject.Set("ts", ts);

        g_httpClient.Post("teams", resultObject, OnTeamsSent);
    }
}

public void OnTeamsSent(HTTPResponse response, any value)
{
    if (response.Status != HTTPStatus_Created) {
        // Failed to post teams
        return;
    }
    if (response.Data == null) {
        // Invalid JSON response
        return;
    }

} 

/**
 * Function to identify if a client is valid and in game.
 */
stock bool IsValidClient(int client) {
    if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
        return true;
    return false;
}
