/*
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/* All4Dead - A modification for the game Left4Dead */
/* Copyright 2009 James Richardson */

/* Define constants */
#define PLUGIN_VERSION    "1.2.0"
#define PLUGIN_NAME       "All4Dead"
#define PLUGIN_TAG  	  "[A4D] "

/* Include necessary files */
#include <sourcemod>
/* Make the admin menu optional */
#undef REQUIRE_PLUGIN
#include <adminmenu>

/* Create ConVar Handles */
new Handle:NotifyPlayers = INVALID_HANDLE
new Handle:AutomaticPlacement = INVALID_HANDLE
new Handle:AutomaticReset = INVALID_HANDLE
new Handle:OnlyHeadShotsKill = INVALID_HANDLE

/* Create handle for the admin menu */
new Handle:AdminMenu = INVALID_HANDLE
new TopMenuObject:dc = INVALID_TOPMENUOBJECT;
new TopMenuObject:sc = INVALID_TOPMENUOBJECT;
new TopMenuObject:cc = INVALID_TOPMENUOBJECT;

/* Metadata for the mod */
public Plugin:myinfo = {
	name = PLUGIN_NAME,
	author = "James Richardson (grandwazir)",
	description = "Enables admins to have control over the AI Director",
	version = PLUGIN_VERSION,
	url = "www.grandwazir.com"
};

/* Create and set all the necessary for All4Dead and register all our commands */ 
public OnPluginStart() {
	/* Create all the necessary ConVars and execute auto-configuation */
	CreateConVar("a4d_version", PLUGIN_VERSION, "The version of All4Dead plugin.", FCVAR_PLUGIN);
	CreateConVar("a4d_director_is_enabled", "1", "Whether or not the AI director is running.", FCVAR_PLUGIN|FCVAR_CHEAT);
	CreateConVar("a4d_zombies_to_add", "10", "The amount of zombies to add when an admin requests more zombies.", FCVAR_PLUGIN|FCVAR_CHEAT);
	NotifyPlayers = CreateConVar("a4d_notify_players", "1", "Whether or not we announce changes in game.", FCVAR_PLUGIN|FCVAR_CHEAT);
	AutomaticPlacement = CreateConVar("a4d_automatic_placement", "1", "Whether or not we ask the director to place things we spawn.", FCVAR_PLUGIN|FCVAR_CHEAT);
	AutomaticReset = CreateConVar("a4d_automatically_reset_settings", "1", "Whether or not we automatically restore game defaults at the end of a map.", FCVAR_PLUGIN|FCVAR_CHEAT); 	
	OnlyHeadShotsKill = CreateConVar("a4d_only_head_shots_kill", "1", "Whether or not infected can only be killed by headshots.", FCVAR_PLUGIN|FCVAR_CHEAT); 	
	/* We make sure that only admins that are permitted to cheat are allow to run these commands */
	/* Register all the director commands */
	RegAdminCmd("a4d_force_panic", Command_ForcePanic, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_panic_forever", Command_PanicForever, ADMFLAG_CHEATS);	
	RegAdminCmd("a4d_force_tank", Command_ForceTank, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_force_witch", Command_ForceWitch, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_delay_rescue", Command_DelayRescue, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_add_zombies", Command_AddZombies, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_spawn", Command_Spawn, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_reset_to_defaults", Command_ResetToDefaults, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_toggle_director", Command_ToggleDirector, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_toggle_auto_placement", Command_ToggleAutoPlacement, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_toggle_notifications", Command_ToggleNotifications, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_toggle_auto_reset", Command_ToggleAutomaticReset, ADMFLAG_CHEATS);
	
	HookEvent("infected_killed", Event_InfectedKilled, EventHookMode_Pre)

	/* Admin menu stuff */
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		/* If so, manually fire the callback */
		OnAdminMenuReady(topmenu);
	}
}

/* If the admin menu is unloaded, stop trying to use it */
public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu"))
	{
		AdminMenu = INVALID_HANDLE;
	}
}

/* When a map ends, if a4d_automatically_reset_settings is true, reset all settings back to their defaults */
public OnMapStart() {
	if (GetConVarBool(AutomaticReset) == true) {
		new notify = GetConVarBool(NotifyPlayers)
		StripAndChangeServerConVarBool("a4d_notify_players", false)
		ResetToDefaults(0)
		StripAndChangeServerConVarBool("a4d_notify_players", notify)
		LogAction(0, -1, "Reverted settings back to defaults.");
	}
}

