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
#define PLUGIN_VERSION    "1.0"
#define PLUGIN_NAME       "All4Dead"
#define PLUGIN_SHORTNAME  "A4D"

/* Include necessary files */
#include <sourcemod>
/* Make the admin menu optional */
#undef REQUIRE_PLUGIN
#include <adminmenu>

/* Create ConVar Handles */
new Handle:NotifyPlayers = INVALID_HANDLE
new Handle:AutomaticPlacement = INVALID_HANDLE

/* Kill Beast Stuff */
new KillBeastBuffetWave
new KillBeastBuffetAdmin
new Handle:KillBeastBuffetMaxWaves = INVALID_HANDLE
new Handle:KillBeastBuffetWaveTimer = INVALID_HANDLE
new Handle:KillBeastBuffetInterval = INVALID_HANDLE
new Handle:KillBeastBuffetInProgress = INVALID_HANDLE

/* Create handle for the admin menu */
new Handle:AdminMenu = INVALID_HANDLE
new TopMenuObject:dc = INVALID_TOPMENUOBJECT;
new TopMenuObject:sc = INVALID_TOPMENUOBJECT;

/* Metadata for the mod */
public Plugin:myinfo = {
	name = PLUGIN_NAME,
	author = "James Richardson (grandwazir)",
	description = "Enables admins to have control over the AI Director",
	version = PLUGIN_VERSION,
	url = "www.grandwazir.com"
};

public OnPluginStart() {
	/* Create all the necessary ConVars and execute auto-configuation */
	CreateConVar("a4d_version", PLUGIN_VERSION, "The version of All4Dead plugin.", FCVAR_PLUGIN);
	CreateConVar("a4d_director_is_enabled", "1", "Whether or not the AI director is running.", FCVAR_PLUGIN);
	CreateConVar("a4d_zombies_to_add", "10", "The amount of zombies to add when an admin requests more zombies.", FCVAR_PLUGIN);
	KillBeastBuffetInProgress = CreateConVar("a4d_kill_beast_buffet_in_progress", "0", "Whether or not it is feeding time at the kill beast buffet.", FCVAR_PLUGIN);
	KillBeastBuffetMaxWaves = CreateConVar("a4d_kill_beast_buffet_max_waves", "3", "The maximium number of waves after which the buffet will end.", FCVAR_PLUGIN);
	KillBeastBuffetInterval = CreateConVar("a4d_kill_beast_buffet_interval", "30", "The amount of time (in seconds) between waves.", FCVAR_PLUGIN);
	NotifyPlayers = CreateConVar("a4d_notify_players", "1", "Whether or not we announce changes in game.", FCVAR_PLUGIN);
	AutomaticPlacement = CreateConVar("a4d_automatic_placement", "1", "Whether or not we ask the director to place things we spawn.", FCVAR_PLUGIN);
	/* We make sure that only admins that are permitted to cheat are allow to run these commands */
	/* Register all the director commands */
	RegAdminCmd("a4d_force_panic", Command_ForcePanic, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_panic_forever", Command_PanicForever, ADMFLAG_CHEATS);	
	RegAdminCmd("a4d_force_tank", Command_ForceTank, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_force_witch", Command_ForceWitch, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_delay_rescue", Command_DelayRescue, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_add_zombies", Command_AddZombies, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_toggle_director", Command_ToggleDirector, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_emergency_reset", Command_EmergencyReset, ADMFLAG_CHEATS);
	
	RegAdminCmd("a4d_spawn", Command_Spawn, ADMFLAG_CHEATS);

	/* Admin menu stuff */
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		/* If so, manually fire the callback */
		OnAdminMenuReady(topmenu);
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu"))
	{
		AdminMenu = INVALID_HANDLE;
	}
}

/* Force the AI director to trigger a panic event */
public Action:Command_ForcePanic(client, args) {
	ForcePanic(client)
	return Plugin_Handled;
}

ForcePanic(client) {
	new String:command[] = "director_force_panic_event";
	StripAndExecuteServerCommand(command, "")
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_SHORTNAME, "A panic event has been started."); }
	LogAction(client, -1, "\"%L\" has executed %s", client, command);
}

