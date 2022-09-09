#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <xs>

#define PLUGIN "Whip Sword"
#define VERSION "2.0"
#define AUTHOR "Jenessee"

#define WEAPONS_FILE "jenessee_weapons.ini"

new const Weapon_DefinitionID = 125321;
new const Resources[][] = 
{
	"models/v_whipsword.mdl", // 0	
	"models/v_whipsword_red.mdl", // 1	
	"models/p_whipsword.mdl", // 2

	"models/ef_whipsword_slash.mdl", // 3	
	"models/ef_whipsword_slash_loop.mdl", // 4	
	"models/ef_whipsword_slash_skill.mdl", // 5
	"models/ef_whipsword_stab.mdl", // 6
	"models/ef_whipsword_stab_loop.mdl", // 7
	"models/ef_whipsword_stab_skill.mdl", // 8

	"weapons/whipsword_slash_end.wav", //  9
	"weapons/whipsword_slash_loop_start.wav", // 10
	"weapons/whipsword_slash_loop1.wav", // 11
	"weapons/whipsword_slash_skill.wav", // 12
	"weapons/whipsword_slash1.wav", // 13
	"weapons/whipsword_slash1_end.wav", // 14
	"weapons/whipsword_stab_end.wav", // 15
	"weapons/whipsword_stab_loop_all.wav", // 16
	"weapons/whipsword_stab_loop_end.wav", // 17
	"weapons/whipsword_stab_skill_flying.wav", // 18
	"weapons/whipsword_stab_skill_start.wav", // 19
	"weapons/whipsword_stab12_end.wav", // 20
	"weapons/dualsword_stab1_hit.wav", // 21
	"weapons/katana_hitwall.wav", // 22

	"sound/weapons/whipsword_stab_skill_end.wav", // 23
	"sound/weapons/whipsword_draw.wav", // 24

	"sprites/knife_whipsword.spr", // 25
	"sprites/knife_whipsword.txt" // 26
};

enum
{
	HIT_NONE,
	HIT_ENEMY,
	HIT_WALL
};

enum
{
	PLAYER_TEAM_UNASSIGNED,
	PLAYER_TEAM_ZOMBIE,
	PLAYER_TEAM_HUMAN
};

const EntVars:var_slashcount = var_iuser1;
const EntVars:var_stabcount = var_iuser2;

enum _:Values
{
	Float:DAMAGE_A, // 0
	Float:DAMAGE_A2, // 1
	Float:DAMAGE_B, // 2
	Float:DAMAGE_B2,  // 3
	Float:DAMAGE_C,  // 4
	Float:RANGE_A,  // 5
	Float:RANGE_A2,  // 6
	Float:RANGE_B,  // 7
	Float:RANGE_B2,  // 8
	Float:RANGE_C,  // 9
	Float:KNOCKBACK_C,  // 10
	Float:KNOCKUP_C,// 11
	Float:HOOK_SPEED // 12
};

new fValues[Values];
new Message_WeaponListID;
new Weapon_EntityID[MAX_PLAYERS+1], iBloodPrecacheID[2], iTotalPlayerUseWeapon, iTotalAlivePlayers, playerTeam[MAX_PLAYERS+1], handleNewRound;
new Array:Array_AlivePlayers;
new HookChain:HC_DefaultDeploy, HookChain:HC_AddPlayerItem;
new HamHook:HAM_Item_PostFrame;
new FW_EmitSound, FW_UpdateClientData, FW_OnFreeEntPrivateData;
new bool:isZombiePlague, bool:isRoundStarted;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("knife_whipsword", "Hook_Knife");
	
	register_clcmd("give_whip", "Give_Knife");

	disable_event(handleNewRound = register_event("HLTV", "OnNewRound", "a", "1=0", "2=0"));

	DisableHookChain(HC_AddPlayerItem = RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "CBasePlayer_AddPlayerItem", false));
	DisableHookChain(HC_DefaultDeploy = RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy", false));
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed");

	DisableHamForward(HAM_Item_PostFrame = RegisterHam(Ham_Item_PostFrame, "weapon_knife", "Item_PostFrame", false));
	
	Message_WeaponListID = get_user_msgid("WeaponList");

	Array_AlivePlayers = ArrayCreate(1);
}

public plugin_precache()
{
	fValues[DAMAGE_A] = 10.0;
	fValues[DAMAGE_A2] = 20.0;
	fValues[DAMAGE_B] = 15.0;
	fValues[DAMAGE_B2] = 5.0;
	fValues[DAMAGE_C] = 30.0;
	fValues[RANGE_A] = 150.0;
	fValues[RANGE_A2] = 175.0;
	fValues[RANGE_B] = 160.0;
	fValues[RANGE_B2] = 200.0;
	fValues[RANGE_C] = 300.0;
	fValues[KNOCKBACK_C] = 1300.0;
	fValues[KNOCKUP_C] = 250.0;
	fValues[HOOK_SPEED] = 1000.0;

	Load_Weapon_Configs();

	for(new index = 0; index < sizeof(Resources); index++)
	{
		switch(index)
		{
			case 0..8: precache_model(Resources[index]); 
			case 9..22: precache_sound(Resources[index]); 
			default: precache_generic(Resources[index]); 
		}		
	}
	
	iBloodPrecacheID[0] = precache_model("sprites/bloodspray.spr");
	iBloodPrecacheID[1] = precache_model("sprites/blood.spr");
}

public plugin_natives()
{
	register_native("Get_Whipsword", "Native_Get_WhipSword");
}

public Native_Get_WhipSword(iPlugin, iParams)
{
	new clientIndex = get_param(1);
	if(clientIndex > 0 && clientIndex <= MAX_PLAYERS && playerTeam[clientIndex] != PLAYER_TEAM_ZOMBIE)
	{
		EnableHookChain(HC_AddPlayerItem);
		rg_give_custom_item(clientIndex, "weapon_knife", GT_REPLACE, Weapon_DefinitionID);
		DisableHookChain(HC_AddPlayerItem);
		engclient_cmd(clientIndex, "weapon_knife");
	}	
}