public OnPluginEnd() {
	ResetToDefaults(0)
	LogAction(0, -1, "Reset settings back to their defaults.");
}

public Action:Event_InfectedKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(OnlyHeadShotsKill)) {	
		if (GetEventBool(event, "headshot") != true)
		{
			return Plugin_Handled
		}
	}
	return Plugin_Continue
}
/* Force the AI director to trigger a panic event */
/* There does seem to be a cooldown on this command and it is very noisy. If you just want to spawn more zombies, use spawn mob instead */
public Action:Command_ForcePanic(client, args) {
	ForcePanic(client)
	return Plugin_Handled;
}

ForcePanic(client) {
	new String:command[] = "director_force_panic_event";
	StripAndExecuteClientCommand(client, command, "","","")
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_TAG, "A panic event has been started."); }
	LogAction(client, -1, "(%L) executed %s", client, command);
}

/* Force the AI Director to start panic events constantly, one after each another, until asked politely to stop. */
/* It won't start working until a panic event has been triggered. If you want it to start doing this straight away trigger a panic event. */
public Action:Command_PanicForever(client, args) {
	
	if (args < 1) { PrintToConsole(client, "Usage: a4d_panic_forever <0|1>"); return Plugin_Handled; }
	
	new String:command[] = "director_panic_forever";
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		StripAndChangeServerConVarBool(command, false)
		if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_TAG, "Endless panic events have ended."); }
		LogAction(client, -1, "(%L) set %s to %i", client, command, value);
	} else if (StrEqual(value, "1")) {
		StripAndChangeServerConVarBool(command, true)
		if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_TAG, "Endless panic events have started."); }
		LogAction(client, -1, "(%L) set %s to %i", client, command, value);
	} else {
		PrintToConsole(client, "Usage: a4d_panic_forever <0|1>")
	}
	return Plugin_Handled;
}

PanicForever(client, bool:value) {
	new String:command[] = "director_panic_forever";
	StripAndChangeServerConVarBool(command, value)
	if (GetConVarBool(NotifyPlayers) == true) {	
		if (value == true) {
			ShowActivity2(client, PLUGIN_TAG, "Endless panic events have started.");
		} else {
			ShowActivity2(client, PLUGIN_TAG, "Endless panic events have ended.");
		}
	}
	LogAction(client, -1, "(%L) set %s to %i", client, command, value);	
}

/* This command forces the AI Director to spawn a tank this round. The admin doesn't have control over where it spawns or when. */
/* I am not certain but pretty confident that if a tank has already been spawned this won't force the director to spawn another. */
public Action:Command_ForceTank(client, args) {
	
	if (args < 1) { PrintToConsole(client, "Usage: a4d_force_tank <0|1>"); return Plugin_Handled; }
	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		ForceTank(client, false)		
	} else if (StrEqual(value, "1")) {
		ForceTank(client, true)
	} else {
		PrintToConsole(client, "Usage: a4d_force_tank <0|1>")
	}
	return Plugin_Handled;
}

ForceTank(client, bool:value) {
	new String:command[] = "director_force_tank";
	StripAndChangeServerConVarBool(command, value)
	if (GetConVarBool(NotifyPlayers) == true) {	
		if (value == true) {
			ShowActivity2(client, PLUGIN_TAG, "A tank is guaranteed to spawn this round");
		} else {
			ShowActivity2(client, PLUGIN_TAG, "A tank is no longer guaranteed to spawn this round");
		}
	}
	LogAction(client, -1, "(%L) set %s to %i", client, command, value);	
}

/* Force the AI Director to spawn a witch somewhere in the players path this round. The admin doesn't have control over where it spawns or when. */
/* I am not certain but pretty confident that if a witch has already been spawned this won't force the director to spawn another. */
public Action:Command_ForceWitch(client, args) {
	
	if (args < 1) { PrintToConsole(client, "Usage: a4d_force_witch <0|1>"); return Plugin_Handled; }	

	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		ForceWitch(client, false)		
	} else if (StrEqual(value, "1")) {
		ForceWitch(client, true)
	} else {
		PrintToConsole(client, "Usage: a4d_force_witch <0|1>")
	}
	return Plugin_Handled;
}

