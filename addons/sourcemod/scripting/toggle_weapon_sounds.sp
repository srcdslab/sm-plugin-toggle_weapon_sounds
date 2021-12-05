#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>

#pragma newdecls required

#define PLUGIN_NAME     "Toggle Weapon Sounds clientprefs"
#define PLUGIN_VERSION  "2.0"

int g_iStopSound[MAXPLAYERS+1];
int g_iSelfStopSound[MAXPLAYERS+1];

bool g_bHooked;
bool g_bReplaceSilence[MAXPLAYERS+1];

Handle g_hClientCookie = INVALID_HANDLE;
Handle g_hClientCookie_SelfSound;

char ReplaceSoundPath[PLATFORM_MAX_PATH];

ConVar gCvar_ReplaceSound;
ConVar gCvar_WeaponScale;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "GoD-Tony, SHUFEN, tilgep, Hotfix by Oylsister",
	description = "Allows clients to stop hearing weapon sounds",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	g_hClientCookie = RegClientCookie("togglestopsound", "Toggle hearing weapon sounds", CookieAccess_Private);
	g_hClientCookie_SelfSound = RegClientCookie("togglestopsound_self", "Self weapon sounds volume", CookieAccess_Private);
	SetCookieMenuItem(StopSoundCookieHandler, 0, "Stop Weapon Sounds");

	gCvar_ReplaceSound = CreateConVar("sm_stopsound_replacesound_path", "weapons/usp/usp1.wav", "Path To the sound that you want to replace.");
	gCvar_WeaponScale = FindConVar("weapon_sound_falloff_multiplier");

	AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
	AddNormalSoundHook(Hook_NormalSound);
      
	CreateConVar("sm_stopsound_version", PLUGIN_VERSION, "Toggle Weapon Sounds", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	RegConsoleCmd("sm_stopsound", Command_StopSound, "Toggle hearing weapon sounds");
	RegConsoleCmd("sm_gunsound", Command_StopSound, "Toggle hearing weapon sounds");

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		OnClientCookiesCached(i);
	}

	LoadTranslations("togglestopsound.phrases");
}

public void OnMapStart()
{
	GetConVarString(gCvar_ReplaceSound, ReplaceSoundPath, sizeof(ReplaceSoundPath));

	if(ReplaceSoundPath[0])
		PrecacheSound(ReplaceSoundPath, true);
}

public void StopSoundCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_DisplayOption:
		{
		}
              
		case CookieMenuAction_SelectOption:
		{
			if(CheckCommandAccess(client, "sm_stopsound", 0))
			{
				PrepareMenu(client);
			}
			else
			{
				ReplyToCommand(client, "[SM] You have no access!");
			}
		}
	}
}

void PrepareMenu(int client)
{
	Handle menu = CreateMenu(YesNoMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem|MenuAction_Display);

	char sStatus[128];
	if(g_iStopSound[client] == 0)
		Format(sStatus, sizeof(sStatus), "%t: %t", "Client_Setting", "Disable");
		
	else if(g_iStopSound[client] == 1)
		Format(sStatus, sizeof(sStatus), "%t: %t", "Client_Setting", "Stop Sound");
		
	else
		Format(sStatus, sizeof(sStatus), "%t: %t", "Client_Setting", "Replace to Silenced Sound");
	
	char sTitle[256];
	Format(sTitle, sizeof(sTitle), "%t\n %s", "StopSound_Title", sStatus);
	SetMenuTitle(menu, "%s", sTitle);

	char sTemp[256];
	FormatEx(sTemp, sizeof(sTemp), "%t", "Disable");
	AddMenuItem(menu, "0", sTemp);
	FormatEx(sTemp, sizeof(sTemp), "%t", "Stop Sound");
	AddMenuItem(menu, "1", sTemp);
	FormatEx(sTemp, sizeof(sTemp), "%t", "Replace to Silenced Sound");
	AddMenuItem(menu, "2", sTemp);
	AddMenuItem(menu, "3", "-------------------------");
	AddMenuItem(menu, "4", "Self Sounds");
	
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 20);
}