public plugin_end()
{
	ArrayDestroy(Array_AlivePlayers);
}

native Get_Whipsword(clientIndex);
public Give_Knife(const clientIndex)
{
	Get_Whipsword(clientIndex);
	return PLUGIN_HANDLED;
}

public Hook_Knife(const clientIndex)
{
	engclient_cmd(clientIndex, "weapon_knife");
	return PLUGIN_HANDLED;
}

public OnNewRound()
{
	isRoundStarted = false;
}

public zp_user_humanized_pre(const clientIndex)
{
	if(!isZombiePlague) 
	{
		enable_event(handleNewRound);
		isZombiePlague = true;
	}

	playerTeam[clientIndex] = PLAYER_TEAM_HUMAN; 
}

public zp_user_infected_pre(const clientIndex)
{
	if(!isZombiePlague) 
	{
		enable_event(handleNewRound);
		isZombiePlague = true;
	}

	playerTeam[clientIndex] = PLAYER_TEAM_ZOMBIE; 
}

public zp_round_started(gamemode, id)
{
	isRoundStarted = true;
}

public client_disconnected(clientIndex)
{
	new iArrayID;
	if((iArrayID = ArrayFindValue(Array_AlivePlayers, clientIndex)) != -1)
	{
		ArrayDeleteItem(Array_AlivePlayers, iArrayID);
		iTotalAlivePlayers--;
	}	

	playerTeam[clientIndex] = PLAYER_TEAM_UNASSIGNED;
}

public EmitSound(const clientIndex, const iChannel, const szSound[])
{
	if(szSound[14] == 'd' && szSound[15] == 'e' && szSound[16] == 'p') 
		return FMRES_SUPERCEDE;
	
	return FMRES_IGNORED;
}

public UpdateClientData(const clientIndex, sendweapons, cd_handle)
{
    if (Weapon_EntityID[clientIndex] <= 0)
       	return FMRES_IGNORED;

    set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001);     
    return FMRES_HANDLED;
}

public OnEntityRemoved(const entityIndex)
{
	if(get_entvar(entityIndex, var_impulse) == Weapon_DefinitionID)
	{
		new clientIndex = get_member(entityIndex, m_pPlayer);

		message_begin(MSG_ONE_UNRELIABLE, Message_WeaponListID, _, clientIndex); 
		write_string("weapon_knife");
		write_byte(-1);
		write_byte(-1);
		write_byte(-1);
		write_byte(-1);
		write_byte(2);
		write_byte(1);
		write_byte(CSW_KNIFE);
		write_byte(0);
		message_end();

		if(--iTotalPlayerUseWeapon <= 0)
		{
			DisableHookChain(HC_DefaultDeploy);
			DisableHamForward(HAM_Item_PostFrame);

			unregister_forward(FM_EmitSound, FW_EmitSound, false);
			unregister_forward(FM_UpdateClientData, FW_UpdateClientData, true);
			unregister_forward(FM_OnFreeEntPrivateData, FW_OnFreeEntPrivateData, false);
		}

		remove_task(entityIndex+Weapon_DefinitionID);
		if(entityIndex == Weapon_EntityID[clientIndex])
		{
			if(get_entvar(entityIndex, var_stabcount) >= 5) emit_sound(clientIndex, CHAN_WEAPON, "common/null.wav", 0.6, 0.4, 0, 94 + random_num(0, 55));
			Weapon_EntityID[clientIndex] = NULLENT;
		}
	}
}

public CBasePlayer_AddPlayerItem(const clientIndex, const iWeaponEntityID)
{
	message_begin(MSG_ONE_UNRELIABLE, Message_WeaponListID, _, clientIndex); 
	write_string("knife_whipsword");
	write_byte(-1);
	write_byte(-1);
	write_byte(-1);
	write_byte(-1);
	write_byte(2);
	write_byte(1);
	write_byte(CSW_KNIFE);
	write_byte(0);
	message_end();

	if(++iTotalPlayerUseWeapon == 1)
	{
		EnableHookChain(HC_DefaultDeploy);
		EnableHamForward(HAM_Item_PostFrame);

		FW_EmitSound = register_forward(FM_EmitSound, "EmitSound", false);
		FW_UpdateClientData = register_forward(FM_UpdateClientData, "UpdateClientData", true);
		FW_OnFreeEntPrivateData = register_forward(FM_OnFreeEntPrivateData, "OnEntityRemoved", false);
	}

	return HC_CONTINUE;
}

public CBasePlayerWeapon_DefaultDeploy(const iWeaponEntityID, const szViewModel[], const szWeaponModel[], const iAnim, const szAnimExt[], const skiplocal) 
{
	new clientIndex = get_member(iWeaponEntityID, m_pPlayer); 
   	if(get_entvar(iWeaponEntityID, var_impulse) == Weapon_DefinitionID)
	{
		SetHookChainArg(2, ATYPE_STRING, Resources[0]); 
		SetHookChainArg(3, ATYPE_STRING, Resources[2]); 
		SetHookChainArg(4, ATYPE_INTEGER, 14); 
		SetHookChainArg(5, ATYPE_STRING, "knife"); 

		set_task(1.0, "Task_Idle", iWeaponEntityID+Weapon_DefinitionID);
		
		Weapon_EntityID[clientIndex] = iWeaponEntityID; 

		if(get_entvar(iWeaponEntityID, var_slashcount)) set_entvar(iWeaponEntityID, var_slashcount, 0);
		if(get_entvar(iWeaponEntityID, var_stabcount)) set_entvar(iWeaponEntityID, var_stabcount, 0);

		RequestFrame("Refresh_ViewModel", clientIndex);
	} else if(Weapon_EntityID[clientIndex] > 0) {
		if(get_entvar(Weapon_EntityID[clientIndex], var_stabcount) >= 5) emit_sound(clientIndex, CHAN_WEAPON, "common/null.wav", 0.6, 0.4, 0, 94 + random_num(0, 55));
		remove_task(Weapon_EntityID[clientIndex]+Weapon_DefinitionID);
		SetThink(Weapon_EntityID[clientIndex], "");
		Weapon_EntityID[clientIndex] = NULLENT;
	} 
}