ForceWitch(client, bool:value) {
	new String:command[] = "director_force_witch";
	StripAndChangeServerConVarBool(command, value)
	if (GetConVarBool(NotifyPlayers) == true) {	
		if (value == true) {
			ShowActivity2(client, PLUGIN_TAG, "A tank is guaranteed to spawn this round");	
		} else {
			ShowActivity2(client, PLUGIN_TAG, "A tank is no longer guaranteed to spawn this round");
		}
	}
	LogAction(client, -1, "(%L) set %s to %i", client, command, value);	
}

/* Force the AI Director to delay the rescue vehicle indefinitely */
/* This means that the end wave essentially never stops. The director makes sure that one tank is always alive at all times during the last wave. */ 
/* Disabling this once the survivors have reached the last wave of the finale seems to have no effect (can anyone test this to be sure?) */
public Action:Command_DelayRescue(client, args) {
	
	if (args < 1) { PrintToConsole(client, "Usage: a4d_delay_rescue <0|1>"); return Plugin_Handled; }	
	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		DelayRescue(client, false)		
	} else if (StrEqual(value, "1")) {
		DelayRescue(client, true)
	} else {
		PrintToConsole(client, "Usage: a4d_delay_rescue <0|1>")
	}
	return Plugin_Handled;
}

DelayRescue(client, bool:value) {
	new String:command[] = "director_finale_infinite";
	StripAndChangeServerConVarBool(command, value)
	if (GetConVarBool(NotifyPlayers) == true) { 	
		if (value == true) {
			ShowActivity2(client, PLUGIN_TAG, "The rescue vehicle has been delayed indefinitely.");
		} else {
			ShowActivity2(client, PLUGIN_TAG, "The rescue vehicle is on its way.");
		}
	}
	LogAction(client, -1, "(%L) set %s to %i", client, command, value);	
}

/* This enables the AI Director to spawn more zombies in the mobs and mega mobs */
/* Make sure to not put silly values in for this as it may cause severe performance problems. */
/* You can reset all settings back to their defaults by calling a4d_reset_to_defaults */
public Action:Command_AddZombies(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_add_zombies <0..99>"); return Plugin_Handled; }	

	new String:value[3]
	new zombies	
	GetCmdArg(1, value, sizeof(value))
	zombies = StringToInt(value)
	AddZombies(client, zombies)
	return Plugin_Handled;
}

AddZombies(client, zombies_to_add) {
	new new_zombie_total	
	new_zombie_total = zombies_to_add + GetConVarInt(FindConVar("z_mega_mob_size"))
	StripAndChangeServerConVarInt("z_mega_mob_size", new_zombie_total)
	LogAction(client, -1, "(%L) set %s to %i", client, "z_mega_mob_size", new_zombie_total);
	new_zombie_total = zombies_to_add + GetConVarInt(FindConVar("z_mob_spawn_max_size"))
	StripAndChangeServerConVarInt("z_mob_spawn_max_size", new_zombie_total)
	LogAction(client, -1, "(%L) set %s to %i", client, "z_mob_spawn_max_size", new_zombie_total);
	new_zombie_total = zombies_to_add + GetConVarInt(FindConVar("z_mob_spawn_min_size"))
	StripAndChangeServerConVarInt("z_mob_spawn_min_size", new_zombie_total)
	LogAction(client, -1, "(%L) set %s to %i", client, "z_mob_spawn_min_size", new_zombie_total);
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_TAG, "More zombies will now be spawned."); }
}

/* This toggles the AI Director on or off */
/* Since there is no way to query the directors state in-game, we keep track of this infomation ourself in a4d_director_enabled */
/* The mod assumes that the director is enabled at the start of each map */
public Action:Command_ToggleDirector(client, args) {
	
	if (args < 1) { PrintToConsole(client, "Usage: a4d_toggle_director <0|1>"); return Plugin_Handled; }	
	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		StopDirector(client)		
	} else if (StrEqual(value, "1")) {
		StartDirector(client)
	} else {
		PrintToConsole(client, "Usage: a4d_toggle_director <0|1>")
	}
	return Plugin_Handled;
}