public int YesNoMenu(Handle menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_DrawItem:
		{
			char sBuf[32];
			GetMenuItem(menu, param2, sBuf, sizeof(sBuf));

			if(StrEqual(sBuf, "0") && g_iStopSound[param1] == 0)
				return ITEMDRAW_DISABLED;

			else if(StrEqual(sBuf, "1") && g_iStopSound[param1] == 1)
				return ITEMDRAW_DISABLED;

			else if(StrEqual(sBuf, "2") && g_iStopSound[param1] == 2)
				return ITEMDRAW_DISABLED;

			else if(StrEqual(sBuf, "3"))
				return ITEMDRAW_DISABLED;

			return ITEMDRAW_DEFAULT;
		}
		
		case MenuAction_DisplayItem:
		{
			char dispBuf[64];
			char infoBuf[32];
			GetMenuItem(menu, param2, infoBuf, sizeof(infoBuf), _, dispBuf, sizeof(dispBuf));

			if(StrEqual(infoBuf, "4")) 
			{
				if(g_iSelfStopSound[param1] == 0) 
					Format(dispBuf, sizeof(dispBuf), "%t: %t", "Your Weapon Sound", "Normal");
					
				else if(g_iSelfStopSound[param1] == 1) 
					Format(dispBuf, sizeof(dispBuf), "%t: %t", "Your Weapon Sound", "Lowered");
					
				else if(g_iSelfStopSound[param1] == 2) 
					Format(dispBuf, sizeof(dispBuf), "%t: %t", "Your Weapon Sound", "Disabled");
					
				return RedrawMenuItem(dispBuf);
			}
		}
		
		case MenuAction_Select:
		{
			char info[50];
			if(GetMenuItem(menu, param2, info, sizeof(info)))
			{
				if(StringToInt(info) == 2) 
				{
					g_iStopSound[param1] = 2;
					g_bReplaceSilence[param1] = true;
					CReplyToCommand(param1, "%t %t: {lightgreen}%t{default}.", "prefix", "stop weapon sounds", "Replace to Silenced Sound");
				}
				else if (StringToInt(info) == 1) 
				{
					g_iStopSound[param1] = 1;
					g_bReplaceSilence[param1] = false;
					CReplyToCommand(param1, "%t %t: {lightgreen}%t{default}.", "prefix", "stop weapon sounds", "Stop Sound");
				}
				else if(StringToInt(info) == 0)
				{
					g_iStopSound[param1] = 0;
					g_bReplaceSilence[param1] = false;
					CReplyToCommand(param1, "%t %t: {lightgreen}%t{default}.", "prefix", "stop weapon sounds", "Disable");
				}
				else if(StringToInt(info) == 4)
				{
					if(g_iSelfStopSound[param1] == 0)
					{
						g_iSelfStopSound[param1]++;
						CReplyToCommand(param1, "%t %t: {lightgreen}%t{default}.", "prefix", "stop your own weapon sounds", "Lowered");
					}
					else if(g_iSelfStopSound[param1] == 1)
					{
						g_iSelfStopSound[param1]++;
						CReplyToCommand(param1, "%t %t: {lightgreen}%t{default}.", "prefix", "stop your own weapon sounds", "Disabled");
					}
					else if(g_iSelfStopSound[param1] == 2)
					{
						g_iSelfStopSound[param1] = 0;
						CReplyToCommand(param1, "%t %t: {lightgreen}%t{default}.", "prefix", "stop your own weapon sounds", "Normal");
					}
					SetClientSelfVolume(param1);
				}
				SaveClientCookies(param1);
				CheckHooks();
				PrepareMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if( param2 == MenuCancel_ExitBack )
			{
				ShowCookieMenu(param1);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
	return 0;
}

public void SaveClientCookies(int client)
{
	char sBuf[8];
	Format(sBuf, sizeof(sBuf), "%d", g_iStopSound[client]);
	SetClientCookie(client, g_hClientCookie, sBuf);

	Format(sBuf, sizeof(sBuf), "%d", g_iSelfStopSound[client]);
	SetClientCookie(client, g_hClientCookie_SelfSound, sBuf);
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));
	if (sValue[0] == '\0') 
	{
		SetClientCookie(client, g_hClientCookie, "2");
		strcopy(sValue, sizeof(sValue), "2");
	}
	g_iStopSound[client] = (StringToInt(sValue));
	g_bReplaceSilence[client] = StringToInt(sValue) > 1;
	
	char sValue2[8];
	GetClientCookie(client, g_hClientCookie_SelfSound, sValue2, sizeof(sValue2));
	if (sValue2[0] == '\0')
	{
		SetClientCookie(client, g_hClientCookie_SelfSound, "1");
		strcopy(sValue2, sizeof(sValue2), "1");
	}
	g_iSelfStopSound[client] = StringToInt(sValue2);
	
	SetClientSelfVolume(client);
	CheckHooks();
}

void SetClientSelfVolume(int client)
{
	if(IsFakeClient(client)) return;

	if(g_iSelfStopSound[client] == 0)
	{
		SendConVarValue(client, gCvar_WeaponScale, "1.0");
	}
	else if(g_iSelfStopSound[client] == 1)
	{
		SendConVarValue(client, gCvar_WeaponScale, "0.009");
	}
	else if(g_iSelfStopSound[client] == 2)
	{
		SendConVarValue(client, gCvar_WeaponScale, "0.0");
	}
}

public Action Command_StopSound(int client, int args)
{	
	if(AreClientCookiesCached(client))
		PrepareMenu(client);

	else
	{
		//ReplyToCommand(client, "[SM] Your Cookies are not yet cached. Please try again later...");
		CReplyToCommand(client, "%t %t", "prefix", "Loading_Cookies");
	}
	return Plugin_Handled;
}

public void OnClientDisconnect_Post(int client)
{
	g_iStopSound[client] = 0;
	g_bReplaceSilence[client] = false;
	g_iSelfStopSound[client] = 0;
	CheckHooks();
}

void CheckHooks()
{
	bool bShouldHook = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iStopSound[i] > 0)
		{
			bShouldHook = true;
			break;
		}
	}
      
	// Fake (un)hook because toggling actual hooks will cause server instability.
	g_bHooked = bShouldHook;
}