public Refresh_ViewModel(const clientIndex)
{
	new weaponEntity = Weapon_EntityID[clientIndex]
	if(weaponEntity > 0)
	{
		set_entvar(clientIndex, var_viewmodel, Resources[0]);
		set_entvar(clientIndex, var_weaponmodel, Resources[2]);

		Weapon_Animation(clientIndex, 14);

		SetThink(weaponEntity, "Think_Buttons");
		set_entvar(weaponEntity, var_nextthink, get_gametime() + 1.0); 
	}
}

public CBasePlayer_Spawn(const clientIndex)
{
	if(!is_user_alive(clientIndex))
		return;

	if(ArrayFindValue(Array_AlivePlayers, clientIndex) == -1)
	{
		ArrayPushCell(Array_AlivePlayers, clientIndex);
		iTotalAlivePlayers++;
	}
}

public CBasePlayer_Killed(const clientIndex)
{
	new iArrayID;
	if((iArrayID = ArrayFindValue(Array_AlivePlayers, clientIndex)) != -1)
	{
		ArrayDeleteItem(Array_AlivePlayers, iArrayID);
		iTotalAlivePlayers--;
	}
}

public Item_PostFrame(const entityIndex)
{	
	if(Weapon_EntityID[get_member(entityIndex, m_pPlayer)] > 0) 
		return HAM_SUPERCEDE;

	return HAM_IGNORED;
}

public Think_Buttons(const iWeaponEntityID)
{
	static clientIndex; clientIndex = get_member(iWeaponEntityID, m_pPlayer); 
	static Button; Button = get_entvar(clientIndex, var_button); 
	static Float:Time; Time = get_gametime(); 
	static iTotalSlash, iTotalStab;

	if(Button & IN_ATTACK2)
	{
		remove_task(iWeaponEntityID+Weapon_DefinitionID);

		if((iTotalSlash = get_entvar(iWeaponEntityID, var_slashcount)) > 0) 
		{
			if(iTotalSlash >= 5)
			{
				Weapon_Animation(clientIndex, 5);
				emit_sound(clientIndex, CHAN_WEAPON, Resources[12], 0.6, 0.4, 0, 94 + random_num(0, 55));
				set_task(1.0, "Task_Idle", iWeaponEntityID+Weapon_DefinitionID);
				set_entvar(iWeaponEntityID, var_nextthink, Time + 1.15); 

				set_entvar(iWeaponEntityID, var_slashcount, 4);

				Do_Damage(clientIndex, fValues[RANGE_C], fValues[DAMAGE_C], 180.0, fValues[KNOCKBACK_C], fValues[KNOCKUP_C], 1.0);

				Create_Effect(clientIndex, Resources[5], 0);
				Player_Animation(clientIndex, "ref_shoot_knife", 1.0);
				return;
			} else if(iTotalSlash >= 4) set_entvar(clientIndex, var_viewmodel, Resources[0]);

			set_entvar(iWeaponEntityID, var_slashcount, 0);
		}

		iTotalStab = get_entvar(iWeaponEntityID, var_stabcount);
		if(iTotalStab >= 4)
		{
			if(iTotalStab == 4)
			{
				Weapon_Animation(clientIndex, 9);

				set_entvar(clientIndex, var_viewmodel, Resources[1]);
				set_entvar(iWeaponEntityID, var_stabcount, ++iTotalStab);
				set_entvar(iWeaponEntityID, var_fuser1, 0.0);

				new effectIndex = Create_Effect(clientIndex, Resources[7], 8192);
				if(effectIndex != NULLENT)
				{
					set_entvar(effectIndex, var_iuser1, iWeaponEntityID);
					SetThink(effectIndex, "Think_Effect_StabCharge");
					set_entvar(effectIndex, var_nextthink, get_gametime());
				}
			}

			set_entvar(iWeaponEntityID, var_nextthink, Time + 0.2); 

			new Float:fLoopStabSound; get_entvar(iWeaponEntityID, var_fuser1, fLoopStabSound);
			if(fLoopStabSound <= Time)
			{
				emit_sound(clientIndex, CHAN_WEAPON, Resources[16], 0.6, 0.4, 0, 94 + random_num(0, 55));
				set_entvar(iWeaponEntityID, var_fuser1, Time + 5.0);
			}

			new Hit = Do_Damage(clientIndex, fValues[RANGE_B2], fValues[DAMAGE_B2], 90.0, 0.0, 0.0, 0.0);
			if(Hit == HIT_ENEMY) emit_sound(clientIndex, CHAN_ITEM, Resources[21], 1.0, 0.4, 0, 94 + random_num(0, 35));

			set_task(0.25, "Task_StabLoop_End", iWeaponEntityID+Weapon_DefinitionID);
		} else {
			static StabAnim[MAX_PLAYERS+1];
			Weapon_Animation(clientIndex, 6+ StabAnim[clientIndex]);
			StabAnim[clientIndex] = !StabAnim[clientIndex];

			emit_sound(clientIndex, CHAN_WEAPON, Resources[13], 1.0, 0.4, 0, 94 + random_num(0, 65));

			set_entvar(iWeaponEntityID, var_stabcount, ++iTotalStab);
			set_entvar(iWeaponEntityID, var_nextthink, Time + 0.75); 

			Create_Effect(clientIndex, Resources[6], 8192);

			set_task(0.8, "Task_Stab_End", iWeaponEntityID+Weapon_DefinitionID);

			new Hit = Do_Damage(clientIndex, fValues[RANGE_B], fValues[DAMAGE_B], 45.0, 0.0, 0.0, 0.0);
			switch(Hit)
			{
				case HIT_ENEMY: emit_sound(clientIndex, CHAN_ITEM, Resources[21], 1.0, 0.4, 0, 94 + random_num(0, 35));	
				case HIT_WALL: emit_sound(clientIndex, CHAN_ITEM, Resources[22], 1.0, 0.4, 0, 94 + random_num(0, 35));	
			}
		}
		Player_Animation(clientIndex, "ref_shoot_knife", 1.0);
		return;
	} 

	if(Button & IN_ATTACK)
	{
		remove_task(iWeaponEntityID+Weapon_DefinitionID);
		if((iTotalStab = get_entvar(iWeaponEntityID, var_stabcount)) > 0) 
		{	
			if(iTotalStab >= 5 && fValues[HOOK_SPEED] > 0.0)
			{
				Weapon_Animation(clientIndex, 11);
				emit_sound(clientIndex, CHAN_WEAPON, Resources[19], 0.6, 0.4, 0, 94 + random_num(0, 55));
				set_task(1.0, "Task_Fly_End", iWeaponEntityID+Weapon_DefinitionID);
				set_entvar(iWeaponEntityID, var_stabcount, 4);

				new Float:vMyVelocity[3], Float:vVelocity[3]; 
				get_entvar(clientIndex, var_velocity, vMyVelocity);
				velocity_by_aim(clientIndex, floatround(fValues[HOOK_SPEED]), vVelocity);
				xs_vec_add(vMyVelocity, vVelocity, vVelocity);
				vVelocity[2] += 250.0;
				set_entvar(clientIndex, var_velocity, vVelocity);

				Create_Effect(clientIndex, Resources[8], 0);
				Player_Animation(clientIndex, "ref_shoot_knife", 1.0);
				return;
			} else if(iTotalStab >= 4) set_entvar(clientIndex, var_viewmodel, Resources[0]);

			set_entvar(iWeaponEntityID, var_stabcount, 0);
		}

		iTotalSlash = get_entvar(iWeaponEntityID, var_slashcount);
		if(iTotalSlash >= 4)
		{
			if(iTotalSlash == 4)
			{
				Weapon_Animation(clientIndex, 3);
				set_entvar(clientIndex, var_viewmodel, Resources[1]);
				set_entvar(iWeaponEntityID, var_slashcount, ++iTotalSlash);

				new effectIndex = Create_Effect(clientIndex, Resources[4], 8192);
				if(effectIndex != NULLENT)
				{
					set_entvar(effectIndex, var_iuser1, iWeaponEntityID);
					SetThink(effectIndex, "Think_Effect_SlashCharge");
					set_entvar(effectIndex, var_nextthink, get_gametime());
				}
			}
			emit_sound(clientIndex, CHAN_WEAPON, Resources[10], 1.0, 0.4, 0, 94 + random_num(0, 55));
			emit_sound(clientIndex, CHAN_STATIC, Resources[11], 0.6, 0.4, 0, 94 + random_num(0, 55));

			set_entvar(iWeaponEntityID, var_nextthink, Time + 0.65); 

			set_task(0.7, "Task_SlashLoop_End", iWeaponEntityID+Weapon_DefinitionID);

		 	Do_Damage(clientIndex, fValues[RANGE_A2], fValues[DAMAGE_A2], 180.0, 0.0, 0.0, 0.0);
		} else {
			Weapon_Animation(clientIndex, 1);

			emit_sound(clientIndex, CHAN_WEAPON, Resources[13], 1.0, 0.4, 0, 94 + random_num(0, 55));

			set_entvar(iWeaponEntityID, var_slashcount, ++iTotalSlash);
			set_entvar(iWeaponEntityID, var_nextthink, Time + 0.75); 

			set_task(0.8, "Task_Slash_End", iWeaponEntityID+Weapon_DefinitionID);

			Create_Effect(clientIndex, Resources[3], 8192);

			new Hit = Do_Damage(clientIndex, fValues[RANGE_A], fValues[DAMAGE_A], 90.0, 0.0, 0.0, 0.0);
			switch(Hit)
			{
				case HIT_ENEMY:	emit_sound(clientIndex, CHAN_ITEM, Resources[21], 1.0, 0.4, 0, 94 + random_num(0, 35));	
				case HIT_WALL:	emit_sound(clientIndex, CHAN_ITEM, Resources[22], 1.0, 0.4, 0, 94 + random_num(0, 35));	
			}
		}

		Player_Animation(clientIndex, "ref_shoot_knife", 1.0);
		return;
	} 

	set_entvar(iWeaponEntityID, var_nextthink, Time); 
}