StartDirector(client) {
	new String:command[] = "director_start";	
	StripAndExecuteClientCommand(client, command, "","","")
	StripAndChangeServerConVarBool("a4d_director_is_enabled", true)
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_TAG, "The director has been enabled."); }
	LogAction(client, -1, "(%L) executed %s", client, command);
}

StopDirector(client) {
	new String:command[] = "director_stop";	
	StripAndExecuteClientCommand(client, command, "","","")
	StripAndChangeServerConVarBool("a4d_director_is_enabled", false)
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_TAG, "The director has been disabled."); }
	LogAction(client, -1, "(%L) executed %s", client, command);
}

/* This spawns an infected of your choice either at your crosshair if a4d_automatic_placement is false or automatically */
/* Currently you can only spawn one thing at once. */
public Action:Command_Spawn(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_spawn <tank|witch|boomer|hunter|smoker|common|mob>"); return Plugin_Handled; }	
		
	new String:type[7]	
	GetCmdArg(1, type, sizeof(type))
	Spawn(client, type)
	return Plugin_Handled;
}

Spawn(client, String:type[]) {
	new String:command[] = "z_spawn";

	if (GetConVarBool(AutomaticPlacement) == true) {
		StripAndExecuteClientCommand(client, command, type, "auto", "")
	} else {
		StripAndExecuteClientCommand(client, command, type, "", "")
	}

	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_TAG, "A %s has been spawned", type); }
	LogAction(client, -1, "(%L) has spawned a %s", client, type);
}

/* This toggles whether or not we want the director to automatically place the things we spawn */
/* The director will place mobs outside the players sight so it will not look like they are magically appearing */
public Action:Command_ToggleAutoPlacement(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_toggle_auto_placement <0|1>"); return Plugin_Handled; }	
	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		ToggleAutoPlacement(client, false)		
	} else if (StrEqual(value, "1")) {
		ToggleAutoPlacement(client, true)	
	} else {
		PrintToConsole(client, "Usage: a4d_toggle_auto_placement <0|1>")
	}
	return Plugin_Handled;
}

ToggleAutoPlacement(client, bool:value) {
	new String:command[] = "a4d_automatic_placement";
	StripAndChangeServerConVarBool(command, value)
	if (GetConVarBool(NotifyPlayers) == true) { 	
		if (value == true) {
			ShowActivity2(client, PLUGIN_TAG, "Automatic placement of spawned infected has been enabled.");
		} else {
			ShowActivity2(client, PLUGIN_TAG, "Automatic placement of spawned infected has been disabled.");
		}
	}
	LogAction(client, -1, "(%L) set %s to %i", client, command, value);	
}

/* Set if we should notify players based on the sm_activity ConVar or not */
public Action:Command_ToggleNotifications(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_toggle_notifications <0|1>"); return Plugin_Handled; }	
	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		ToggleNotifications(client, false)		
	} else if (StrEqual(value, "1")) {
		ToggleNotifications(client, true)	
	} else {
		PrintToConsole(client, "Usage: a4d_toggle_notifications <0|1>")
	}
	return Plugin_Handled;
}

ToggleNotifications(client, bool:value) {
	new String:command[] = "a4d_notify_players";
	StripAndChangeServerConVarBool(command, value)
	if (GetConVarBool(NotifyPlayers) == true) { 	
		ShowActivity2(client, PLUGIN_TAG, "Player notifications have now been enabled.");
	}
	LogAction(client, -1, "(%L) set %s to %i", client, command, value);	
}

/* This toggles if we want to revert back to the game defaults on each map start */
public Action:Command_ToggleAutomaticReset(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_toggle_automatic_reset <0|1>"); return Plugin_Handled; }	
	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		ToggleAutomaticReset(client, false)		
	} else if (StrEqual(value, "1")) {
		ToggleAutomaticReset(client, true)	
	} else {
		PrintToConsole(client, "Usage: a4d_toggle_automatic_reset <0|1>")
	}
	return Plugin_Handled;
}