public Action Hook_NormalSound(int clients[64], int& numClients, char sample[PLATFORM_MAX_PATH], int& entity, int& channel, float& volume, int& level, int& pitch, int& flags)
{
	// Ignore non-weapon or Re-broadcasted sounds.
	if (!g_bHooked || StrEqual(sample, ReplaceSoundPath, false) || !(strncmp(sample, "weapons", 7, false) == 0 || strncmp(sample[1], "weapons", 7, false) == 0 || strncmp(sample[2], "weapons", 7, false) == 0))
		return Plugin_Continue;
      
	int i, j;
      
	for (i = 0; i < numClients; i++)
	{
		if (g_iStopSound[clients[i]] > 0)
		{
			// Remove the client from the array.
			for (j = i; j < numClients-1; j++)
			{
				clients[j] = clients[j+1];
			}
                      
			numClients--;
			i--;
		}
	}
	return (numClients > 0) ? Plugin_Changed : Plugin_Stop;
}

public Action CSS_Hook_ShotgunShot(const char[] te_name, const int[] Players, int numClients, float delay)
{
	if (!g_bHooked)
		return Plugin_Continue;
      
	// Check which clients need to be excluded.
	int newClients[MAXPLAYERS+1];
	int client; 
	int i;
	int newTotal = 0;

	int clientlist[MAXPLAYERS+1];
	int clientcount = 0;

	for (i = 0; i < numClients; i++)
	{
		client = Players[i];
              
		if (g_iStopSound[client] <= 0)
		{
			newClients[newTotal++] = client;
		}
		else if(ReplaceSoundPath[0])
		{
			if(g_bReplaceSilence[client])
			{
				clientlist[clientcount++] = client;
			}
		}
	}
      
	// No clients were excluded.
	if (newTotal == numClients)
		return Plugin_Continue;

	int player = TE_ReadNum("m_iPlayer");
	if(ReplaceSoundPath[0]) 
	{
		int entity = player + 1;
		for (int j = 0; j < clientcount; j++)
		{
			if (entity == clientlist[j])
			{
				for (int k = j; k < clientcount-1; k++)
				{
					clientlist[k] = clientlist[k+1];
				}
                              
				clientcount--;
				j--;
			}
		}
		EmitSound(clientlist, clientcount, ReplaceSoundPath, entity, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
	}
      
	// All clients were excluded and there is no need to broadcast.
	else if (newTotal == 0)
		return Plugin_Stop;
      
	// Re-broadcast to clients that still need it.
	float vTemp[3];
	TE_Start("Shotgun Shot");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", player);
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_Send(newClients, newTotal, delay);
      
	return Plugin_Stop;
}