public Task_Slash_End(iWeaponEntityID)
{
	set_task(0.8, "Task_Idle", iWeaponEntityID);

	iWeaponEntityID -= Weapon_DefinitionID;

	new clientIndex = get_entvar(iWeaponEntityID, var_owner);

	emit_sound(clientIndex, CHAN_WEAPON, Resources[14], 1.0, 0.4, 0, 94 + random_num(0, 55));
	Weapon_Animation(clientIndex, 2);
}

public Task_SlashLoop_End(iWeaponEntityID)
{
	set_task(1.0, "Task_Idle", iWeaponEntityID);

	iWeaponEntityID -= Weapon_DefinitionID;

	new clientIndex = get_entvar(iWeaponEntityID, var_owner);

	set_entvar(iWeaponEntityID, var_slashcount, 4);

	emit_sound(clientIndex, CHAN_WEAPON, Resources[15], 1.0, 0.4, 0, 94 + random_num(0, 55));
	Weapon_Animation(clientIndex, 4);
}

public Task_Stab_End(iWeaponEntityID)
{
	set_task(0.7, "Task_Idle", iWeaponEntityID);

	iWeaponEntityID -= Weapon_DefinitionID;

	new clientIndex = get_entvar(iWeaponEntityID, var_owner);

	emit_sound(clientIndex, CHAN_WEAPON, Resources[20], 1.0, 0.4, 0, 94 + random_num(0, 55));
	Weapon_Animation(clientIndex, 8);
}

public Task_StabLoop_End(iWeaponEntityID)
{
	set_task(1.0, "Task_Idle", iWeaponEntityID);

	iWeaponEntityID -= Weapon_DefinitionID;
	new clientIndex = get_entvar(iWeaponEntityID, var_owner);

	set_entvar(iWeaponEntityID, var_stabcount, 4);

	emit_sound(clientIndex, CHAN_WEAPON, Resources[15], 1.0, 0.4, 0, 94 + random_num(0, 55));
	Weapon_Animation(clientIndex, 10);
}