ToggleAutomaticReset(client, bool:value) {
	new String:command[] = "a4d_automatically_reset_settings";
	StripAndChangeServerConVarBool(command, value)
	if (GetConVarBool(NotifyPlayers) == true) { 	
		if (value == true) {
			ShowActivity2(client, PLUGIN_TAG, "Game defaults will be restored at the start of each map.");
		} else {
			ShowActivity2(client, PLUGIN_TAG, "Settings will now not be restored automatically.");
		}
	}
	LogAction(client, -1, "(%L) set %s to %i", client, command, value);	
}
/* Resets all ConVars to their default settings. */
/* Should be used if you screwed something up or at the beginning of every map to have a normal game */
public Action:Command_ResetToDefaults(client, args) {

	ResetToDefaults(client)
	return Plugin_Handled;

}

ResetToDefaults(client) {
	ForceTank(client, false)
	ForceWitch(client, false)
	PanicForever(client, false)
	DelayRescue(client, false)
	StripAndChangeServerConVarInt("z_mega_mob_size", 50);
	LogAction(client, -1, "%L) set %s to %i", client, "z_mob_spawn_max_size", 50);
	StripAndChangeServerConVarInt("z_mob_spawn_max_size", 30)
	LogAction(client, -1, "(%L) set %s to %i", client, "z_mob_spawn_max_size", 30);
	StripAndChangeServerConVarInt("z_mob_spawn_min_size", 10)
	LogAction(client, -1, "(%L) set %s to %i", client, "z_mob_spawn_max_size", 10);
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_TAG, "Restored the default settings."); }
	LogAction(client, -1, "(%L) executed %s", client, "a4d_reset_to_defaults");
}

/* This toggles if we want to revert back to the game defaults on each map start */
public Action:Command_SetDifficulty(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_set_difficulty <0=easy|1=normal|2=advanced|3=expert>"); return Plugin_Handled; }	
	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		SetDifficulty(client, 0)	
	} else if (StrEqual(value, "1")) {
		SetDifficulty(client, 1)	
	} else if (StrEqual(value, "2")) {
		SetDifficulty(client, 2)
	} else if (StrEqual(value, "2")) {
		SetDifficulty(client, 3)
	} else {	
		PrintToConsole(client, "Usage: a4d_toggle_automatic_reset <0|1>")
	}
	return Plugin_Handled;
}

SetDifficulty(client, value) {
	new String:command[] = "z_difficulty";
	SetConVarInt(FindConVar(command), value, false, true);
	if (GetConVarBool(NotifyPlayers) == true) { 	
		switch (value) {
			case 0: {
				ShowActivity2(client, PLUGIN_TAG, "The difficulty has been changed to easy.");
			} case 1: {
				ShowActivity2(client, PLUGIN_TAG, "The difficulty has been changed to normal.");
			} case 2: {
				ShowActivity2(client, PLUGIN_TAG, "The difficulty has been changed to advanced.");
			} case 3: {
				ShowActivity2(client, PLUGIN_TAG, "The difficulty has been changed to expert.");
			}
		}
	}
	LogAction(client, -1, "(%L) set %s to %i", client, command, value);	
}

public Action:Command_AllBotTeam(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_all_bot_team <0|1>"); return Plugin_Handled; }	
	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		AllBotTeam(cindex, false)	
	} else if (StrEqual(value, "1")) {
		AllBotTeam(cindex, true)	
	} else {	
		PrintToConsole(client, "Usage: a4d_all_bot_team <0|1>")
	}
	return Plugin_Handled;
}

AllBotTeam(client, bool:value) {
	new String:command[] = "sb_all_bot_team";
	StripAndChangeServerConVarBool(command, value)
	if (GetConVarBool(NotifyPlayers) == true) { 	
		if (value == true) {
			ShowActivity2(client, PLUGIN_TAG, "All survivors are now allowed to be bots.");
		} else {
			ShowActivity2(client, PLUGIN_TAG, "There must be one human survivor for the game to start.");
		}
	}
	LogAction(client, -1, "(%L) set %s to %i", client, command, value);	
}

public Action:Command_AllBotTeam(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_only_head_shots_kill <0|1>"); return Plugin_Handled; }	
	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		OnlyHeadShotsKill(cindex, false)	
	} else if (StrEqual(value, "1")) {
		OnlyHeadShotsKill(cindex, true)	
	} else {	
		PrintToConsole(client, "Usage: a4d_only_head_shots_kill <0|1>")
	}
	return Plugin_Handled;
}