/* Force the AI Director to start panic events constantly, one after each another, until asked politely to stop. */
/* It won't start working until a panic event has been triggered. If you want it to start doing this straight away trigger a panic event. */
public Action:Command_PanicForever(client, args) {
	
	if (args < 1) { PrintToConsole(client, "Usage: a4d_panic_forever <0|1>"); return Plugin_Handled; }
	
	new String:command[] = "director_panic_forever";
	new String:value[1]
	GetCmdArg(1, value, sizeof(value))

	if (StrEqual(value, "0")) {
		StripAndChangeServerConVarBool(command, false)
		if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_SHORTNAME, "Endless panic events have ended."); }
		LogAction(client, -1, "[%s]\"%L\" has set %s to %i", PLUGIN_SHORTNAME, client, command, value);
	} else if (StrEqual(value, "1")) {
		StripAndChangeServerConVarBool(command, true)
		if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_SHORTNAME, "Endless panic events have started."); }
		LogAction(client, -1, "[%s]\"%L\" has set %s to %i", PLUGIN_SHORTNAME, client, command, value);
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
			ShowActivity2(client, PLUGIN_SHORTNAME, "Endless panic events have started.");
		} else {
			ShowActivity2(client, PLUGIN_SHORTNAME, "Endless panic events have ended.");
		}
	}
	LogAction(client, -1, "[%s]\"%L\" has set %s to %i", PLUGIN_SHORTNAME, client, command, value);	
}

/* This command forces the AI Director to spawn a tank this round. The admin doesn't have control over where it spawns or when. */
/* I am not certain but pretty confident that if a tank has already been spawned this won't force the director to spawn another. */
public Action:Command_ForceTank(client, args) {
	
	if (args < 1) { PrintToConsole(client, "Usage: a4d_force_tank <0|1>"); return Plugin_Handled; }
	
	new String:value[1]
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
			ShowActivity2(client, PLUGIN_SHORTNAME, "A tank is guaranteed to spawn this round");
		} else {
			ShowActivity2(client, PLUGIN_SHORTNAME, "A tank is no longer guaranteed to spawn this round");
		}
	}
	LogAction(client, -1, "[%s]\"%L\" has set %s to %i", PLUGIN_SHORTNAME, client, command, value);	
}

/* Force the AI Director to spawn a witch somewhere in the players path this round. The admin doesn't have control over where it spawns or when. */
/* I am not certain but pretty confident that if a witch has already been spawned this won't force the director to spawn another. */
public Action:Command_ForceWitch(client, args) {
	
	if (args < 1) { PrintToConsole(client, "Usage: a4d_force_witch <0|1>"); return Plugin_Handled; }	

	
	new String:value[1]
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
			ShowActivity2(client, PLUGIN_SHORTNAME, "A tank is guaranteed to spawn this round");	
		} else {
			ShowActivity2(client, PLUGIN_SHORTNAME, "A tank is no longer guaranteed to spawn this round");
		}
	}
	LogAction(client, -1, "[%s]\"%L\" has set %s to %i", PLUGIN_SHORTNAME, client, command, value);	
}

/* Force the AI Director to delay the rescue vehicle indefinitely */
/* This means that the end wave essentially never stops. The director makes sure that one tank is always alive at all times during the last wave. */ 
/* Disabling this once the survivors have reached the last wave of the finale seems to have no effect (can anyone test this to be sure?) */
public Action:Command_DelayRescue(client, args) {
	
	if (args < 1) { PrintToConsole(client, "Usage: a4d_delay_rescue <0|1>"); return Plugin_Handled; }	
	
	new String:value[1]
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
			ShowActivity2(client, PLUGIN_SHORTNAME, "The rescue vehicle has been delayed indefinitely.");
		} else {
			ShowActivity2(client, PLUGIN_SHORTNAME, "The rescue vehicle is on its way.");
		}
	}
	LogAction(client, -1, "[%s]\"%L\" has set %s to %i", PLUGIN_SHORTNAME, client, command, value);	
}