public Task_Fly_End(iWeaponEntityID)
{
	set_task(0.7, "Task_Idle", iWeaponEntityID);

	iWeaponEntityID -= Weapon_DefinitionID;

	Weapon_Animation(get_member(iWeaponEntityID, m_pPlayer), 13);

	set_entvar(iWeaponEntityID, var_nextthink, get_gametime() + 0.85); 
}

public Task_Idle(iWeaponEntityID)
{
	iWeaponEntityID -= Weapon_DefinitionID;

	new clientIndex = get_entvar(iWeaponEntityID, var_owner);
	new iValue;
	if((iValue = get_entvar(iWeaponEntityID, var_slashcount)) > 0) 
	{
		if(iValue >= 4) set_entvar(clientIndex, var_viewmodel, Resources[0]);
		set_entvar(iWeaponEntityID, var_slashcount, 0);
	}

	if((iValue = get_entvar(iWeaponEntityID, var_stabcount)) > 0) 
	{
		if(iValue >= 4) set_entvar(clientIndex, var_viewmodel, Resources[0]);
		set_entvar(iWeaponEntityID, var_stabcount, 0);
	}

	Weapon_Animation(clientIndex, 0);
}

Weapon_Animation(const clientIndex, const iSequence) 
{
	set_entvar(clientIndex, var_weaponanim, iSequence);

	message_begin(MSG_ONE, SVC_WEAPONANIM, _, clientIndex);
	write_byte(iSequence);
	write_byte(0);
	message_end();	
}

Entity_Animation(const entityIndex, const iSequence, const Float:fFramerate)
{
	set_entvar(entityIndex, var_animtime, get_gametime());
	set_entvar(entityIndex, var_frame, 0.0);
	set_entvar(entityIndex, var_framerate, fFramerate);
	set_entvar(entityIndex, var_sequence, iSequence);
}        

Player_Animation(const clientIndex, const szAnimation[], const Float:fFramerate)
{
	new iSequence, Float:Framerate, Float:Groundspeed, bool:Loops, Float:gameTime = get_gametime();
	if ((iSequence = lookup_sequence(clientIndex, szAnimation, Framerate, Loops, Groundspeed)) == -1) iSequence = 0;

	set_entvar(clientIndex, var_sequence, iSequence);
	set_entvar(clientIndex, var_frame, 0.0);
	set_entvar(clientIndex, var_animtime, gameTime);
	set_entvar(clientIndex, var_framerate, fFramerate);

	set_pdata_int(clientIndex, 40, Loops, 4);
	set_pdata_int(clientIndex, 39, 0, 4);

	set_pdata_float(clientIndex, 36, Framerate, 4);
	set_pdata_float(clientIndex, 37, Groundspeed, 4);
	set_pdata_float(clientIndex, 38, gameTime, 4);

	set_pdata_int(clientIndex, 73, 28, 5);
	set_pdata_int(clientIndex, 74, 28, 5);
	set_pdata_float(clientIndex, 220, gameTime, 5);
}

Create_Effect(const clientIndex, const szModel[], const iEffect)
{
	new entityIndex = rg_create_entity("info_target");
	if (!is_nullent(entityIndex))
	{
		engfunc(EngFunc_SetModel, entityIndex, szModel); 

		set_entvar(entityIndex, var_movetype, MOVETYPE_FLY);

		set_entvar(entityIndex, var_rendermode, kRenderTransAdd);
		set_entvar(entityIndex, var_renderamt, 255.0);
		if(iEffect) 
		{
			if(get_viewent(clientIndex) == clientIndex || iEffect != 8192) set_entvar(entityIndex, var_effects, iEffect);
		}
		set_entvar(entityIndex, var_owner, clientIndex);

		Entity_Animation(entityIndex, 0, 1.0);

		SetThink(entityIndex, "Think_Fadeout");
		set_entvar(entityIndex, var_nextthink, get_gametime() + 0.5);
		RequestFrame("Frame_ParentOwner", entityIndex);

		return entityIndex;
	}	
	return NULLENT;
}

public Frame_ParentOwner(const entityIndex)
{
	if(is_nullent(entityIndex))
		return;

	static parentIndex; parentIndex = get_entvar(entityIndex, var_owner);
	if(Weapon_EntityID[parentIndex] <= 0)
		return

	static Float:vParentPosition[3], Float:vParentAngles[3];
	get_entvar(parentIndex, var_angles, vParentAngles);
	Get_Position(parentIndex, 0.0, 0.0, 0.0, vParentPosition, vParentAngles, true, Float:{0.0, 0.0, 0.0}, false);

	set_entvar(entityIndex, var_velocity, {0.1, 0.1, 0.1});
	set_entvar(entityIndex, var_angles, vParentAngles);
	set_entvar(entityIndex, var_origin, vParentPosition);
	RequestFrame("Frame_ParentOwner", entityIndex);
}

public Think_Fadeout(const entityIndex)
{
	static Float:Renderamt; Renderamt = get_entvar(entityIndex, var_renderamt);

	if((Renderamt -= 6.0) <= 0.0) 
	{
		set_entvar(entityIndex, var_flags, FL_KILLME);
		return;
	}

	set_entvar(entityIndex, var_renderamt, Renderamt);
	set_entvar(entityIndex, var_nextthink, get_gametime());
}

public Think_Effect_SlashCharge(const entityIndex)
{
	static iWeaponEntityID, clientIndex, Float:Time; Time = get_gametime(); 
	iWeaponEntityID = get_entvar(entityIndex, var_iuser1);
	clientIndex = get_entvar(entityIndex, var_owner);

	if(Weapon_EntityID[clientIndex] != iWeaponEntityID || get_entvar(iWeaponEntityID, var_slashcount) < 5) 
	{
		SetThink(entityIndex, "Think_Fadeout");
	}

	set_entvar(entityIndex, var_nextthink, Time);
}