OnlyHeadShotsKill(client, bool:value) {
	new String:command[] = "a4d_only_head_shots_kill";
	StripAndChangeServerConVarBool(command, value)
	if (GetConVarBool(NotifyPlayers) == true) { 	
		if (value == true) {
			ShowActivity2(client, PLUGIN_TAG, "Only head shots will kill zombies.");
		} else {
			ShowActivity2(client, PLUGIN_TAG, "Hitting zombies anywhere will kill them.");
		}
	}
	LogAction(client, -1, "(%L) set %s to %i", client, command, value);	
}

/* Menu Functions */

/* Load our categories and menus */
public OnAdminMenuReady(Handle:TopMenu) {
	/* Block us from being called twice */
	if (TopMenu == AdminMenu) { return; }
	
	AdminMenu = TopMenu;
 
	/* Add a category to the SourceMod menu called "Director Commands" */
	AddToTopMenu(AdminMenu, "All4Dead Commands", TopMenuObject_Category, CategoryHandler, INVALID_TOPMENUOBJECT)
	/* Get a handle for the catagory we just added so we can add items to it */
	new TopMenuObject:afd_commands = FindTopMenuCategory(AdminMenu, "All4Dead Commands");
	
	/* Don't attempt to add items to the catagory if for some reason the catagory doesn't exist */
	if (afd_commands == INVALID_TOPMENUOBJECT) { return; }
	
	/* The order that items are added to menus has no relation to the order that they appear. Items are sorted alphabetically automatically */
	/* Assign the menus to global values so we can easily check what a menu is when it is chosen */
	dc = AddToTopMenu(AdminMenu, "a4d_show_director_commands", TopMenuObject_Item, Menu_TopItemHandler, afd_commands, "a4d_show_director_commands", ADMFLAG_CHEATS);
	sc = AddToTopMenu(AdminMenu, "a4d_show_spawn_commands", TopMenuObject_Item, Menu_TopItemHandler, afd_commands, "a4d_show_spawn_commands", ADMFLAG_CHEATS);
	cc = AddToTopMenu(AdminMenu, "a4d_show_config_commands", TopMenuObject_Item, Menu_TopItemHandler, afd_commands, "a4d_show_config_commands", ADMFLAG_CHEATS);

}

/* This handles the top level "All4Dead" category and how it is displayed on the core admin menu */
public CategoryHandler(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, client, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "All4Dead Commands:");
	}
	else if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "All4Dead Commands");
	}
}

/* This deals with what happens someone opens the "All4Dead" category from the menu */ 
public Menu_TopItemHandler(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, client, String:buffer[], maxlength)
{
	/* When an item is displayed to a player tell the menu to format the item */
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == dc) {
			Format(buffer, maxlength, "Director Commands");
		} else if (object_id == sc) {
			Format(buffer, maxlength, "Spawn Commands");
		} else if (object_id == cc) {
			Format(buffer, maxlength, "Configuration Commands");
		}
	}
	
	/* When an item is selected do the following */
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == dc) {
			Menu_Director(client, false)
		} else if (object_id == sc) {
			Menu_Spawn(client, false)
		} else if (object_id == cc) {
			Menu_Config(client, false)
		}
	}
}

/* This menu deals with all the commands related to the director */
public Action:Menu_Director(client, args)
{
	new Handle:menu = CreateMenu(MenuHandler_Director)
	SetMenuTitle(menu, "Director Commands")
	
	AddMenuItem(menu, "fp", "Force a panic event to start")
	if (GetConVarBool(FindConVar("director_panic_forever"))) { AddMenuItem(menu, "pf", "End non-stop panic events"); } else { AddMenuItem(menu, "pf", "Force non-stop panic events"); }
	if (GetConVarBool(FindConVar("director_force_tank"))) { AddMenuItem(menu, "ft", "Director controls if a tank spawns this round"); } else { AddMenuItem(menu, "ft", "Force a tank to spawn this round"); }
	if (GetConVarBool(FindConVar("director_force_witch"))) { AddMenuItem(menu, "fw", "Director controls if a witch spawns this round"); } else { AddMenuItem(menu, "fw", "Force a witch to spawn this round"); }
	if (GetConVarBool(FindConVar("director_finale_infinite"))) { AddMenuItem(menu, "fi", "Allow the survivors to be rescued"); } else { AddMenuItem(menu, "fw", "Force an endless finale"); }	
	AddMenuItem(menu, "mz", "Add more zombies to the mobs")
	if (GetConVarBool(FindConVar("a4d_director_is_enabled"))) { AddMenuItem(menu, "td", "Disable the director"); } else { AddMenuItem(menu, "td", "Enable the director"); }	
	SetMenuExitButton(menu, true)
	DisplayMenu(menu, client, 20)
	return Plugin_Handled
}

