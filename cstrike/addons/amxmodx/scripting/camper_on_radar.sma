#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#pragma semicolon 1
#pragma tabsize 4
#pragma compress 1

#define PLUGIN 			"Camper on radar"
#define VERSION 		"0.01"
#define AUTHOR 			"Aoi.Kagase"
#define TASK_CHECKER 	55443332

new Float:aOrigin[MAX_PLAYERS + 1][3];
new campcount[MAX_PLAYERS]; 
new g_msgHostagePos;
new g_msgBombDrop;
new g_msgHostageK;

enum CVARS
{
	ENABLE,
	COUNT,
}
new g_Cvars[CVARS];

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	bind_pcvar_num(create_cvar("amx_campradar", "1"), 		g_Cvars[ENABLE]); 	// 1 = on, 0 = off
	bind_pcvar_num(create_cvar("amx_campradar_count", "30"),g_Cvars[COUNT]);	// Camper検知の秒数

	register_event("DeathMsg", 	"Death_Radar_Out", 		"a"); 					// 死亡時レーダーから削除
	register_event("HLTV", 		"RoundStart", 			"a", "1=0", "2=0"); 	// ラウンド開始

	g_msgHostagePos = get_user_msgid("HostagePos");
	g_msgBombDrop 	= get_user_msgid("BombDrop");
	g_msgHostageK 	= get_user_msgid("HostageK");
}

// サーバーログイン時
public client_putinserver(id)
{ 
	// プラグインOFFの場合はスキップ
	if (!g_Cvars[ENABLE])
		return PLUGIN_CONTINUE;

	// 座標取得
	entity_get_vector(id, EV_VEC_origin, aOrigin[id]);

	// チェッカー起動
	new prm[3];
	num_to_str(id, prm, charsmax(prm));
	set_task(1.0, "checkCamp", id + TASK_CHECKER, prm, sizeof(prm), "b");

	return PLUGIN_CONTINUE;
}

// サーバー切断時
public client_disconnected(id)
{
	if (!g_Cvars[ENABLE])
		return PLUGIN_CONTINUE;

	// レーダー削除
	Radar_Out(id);

	// チェッカー停止
	if (task_exists(id + TASK_CHECKER))
		remove_task(id + TASK_CHECKER);

	return PLUGIN_CONTINUE;
}

public checkCamp(prm[])
{
	if (!g_Cvars[ENABLE])
		return PLUGIN_CONTINUE;

	new id = str_to_num(prm) - TASK_CHECKER;

	// 死んでいる場合はチェックしない
	if (!is_user_alive(id))
		return PLUGIN_CONTINUE;


	new Float:bOrigin[3];
	new axyz[3], bxyz[3];

	// 現在の座標取得
	entity_get_vector(id, EV_VEC_origin, bOrigin);
	
	// 前チェッカーで取得した座標をレーダー表示用に変換
	FVecIVec(aOrigin[id], axyz);
	// 現チェッカーで取得した座標をレーダー表示用に変換
	FVecIVec(bOrigin, bxyz);
	
	if(bxyz[0] == axyz[0] && bxyz[1] == axyz[1] && bxyz[2] == axyz[2])
	{ 
		// XYZ全て移動無しの場合はカウント
		campcount[id]++;
	}
	else
	{
		// 移動有りの場合はレーダーから削除しカウントを初期化
		Radar_Out(id);
		campcount[id] = 0;
	} 

	// カウントが閾値に達した場合
	if(g_Cvars[COUNT] <= campcount[id])
	{
		// 対象のチームを取得
		new CsTeams:Team = cs_get_user_team(id);

		// 敵プレイヤーへレーダー通知
		for (new i = 1; i <= get_playersnum(); i++) 
		{
			// 通知先が死亡済み、同一チーム、対象と同じプレイヤーの場合はスキップ
			new CsTeams:Team2 = cs_get_user_team(i);
			if (id == i || !is_user_alive(i) || Team == Team2) 
				continue;

			// レーダー通知
			switch(Team2)
			{
				// CT用レーダー通知
				case CS_TEAM_CT:
				{
					message_begin	(MSG_ONE, g_msgHostagePos, {0,0,0}, i);
					write_byte		(i);
					write_byte		(20);
					write_coord		(bxyz[0]);
					write_coord		(bxyz[1]);
					write_coord		(bxyz[2]);
					message_end		();
				} 
				// T用レーダー通知
				case CS_TEAM_T:
				{
					message_begin	(MSG_ONE, g_msgBombDrop, {0,0,0}, i);
					write_coord		(bxyz[0]);
					write_coord		(bxyz[1]);
					write_coord		(bxyz[2]);
					write_byte		(0);
					message_end		();
				} 
			}  
		} 
	} 

	//古い座標の更新
	xs_vec_copy(bOrigin, aOrigin[id]);

	return PLUGIN_CONTINUE;
}

public Death_Radar_Out()
{
	// 死人のIDを取得
	new victim = read_data(2);
	Radar_Out(victim);//レーダー削除

	return PLUGIN_CONTINUE;
}

public RoundStart()
{
	for (new i = 1; i <= get_playersnum(); i++) 
	{
		if (!is_user_alive(i)) 
			continue;

		message_begin(MSG_ONE, g_msgHostageK, {0,0,0}, i);
		write_byte(20);
		message_end();
	}
}

public Radar_Out(id)
{
	//レーダー削除  (メイン)
	new CsTeams:Team = cs_get_user_team(id);
	for (new i = 1; i <= get_playersnum(); i++) 
	{
		new CsTeams:Team2 = cs_get_user_team(i);
		if (id == i || !is_user_alive(i) || Team == Team2) 
			continue;

		message_begin(MSG_ONE, g_msgHostageK, {0,0,0}, i);
		write_byte(20);
		message_end();
	}
	campcount[id] = 0;
}