public Think_Effect_StabCharge(const entityIndex)
{
	static iWeaponEntityID, clientIndex, Float:Time; Time = get_gametime(); 
	iWeaponEntityID = get_entvar(entityIndex, var_iuser1);
	clientIndex = get_entvar(entityIndex, var_owner);

	if(Weapon_EntityID[clientIndex] != iWeaponEntityID || get_entvar(iWeaponEntityID, var_stabcount) < 5) 
	{
		SetThink(entityIndex, "Think_Fadeout");
	}

	set_entvar(entityIndex, var_nextthink, Time);
}

Do_Damage(const clientIndex, const Float:Damage_Range, const Float:Damage, const Float:Point_Dis, const Float:Knockback, const Float:KnockUp, const Float:Painshock)
{
	new Hit_Type, KnifeEntityID = Weapon_EntityID[clientIndex], Float:vOwnerPosition[3], Float:vVictimPosition[3], Float:vTargetPosition[3]; 
	Get_Position(clientIndex, 0.0, 0.0, 0.0, vOwnerPosition, Float:{0.0, 0.0, 0.0}, false, Float:{0.0, 0.0, 0.0}, false);

	for(new iArrayID = iTotalAlivePlayers-1, victimIndex; iArrayID >= 0; iArrayID--)
	{
		victimIndex = ArrayGetCell(Array_AlivePlayers, iArrayID);
		if(victimIndex == clientIndex)	
			continue;
		if(isZombiePlague)
		{
			if(!isRoundStarted) break;
			if(playerTeam[clientIndex] == playerTeam[victimIndex])
				continue;
		}
		if(!rg_is_player_can_takedamage(victimIndex, clientIndex))
			continue;
		Get_Position(victimIndex, 0.0, 0.0, 0.0, vVictimPosition, Float:{0.0, 0.0, 0.0}, false, Float:{0.0, 0.0, 0.0}, false);
		if(get_distance_f(vOwnerPosition, vVictimPosition) > Damage_Range)
			continue;
		if(!Compare_Target_And_Entity_Angle(clientIndex, victimIndex, Point_Dis))
			continue;
		if(!Can_See(clientIndex, victimIndex))
			continue;

		if(!Hit_Type) Hit_Type = HIT_ENEMY; 

		if(Damage > 0.0) FakeTraceAttack(clientIndex, victimIndex, KnifeEntityID, Damage, DMG_BULLET);
		if(Painshock > 0.0) set_pdata_float(victimIndex, 108, Painshock, 5);
		if(Knockback > 0.0 || KnockUp > 0.0) Hook_Entity(victimIndex, vOwnerPosition, Knockback, KnockUp, true);	
	}

	Get_Position(clientIndex, Damage_Range, 0.0, 0.0, vTargetPosition, Float:{0.0, 0.0, 0.0}, false, vOwnerPosition, true);
	engfunc(EngFunc_TraceLine, vOwnerPosition, vTargetPosition, DONT_IGNORE_MONSTERS, clientIndex, 0);
	new Enemy = get_tr2(0, TR_pHit); 
	if(!is_nullent(Enemy) && get_entvar(Enemy, var_takedamage) == DAMAGE_YES)
	{
		if(!Hit_Type) Hit_Type = HIT_ENEMY; 
		ExecuteHamB(Ham_TakeDamage, Enemy, KnifeEntityID, clientIndex, Damage, DMG_SLASH);
	} else if(!Hit_Type) {
		new Float:End_Origin[3]; get_tr2(0, TR_vecEndPos, End_Origin);
		if(floatround(get_distance_f(vTargetPosition, End_Origin)) && !is_user_alive(Enemy)) Hit_Type = HIT_WALL; 
	}

	return Hit_Type;
}

FakeTraceAttack(const iAttacker, const iVictim, const iInflictor, Float:fDamage, const iDamageType)
{
	new iTarget, iHitGroup = HIT_GENERIC; 
	new Float:vAttackerAngle[3]; get_entvar(iAttacker, var_v_angle, vAttackerAngle);
	new Float:vAttackerOrigin[3]; Get_Position(iAttacker, 0.0, 0.0, 0.0, vAttackerOrigin, vAttackerAngle, true, Float:{0.0, 0.0, 0.0}, false);
	new Float:vTargetOrigin[3]; Get_Position(iAttacker, 8192.0, 0.0, 0.0, vTargetOrigin, vAttackerAngle, true, vAttackerOrigin, true);

	engfunc(EngFunc_TraceLine, vAttackerOrigin, vTargetOrigin, DONT_IGNORE_MONSTERS, iAttacker, 0); 

	iTarget = get_tr2(0, TR_pHit);
	iHitGroup = get_tr2(0, TR_iHitgroup);
	get_tr2(0, TR_vecEndPos, vTargetOrigin);

	if(iTarget != iVictim) 
	{
		iTarget = iVictim;
		iHitGroup = HIT_STOMACH;
		get_entvar(iVictim, var_origin, vTargetOrigin);
	}

	fDamage *= Damage_Multiplier(iHitGroup);
	if(!Compare_Target_And_Entity_Angle(iTarget, iAttacker, 90.0)) fDamage *= 3.0;
	set_member(iTarget, m_LastHitGroup, iHitGroup);
	Spawn_Blood(vTargetOrigin, iHitGroup, 7);
	ExecuteHamB(Ham_TakeDamage, iTarget, iInflictor, iAttacker, fDamage, iDamageType);
}

Float:Damage_Multiplier(const iBody)
{
	new Float:X;
	switch (iBody)
	{
		case 1: X = 4.0;
		case 2: X = 2.0;
		case 3: X = 1.25;
		default: X = 1.0;
	}
	return X;
}

Spawn_Blood(const Float:Origin[3], const iBody, const iScale)
{
	new Blood_Scale;
	switch (iBody)
	{
		case HIT_HEAD: Blood_Scale = iScale+8; 
		case HIT_CHEST, HIT_STOMACH: Blood_Scale = iScale+3;
		default: Blood_Scale = iScale;
	}

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, Origin);
	write_byte(TE_BLOODSPRITE);
	engfunc(EngFunc_WriteCoord, Origin[0]);
	engfunc(EngFunc_WriteCoord, Origin[1]);
	engfunc(EngFunc_WriteCoord, Origin[2]);
	write_short(iBloodPrecacheID[0]);
	write_short(iBloodPrecacheID[1]);
	write_byte(247);
	write_byte(Blood_Scale);
	message_end();
}    