public MenuHandler_Director(Handle:menu, MenuAction:action, cindex, itempos) {
	
	if (action == MenuAction_Select) {
		switch (itempos) {
			case 0: {
				ForcePanic(cindex)
			} case 1: {
				if (GetConVarBool(FindConVar("director_panic_forever"))) { 
					PanicForever(cindex, false) 
				} else {
					PanicForever(cindex, true)
				} 
			} case 2: {
				if (GetConVarBool(FindConVar("director_force_tank"))) { 
					ForceTank(cindex, false) 
				} else {
					ForceTank(cindex, true)
				}
			} case 3: {
				if (GetConVarBool(FindConVar("director_force_witch"))) { 
					ForceWitch(cindex, false) 
				} else {
					ForceWitch(cindex, true)
				}
			} case 4: {
				if (GetConVarBool(FindConVar("director_finale_infinite"))) { 
					DelayRescue(cindex, false) 
				} else {
					DelayRescue(cindex, true)
				}
			} case 5: {
				AddZombies(cindex, GetConVarInt(FindConVar("a4d_zombies_to_add")))
			} case 6: { 
				if (GetConVarBool(FindConVar("a4d_director_is_enabled"))) { 
					StopDirector(cindex) 
				} else {
					StartDirector(cindex)
				}
			}
		}
		
		Menu_Director(cindex, false)
		
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu)
	}
}

/* This menu deals with all commands related to spawning creatures */
public Action:Menu_Spawn(client, args)
{
	new Handle:menu = CreateMenu(MenuHandler_Spawn)
	SetMenuTitle(menu, "Spawn Commands")
	
	AddMenuItem(menu, "st", "Spawn a tank")
	AddMenuItem(menu, "sw", "Spawn a witch")
	AddMenuItem(menu, "sb", "Spawn a boomer")
	AddMenuItem(menu, "sh", "Spawn a hunter")
	AddMenuItem(menu, "ss", "Spawn a smoker")
	AddMenuItem(menu, "sm", "Spawn a mob")
	if (GetConVarBool(AutomaticPlacement)) { AddMenuItem(menu, "ap", "Disable automatic placement"); } else { AddMenuItem(menu, "ap", "Enable automatic placement"); }
	SetMenuExitButton(menu, true)
	DisplayMenu(menu, client, 20)
	return Plugin_Handled
}

public MenuHandler_Spawn(Handle:menu, MenuAction:action, cindex, itempos) {
	
	if (action == MenuAction_Select) {
		switch (itempos) {
			case 0: {
				Spawn(cindex, "tank")
			} case 1: {
				Spawn(cindex, "witch")
			} case 2: {
				Spawn(cindex, "boomer")
			} case 3: {
				Spawn(cindex, "hunter")
			} case 4: {
				Spawn(cindex, "smoker")
			} case 5: {
				Spawn(cindex, "mob")
			} case 6: { 
				if (GetConVarBool(AutomaticPlacement)) { 
					ToggleAutoPlacement(cindex, false) 
				} else {
					ToggleAutoPlacement(cindex, true) 
				}
			}
		}
		
		Menu_Spawn(cindex, false)
		
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu)
	}
}

/* This menu deals with all Configuration commands that don't fit into another category */
public Action:Menu_Config(client, args)
{
	new Handle:menu = CreateMenu(MenuHandler_Config)
	SetMenuTitle(menu, "Configuration Commands")
	if (GetConVarBool(NotifyPlayers)) { AddMenuItem(menu, "pn", "Disable player notifications"); } else { AddMenuItem(menu, "pn", "Enable player notifications"); }
	if (GetConVarBool(AutomaticReset)) { AddMenuItem(menu, "ar", "Do not reset game settings on map start"); } else { AddMenuItem(menu, "ar", "Restore game defaults on map start"); }
	AddMenuItem(menu, "rs", "Restore all settings now")
	SetMenuExitButton(menu, true)
	DisplayMenu(menu, client, 20)
	return Plugin_Handled
}