public Action:Command_AddZombies(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_add_zombies <0..99>"); return Plugin_Handled; }	

	new String:value[2]
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
	LogAction(client, -1, "[%s]\"%L\" has set %s to %i", PLUGIN_SHORTNAME, client, "z_mega_mob_size", new_zombie_total);
	new_zombie_total = zombies_to_add + GetConVarInt(FindConVar("z_mob_spawn_max_size"))
	StripAndChangeServerConVarInt("z_mob_spawn_max_size", new_zombie_total)
	LogAction(client, -1, "[%s]\"%L\" has set %s to %i", PLUGIN_SHORTNAME, client, "z_mob_spawn_max_size", new_zombie_total);
	new_zombie_total = zombies_to_add + GetConVarInt(FindConVar("z_mob_spawn_min_size"))
	StripAndChangeServerConVarInt("z_mob_spawn_min_size", new_zombie_total)
	LogAction(client, -1, "[%s]\"%L\" has set %s to %i", PLUGIN_SHORTNAME, client, "z_mob_spawn_min_size", new_zombie_total);
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_SHORTNAME, "More zombies will now be spawned."); }
}

public Action:Command_ToggleDirector(client, args) {
	
	if (args < 1) { PrintToConsole(client, "Usage: a4d_toggle_director <0|1>"); return Plugin_Handled; }	
	
	new String:value[1]
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
	StripAndExecuteServerCommand(command, "")
	StripAndChangeServerConVarBool("a4d_director_is_enabled", true)
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_SHORTNAME, "The director has been enabled."); }
	LogAction(client, -1, "\"%L\" has executed %s", client, command);
}

StopDirector(client) {
	new String:command[] = "director_stop";	
	StripAndExecuteServerCommand(command, "")
	StripAndChangeServerConVarBool("a4d_director_is_enabled", false)
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_SHORTNAME, "The director has been disabled."); }
	LogAction(client, -1, "\"%L\" has executed %s", client, command);
}

public Action:Command_EmergencyReset(client, args) {
	EmergencyReset(client)
	return Plugin_Handled;
}

EmergencyReset(client) {
	StartDirector(client)
	DelayRescue(client, false)
	ForceTank(client, false)
	ForceWitch(client, false)
	PanicForever(client, false)
	StopKillBeastBuffet(client)
	StripAndChangeServerConVarInt("z_mega_mob_size", 50)
	StripAndChangeServerConVarInt("z_mob_spawn_max_size", 30)
	StripAndChangeServerConVarInt("z_mob_spawn_min_size", 10)
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_SHORTNAME, "An emergency reset has been requested."); }
	LogAction(client, -1, "\"%L\" has executed a4d_emergency_reset", client);
}
	

public Action:Command_Spawn(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_spawn <tank|witch|boomer|hunter|smoker|common|mob>"); return Plugin_Handled; }	
		
	new String:type[6]	
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

	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_SHORTNAME, "A %s has been spawned", type); }
	LogAction(client, -1, "[%s]\"%L\" has spawned a %s", PLUGIN_SHORTNAME, client, type);
}

public Action:Command_ToggleAutoPlacement(client, args) {

	if (args < 1) { PrintToConsole(client, "Usage: a4d_toggle_auto_placement <0|1>"); return Plugin_Handled; }	
	
	new String:value[1]
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
			ShowActivity2(client, PLUGIN_SHORTNAME, "Automatic placement of spawned infected has been enabled.");
		} else {
			ShowActivity2(client, PLUGIN_SHORTNAME, "Automatic placement of spawned infected has been disabled.");
		}
	}
	LogAction(client, -1, "[%s]\"%L\" has set %s to %i", PLUGIN_SHORTNAME, client, command, value);	
}

public Action:Command_StartKillBeastBuffet(client, args) {
	StartKillBeastBuffet(client)
	return Plugin_Handled;
}

StartKillBeastBuffet(client) {
	new String:command[] = "a4d_kill_beast_buffet_in_progress";
	StripAndChangeServerConVarBool(command, true)
	KillBeastBuffetWaveTimer = CreateTimer(GetConVarFloat(KillBeastBuffetInterval), Command_GenerateKillBeastWave, false, TIMER_REPEAT)
	KillBeastBuffetAdmin = client
	KillBeastBuffetWave = 1
	Command_GenerateKillBeastWave(KillBeastBuffetWaveTimer)
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_SHORTNAME, "It is all you can eat time at the Kill Beast Buffet."); }
	LogAction(client, -1, "\"%L\" has executed %s", client, command);
}	