Hook_Entity(const Entity, const Float:TargetOrigin[3], Float:Knockback, Float:KnockUp, bool:Mode)
{
	new Float:EntityOrigin[3];
	new Float:EntityVelocity[3];
	if(KnockUp == 0.0) get_entvar(Entity, var_velocity, EntityVelocity);
	get_entvar(Entity, var_origin, EntityOrigin);

	new Float:Distance; Distance = get_distance_f(EntityOrigin, TargetOrigin);
	new Float:Time; Time = Distance / Knockback;

	new Float:V1[3], Float:V2[3];
	if(Mode) V1 = EntityOrigin, V2 = TargetOrigin; // Konumdan İttirme 
	else V2 = EntityOrigin, V1 = TargetOrigin; // Konuma Çekme

	EntityVelocity[0] = (V1[0] - V2[0]) / Time;
	EntityVelocity[1] = (V1[1] - V2[1]) / Time;
	if(KnockUp > 0.0) EntityVelocity[2] = KnockUp;
	else if(KnockUp < 0.0) EntityVelocity[2] = (V1[2] - V2[2]) / Time;

	set_entvar(Entity, var_velocity, EntityVelocity);
}    

bool:Compare_Target_And_Entity_Angle(const entityIndex, const targetIndex, const Float:ViewDis)
{
	new Float:Origin[3]; get_entvar(entityIndex, var_origin, Origin);
	new Float:Angles[3]; get_entvar(entityIndex, var_v_angle, Angles);
	new Float:Target[3]; get_entvar(targetIndex, var_origin, Target);
	new Float:Radians = floatatan2(Target[1] - Origin[1], Target[0] - Origin[0], radian);
	new Float:GoalAngles[3]; GoalAngles[1] = Radians * (180 / 3.14);
    	
	new Float:Distance = 180.0 - floatabs(floatabs(GoalAngles[1] - Angles[1]) - 180.0);
	if(Distance <= ViewDis) return true;
	return false;
}   
   
Get_Position(const iEntityIndex, const Float:fForwardAdd, const Float:fRightAdd, const Float:fUpAdd, Float:vPosition[3], const Float:vCustomAngle[3], const bool:WorkCustomAngle, const Float:vCustomOrigin[3], const bool:WorkCustomOrigin)
{
	static Float:vEntityAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3];
	
	if(WorkCustomOrigin) {
		vPosition = vCustomOrigin;
	} else {
		get_entvar(iEntityIndex, var_origin, vPosition);
		get_entvar(iEntityIndex, var_view_ofs, vUp);
		xs_vec_add(vPosition, vUp, vPosition);
	}
	
	if(!WorkCustomAngle)
	{
		if(iEntityIndex > MAX_PLAYERS) get_entvar(iEntityIndex, var_angles, vEntityAngle);
		else get_entvar(iEntityIndex, var_v_angle, vEntityAngle);
	} else {
		vEntityAngle = vCustomAngle;
	}

	if(fForwardAdd != 0.0) angle_vector(vEntityAngle, ANGLEVECTOR_FORWARD, vForward);
	if(fRightAdd != 0.0) angle_vector(vEntityAngle, ANGLEVECTOR_RIGHT, vRight);
	if(fUpAdd != 0.0) angle_vector(vEntityAngle, ANGLEVECTOR_UP, vUp);
	
	vPosition[0] += vForward[0] * fForwardAdd + vRight[0] * fRightAdd + vUp[0] * fUpAdd;
	vPosition[1] += vForward[1] * fForwardAdd + vRight[1] * fRightAdd + vUp[1] * fUpAdd;
	vPosition[2] += vForward[2] * fForwardAdd + vRight[2] * fRightAdd + vUp[2] * fUpAdd;
}    

bool:Can_See(const clientIndex, const targetIndex)
{
	new flags = pev(clientIndex, pev_flags);
	if (flags & EF_NODRAW || flags & FL_NOTARGET)
	{
		return false;
	}

	new Float:lookerOrig[3];
	new Float:targetBaseOrig[3];
	new Float:targetOrig[3];
	new Float:temp[3];

	get_entvar(clientIndex, var_origin, lookerOrig);
	get_entvar(clientIndex, var_view_ofs, temp);
	xs_vec_add(lookerOrig, temp, lookerOrig);

	get_entvar(targetIndex, var_origin, targetBaseOrig);
	get_entvar(targetIndex, var_view_ofs, temp);
	xs_vec_add(targetBaseOrig, temp, targetOrig);

	engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, IGNORE_MONSTERS, clientIndex, 0);
	if (get_tr2(0, TraceResult:TR_InOpen) && get_tr2(0, TraceResult:TR_InWater))
	{
		return false;
	} 
	else 
	{
		new Float:flFraction;
		get_tr2(0, TraceResult:TR_flFraction, flFraction);
		if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == targetIndex))
		{
			return true;
		}
		else
		{
			targetOrig = targetBaseOrig;
			engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, IGNORE_MONSTERS, clientIndex, 0); 
			get_tr2(0, TraceResult:TR_flFraction, flFraction);
			if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == targetIndex))
			{
				return true;
			}
			else
			{
				targetOrig = targetBaseOrig;
				targetOrig[2] -= 17.0;
				engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, IGNORE_MONSTERS, clientIndex, 0); 
				get_tr2(0, TraceResult:TR_flFraction, flFraction);
				if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == targetIndex))
				{
					return true;
				}
			}
		}
	}
	return false;
}
	