public MenuHandler_Config(Handle:menu, MenuAction:action, cindex, itempos) {
	
	if (action == MenuAction_Select) {
		switch (itempos) {
			case 0: {
				if (GetConVarBool(NotifyPlayers)) { 
					ToggleNotifications(cindex, false) 
				} else {
					ToggleNotifications(cindex, true) 
				} 
			} case 1: {
				if (GetConVarBool(AutomaticReset)) { 
					ToggleAutomaticReset(cindex, false) 
				} else {
					ToggleAutomaticReset(cindex, true) 
				} 
			} case 2: {
				ResetToDefaults(cindex)
			}
		}
		
		Menu_Config(cindex, false)
		
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu)
	}
}

/* This menu deals with all the various gameplay commands we have */
public Action:Menu_Game(client, args)
{
	new Handle:menu = CreateMenu(MenuHandler_Game)
	SetMenuTitle(menu, "Gameplay Settings")
	AddMenuItem(menu, "dn", "Set difficulty to easy")
	AddMenuItem(menu, "dn", "Set difficulty to normal")
	AddMenuItem(menu, "da", "Set difficulty to advanced")
	AddMenuItem(menu, "di", "Set difficulty to expert")
	if (GetConVarBool(FindConVar("sb_all_bot_team"))) { AddMenuItem(menu, "ab", "Require at least one human survivor"); } else { AddMenuItem(menu, "ab", "Allow all survivors to be bots"); };
	if (GetConVarBool(FindConVar("a4d_only_head_shots_kill"))) { AddMenuItem(menu, "oh", "Hitting zombies anywhere will kill"); } else { AddMenuItem(menu, "oh", "Only headshots kill zombies"); };
	SetMenuExitButton(menu, true)
	DisplayMenu(menu, client, 20)
	return Plugin_Handled
}

public MenuHandler_Game(Handle:menu, MenuAction:action, cindex, itempos) {
	
	if (action == MenuAction_Select) {
		switch (itempos) {
			case 0: {
				SetDifficulty(cindex, 0)
			} case 1: {
				SetDifficulty(cindex, 1)
			} case 2: {
				SetDifficulty(cindex, 2)
			} case 3: {
				SetDifficulty(cindex, 3)
			} case 4: {
				if (GetConVarBool(FindConVar("sb_all_bot_team"))) {
					AllBotTeam(cindex, false)
				} else {
					AllBotTeam(cindex, true)
				}
			} case 5: {
				if (GetConVarBool(FindConVar("a4d_only_head_shots_kill"))) {
					OnlyHeadShotsKill(cindex, false)
				} else {
					OnlyHeadShotsKill(cindex, true)
				}
			}
		}
		
		Menu_Config(cindex, false)
		
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu)
	}
}

/* Helper Functions */
/* This function strips the cheat flags from a command, executes it and then restores it to its former glory. */

/* This isn't used yet. It seems that most commands are called from the client and StripAndExecuteClientCommand should be used instead

StripAndExecuteServerCommand(String:command[], String:arg[]) {
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	ServerCommand(command);
	SetCommandFlags(command, flags);
}
*/

/* Strip and change a ConVar to the value specified */
StripAndChangeServerConVarBool(String:command[], bool:value) {
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	SetConVarBool(FindConVar(command), value, false, false);
	SetCommandFlags(command, flags);
}

/* Strip and change a ConVar to the value sppcified */
/* This doesn't do any maths. If you want to add 10 to an existing ConVar you need to work out the value before you call this */
StripAndChangeServerConVarInt(String:command[], value) {
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	SetConVarInt(FindConVar(command), value, false, false);
	SetCommandFlags(command, flags);
}

/* Does the same as the above but for client commands */
StripAndExecuteClientCommand(client, String:command[], String:param1[], String:param2[], String:param3[]) {
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s %s", command, param1, param2, param3)
	SetCommandFlags(command, flags);
}