public Action:Command_GenerateKillBeastWave(Handle:timer) {
	new String:command[] = "z_spawn";
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "tank", "auto", "")
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "hunter", "auto", "")
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "hunter", "auto", "")
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "hunter", "auto", "")
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "boomer", "auto", "")
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "boomer", "auto", "")
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "boomer", "auto", "")
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "smoker", "auto", "")
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "smoker", "auto", "")
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "smoker", "auto", "")
	StripAndExecuteClientCommand(KillBeastBuffetAdmin, command, "mob", "auto", "")
	KillBeastBuffetWave = KillBeastBuffetWave + 1
	LogAction(KillBeastBuffetAdmin, -1, "[%s] Wave %d of the Kill Beast Buffet has been spawned.", PLUGIN_SHORTNAME, KillBeastBuffetWave);
	if (GetConVarInt(KillBeastBuffetMaxWaves) == KillBeastBuffetWave) {
		LogAction(KillBeastBuffetAdmin, -1, "[%s] The maximium number of waves for the Kill Beast Buffet has been reached.", PLUGIN_SHORTNAME)
		if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(KillBeastBuffetAdmin, PLUGIN_SHORTNAME, "It is closing time at the Kill Beast Buffet."); }		
		return Plugin_Stop
	} 
	return Plugin_Continue
}

public Action:Command_StopKillBeastBuffet(client, args) {
	StopKillBeastBuffet(client)
	return Plugin_Handled;
}

StopKillBeastBuffet(client) {
	new String:command[] = "a4d_kill_beast_buffet_in_progress";
	StripAndChangeServerConVarBool(command, false)
	KillTimer(KillBeastBuffetWaveTimer)
	if (GetConVarBool(NotifyPlayers) == true) { ShowActivity2(client, PLUGIN_SHORTNAME, "It is closing time at the Kill Beast Buffet."); }
	LogAction(client, -1, "\"%L\" has executed %s", client, command)
}

/* Menu Functions */
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
	dc = AddToTopMenu(AdminMenu, "a4d_show_director_commands", TopMenuObject_Item, Menu_TopItemHandler, afd_commands, "a4d_show_director_commands", ADMFLAG_CHEATS);
	/*	
	sc = AddToTopMenu(AdminMenu, "a4d_show_spawn_commands", TopMenuObject_Item, ShowSpawnMenu, afd_commands, "a4d_show_spawn_commands", ADMFLAG_CHEATS);
	*/
}

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

public Menu_TopItemHandler(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, client, String:buffer[], maxlength)
{
	/* When an item is displayed to a player tell the menu to format the item */
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == dc) {
			Format(buffer, maxlength, "Director Commands");
		} else if (object_id == sc) {
			Format(buffer, maxlength, "Spawn Commands");

		}
	}
	
	/* When an item is selected do the following */
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == dc) {
			Menu_Director(client, false)
		} else if (object_id == sc) {
			Menu_Spawn(client, false)
		} 
	}
}

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
	AddMenuItem(menu, "es", "Emergency Reset")	
	SetMenuExitBackButton(menu, true);	
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
			} case 7: {
				EmergencyReset(cindex)
			}
		}
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu)
	}
}

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
	if (GetConVarBool(KillBeastBuffetInProgress)) { AddMenuItem(menu, "kb", "Stop the Kill Beast Buffet"); } else { AddMenuItem(menu, "kb", "Summon the Kill Beast Buffet"); }		
	SetMenuExitBackButton(menu, true);	
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
			} case 7: {
				if (GetConVarBool(KillBeastBuffetInProgress)) { 
					StopKillBeastBuffet(cindex) 
				} else {
					StartKillBeastBuffet(cindex) 
				}
			}
		}
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu)
	}
}

/* Helper Functions */
/* This function strips the cheat flags from a command, executes it and then restores it to its former glory. */
StripAndExecuteServerCommand(String:command[], String:arg[]) {
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	ServerCommand("%s %s", command, arg)
	SetCommandFlags(command, flags);
}

StripAndChangeServerConVarBool(String:command[], bool:value) {
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	SetConVarBool(FindConVar(command), value, false, false);
	SetCommandFlags(command, flags);
}

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