Load_Weapon_Configs()
{
	new szPath[64]; get_configsdir(szPath, charsmax(szPath));
	format(szPath, charsmax(szPath), "%s/%s", szPath, WEAPONS_FILE);

	if (!file_exists(szPath))
	{
		new Error[100]; formatex(Error, charsmax(Error), "Dosya bulunamadi %s!", szPath);
		set_fail_state(Error);
		return;
	}

	new linedata[1024], key[64], value[960], File = fopen(szPath, "rt"), bool:isGun, bool:isNewGun = true, Float:fValue;
	while(File && !feof(File))
	{
		fgets(File, linedata, charsmax(linedata));
		replace(linedata, charsmax(linedata), "^n", "");

		if (!linedata[0] || linedata[0] == ';' || (linedata[0] == '/' && linedata[1] == '/')) continue;
			
		if (linedata[0] == '[')
		{
			linedata[strlen(linedata) - 1] = 0;
			copy(linedata, charsmax(linedata), linedata[1]);
				
			if(equal(linedata, PLUGIN))
			{
				isGun = true;
				isNewGun = false;
			} else isGun = false;
		}
		if(!isGun) 
			continue;

		strtok(linedata, key, charsmax(key), value, charsmax(value), '=');
			
		trim(key);
		trim(value);

		fValue = str_to_float(value);
		if(equal(key, "DAMAGE SLASH NORMAL")) 
		{
			fValues[DAMAGE_A] = floatmax(fValue, 1.0);
		} else if(equal(key, "DAMAGE SLASH CHARGED")) {
			fValues[DAMAGE_A2] = floatmax(fValue, 1.0);
		} else if(equal(key, "DAMAGE STAB NORMAL")) {
			fValues[DAMAGE_B] = floatmax(fValue, 1.0);
		} else if(equal(key, "DAMAGE STAB CHARGED")) {
			fValues[DAMAGE_B2] = floatmax(fValue, 1.0);
		} else if(equal(key, "DAMAGE WHIP EXPLOSION")) {
			fValues[DAMAGE_C] = floatmax(fValue, 1.0);
		} else if(equal(key, "RANGE SLASH NORMAL")) {
			fValues[RANGE_A] = floatmax(fValue, 1.0);
		} else if(equal(key, "RANGE SLASH CHARGED")) {
			fValues[RANGE_A2] = floatmax(fValue, 1.0);
		} else if(equal(key, "RANGE STAB NORMAL")) {
			fValues[RANGE_B] = floatmax(fValue, 1.0);
		} else if(equal(key, "RANGE STAB CHARGED")) {
			fValues[RANGE_B2] = floatmax(fValue, 1.0);
		} else if(equal(key, "RANGE WHIP EXPLOSION")) {
			fValues[RANGE_C] = floatmax(fValue, 1.0);
		} else if(equal(key, "KNOCKBACK WHIP EXPLOSION")) {
			fValues[KNOCKBACK_C] = floatmax(fValue, 0.0);
		} else if(equal(key, "KNOCKUP WHIP EXPLOSION")) {
			fValues[KNOCKUP_C] = floatmax(fValue, 0.0);
		} else if(equal(key, "STAB HOOK SPEED")) {
			fValues[HOOK_SPEED] = floatmax(fValue, 0.0);
		}
	}

	if (File) fclose(File);

	if(isNewGun) Save_Weapon_Configs();
}

Save_Weapon_Configs()
{
	new szBuffer[512], szPath[64], File; get_configsdir(szPath, charsmax(szPath));
	format(szPath, charsmax(szPath), "%s/%s", szPath, WEAPONS_FILE);

	File = fopen(szPath, "at");

	format(szBuffer, charsmax(szBuffer), "^n[%s]", PLUGIN);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Sol tıklayınca yapılan mavi saldırıların hasarını ayarlar.");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nDAMAGE SLASH NORMAL = %0.1f", fValues[DAMAGE_A]);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Sol tıka basılı tutunca yapılan kırmızı saldırıların hasarını ayarlar.");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nDAMAGE SLASH CHARGED = %0.1f", fValues[DAMAGE_A2]);
	fputs(File, szBuffer);
	
	formatex(szBuffer, charsmax(szBuffer), "^n// Sağ tıklayınca yapılan mavi saldırıların hasarını ayarlar.");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nDAMAGE STAB NORMAL = %0.1f", fValues[DAMAGE_B]);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Sağ tıka basılı tutunca yapılan seri saldırıların hasarını ayarlar.");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nDAMAGE STAB CHARGED = %0.1f", fValues[DAMAGE_B2]);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Kombo hareketi yapınca verilen hasarı ayarlar.");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nDAMAGE WHIP EXPLOSION = %0.1f", fValues[DAMAGE_C]);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Sol tıklayınca yapılan mavi saldırıların menzilini ayarlar.");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nRANGE SLASH NORMAL = %0.1f", fValues[RANGE_A]);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Sol tıka basılı tutunca yapılan kırmızı saldırıların menzilini ayarlar.");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nRANGE SLASH CHARGED = %0.1f", fValues[RANGE_A2]);
	fputs(File, szBuffer);
	
	formatex(szBuffer, charsmax(szBuffer), "^n// Sağ tıklayınca yapılan mavi saldırıların menzilini ayarlar.");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nRANGE STAB NORMAL = %0.1f", fValues[RANGE_B]);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Sağ tıka basılı tutunca yapılan seri saldırıların menzilini ayarlar.");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nRANGE STAB CHARGED = %0.1f", fValues[RANGE_B2]);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Kombo hareketi yapınca saldırının menzilini ayarlar.");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nRANGE WHIP EXPLOSION = %0.1f", fValues[RANGE_C]);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Kombo hareketi yapınca saldırının düşmanı ittirme hızını ayarlar (0 yaparsan kapanır).");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nKNOCKBACK WHIP EXPLOSION = %0.1f", fValues[KNOCKBACK_C]);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Kombo hareketi yapınca saldırının düşmanı havaya kaldırma hızını ayarlar (0 yaparsan kapanır).");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nKNOCKUP WHIP EXPLOSION = %0.1f", fValues[KNOCKUP_C]);
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^n// Kombo hareketi yapınca kırbaçla duvara çekme hızını ayarlar (0 yaparsan kapanır).");
	fputs(File, szBuffer);

	formatex(szBuffer, charsmax(szBuffer), "^nSTAB HOOK SPEED = %0.1f^n", fValues[HOOK_SPEED]);
	fputs(File, szBuffer);

	fclose(File);
}