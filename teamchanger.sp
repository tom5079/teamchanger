//Author: D rank
//
//Project:  ██╗      █████╗ ███╗   ██╗███████╗███████╗███████╗
//          ██║     ██╔══██╗████╗  ██║██╔════╝██╔════╝██╔════╝
//          ██║     ███████║██╔██╗ ██║█████╗  ███████╗███████╗
//          ██║     ██╔══██║██║╚██╗██║██╔══╝  ╚════██║╚════██║
//          ███████╗██║  ██║██║ ╚████║███████╗███████║███████║
//          ╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝╚══════╝

#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdktools>

#define PREFIX "[\x05LANESS\x01]"
#define MAXBUFF 255
#define COMMAND "\"!팀교환\""

public Plugin myinfo = {
	name = "TeamChanger",
	description = "A plugin that allows player to change teams",
	author = "D rank",
	version = "1.0",
	url = "surf.quaver.xyz"
};

int g_requests[MAXPLAYERS];
int g_requested[MAXPLAYERS];

public Action ResetRequest(Handle timer, any client) {
	g_requested[client] = 0;
}

public void OnPluginStart() {
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	
	HookEvent("round_end", OnRoundEnd);
}

public int AcceptMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if(action == MenuAction_Select) {
		char buf[MAXBUFF];
		
		menu.GetItem(param2, buf, MAXBUFF);
		
		if(StrEqual(buf, "YES"))
			PrintToChat(g_requests[param1], "%s 팀변경이 수락되었습니다", PREFIX);
		else {
			PrintToChat(g_requests[param1], "%s 팀변경이 거절되었습니다", PREFIX);
			g_requests[param1] = 0;
		}
		
	} else if(action == MenuAction_Cancel) {
		PrintToChat(g_requests[param1], "%s 팀변경이 거절되었습니다", PREFIX);
		g_requests[param1] = 0;
	}
}

public int ChangeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if(action == MenuAction_Select) {
		char buf[MAXBUFF];
		
		menu.GetItem(param2, buf, MAXBUFF);
		
		int target = StringToInt(buf);
		
		if(g_requests[target] != 0) {
			PrintToChat(param1, "%s 이 플레이어는 현재 팀변경이 진행중입니다", PREFIX);
		} else if(g_requested[param1] != 0) {
			PrintToChat(param1, "%s 최근에 팀변경 요청을 하셨습니다. 잠시 후에 다시 시도해주세요.", PREFIX);
		} else {
			g_requests[target] = param1;
			g_requested[param1] = 1;
		
			BuildAcceptMenu(param1).Display(target, 60);
			CreateTimer(60.0, ResetRequest, param1);
			
			PrintToChat(param1, "%s 팀변경 요청을 보냈습니다", PREFIX);
		}
	}
}

Menu BuildChangeMenu(int team) {
	Menu menu = new Menu(ChangeMenuHandler);
	
	menu.SetTitle("교환할 플레이어를 선택하세요");
	
	for(int i = 1; i <= MaxClients; i++)
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == team) {
			char name[MAXBUFF], id[MAXBUFF], buf[MAXBUFF];
			
			GetClientName(i, name, MAXBUFF);
			IntToString(i, id, MAXBUFF);
			
			Format(buf, MAXBUFF, "%d번 %s %s", GetClientUserId(i), team==CS_TEAM_CT?"간수":"죄수", name);
			
			menu.AddItem(id, buf);
		}
	
	return menu;
}

Menu BuildAcceptMenu(int requester) {
	char buf[MAXBUFF], name[MAXBUFF];
	int team = GetClientTeam(requester);
	
	GetClientName(requester, name, MAXBUFF);
	
	Menu menu = new Menu(AcceptMenuHandler);
	
	Format(buf, MAXBUFF, "팀 변경 수락\n\n%d번 %s %s님이 팀변경을 요청했습니다 변경하시겠습니까?\n60초 뒤 자동으로 거절됩니다", GetClientUserId(requester), team==CS_TEAM_CT?"간수":"죄수", name);
	
	menu.SetTitle(buf);
	
	for(int i = 0; i < 7; i++)
		menu.AddItem("", "", ITEMDRAW_SPACER);
	
	menu.Pagination = MENU_NO_PAGINATION;
	
	menu.AddItem("YES", "네");
	menu.AddItem("NO", "아니오");
	
	return menu;
}

void Command_TeamChange(int client) {
	int team = GetClientTeam(client);
	
	//If player is neither T nor CT, ignore
	if(team != CS_TEAM_CT && team != CS_TEAM_T)
		return;
	
	//If opposite team has no player, block
	if(GetTeamClientCount(team==CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT) == 0) {
		PrintToChat(client, "%s 상대팀에 플레이어가 없습니다.", PREFIX);
		return;
	}
	
	BuildChangeMenu(team==CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT).Display(client, MENU_TIME_FOREVER);
}

public Action Command_Say(int client, const char[] command, int argc) {
	char buf[MAXBUFF];
	
	GetCmdArgString(buf, MAXBUFF);
	
	if(StrEqual(buf, COMMAND))
		Command_TeamChange(client);
	
	return Plugin_Continue;
}

public Action OnRoundEnd(Handle event, const char[] name, bool dontBroadcast) {
	for(int i = 1; i <= MaxClients; i++) {
		if(g_requests[i] != 0) {
			if(!IsClientInGame(i))
				PrintToChat(g_requests[i], "%s 팀변경 상대가 게임을 떠났습니다", PREFIX);
			else if(!IsClientInGame(g_requests[i]))
				PrintToChat(i, "%s 팀변경 상대가 게임을 떠났습니다", PREFIX);
			else {
				int target_team = GetClientTeam(i);
				int requester_team = GetClientTeam(g_requests[i]);
				
				if(target_team == requester_team) {
					PrintToChat(i, "%s 상대 플레이어와 팀이 같습니다", PREFIX);
				} else {
					ChangeClientTeam(i, requester_team);
					ChangeClientTeam(g_requests[i], target_team);
				}
			}
			
			g_requests[i] = 0;
		}
	}
}