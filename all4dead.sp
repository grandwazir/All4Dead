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

// All4Dead - A modification for the game Left4Dead.
// Copyright 2009 James Richardson.
// The full changelog can be found with the thread.

// Include frameworks.
#include <sourcemod>
#undef REQUIRE_PLUGIN // The following includes are optional.
#include <adminmenu>
// Define plugin constants.
#define FLAG_REQUIRED		ADMFLAG_CHEATS // The flag required to run any All4Dead commands.
#define PLUGIN_TAG  	  	"[A4D]" // The tag that is placed before all console and chat messages.
#define PLUGIN_VERSION		"1.5.0" // The current version of the plugin.

// Define ConVar handles.

new Handle:developer_mode = INVALID_HANDLE;
new Handle:logging_mode = INVALID_HANDLE;

// Create handles for the menu objects.
new Handle:AdminMenu = INVALID_HANDLE;
new TopMenuObject:cc = INVALID_TOPMENUOBJECT;
new TopMenuObject:dc = INVALID_TOPMENUOBJECT;
new TopMenuObject:si = INVALID_TOPMENUOBJECT;
new TopMenuObject:sm = INVALID_TOPMENUOBJECT;
new TopMenuObject:sw = INVALID_TOPMENUOBJECT;

// Create fake client id.
new fake_command_client = 0

// All4Dead metadata.
public Plugin:myinfo = {
	name = "All4Dead",
	author = "James Richardson (grandwazir)",
	description = "Enables admins to have control over the AI Director",
	version = PLUGIN_VERSION,
	url = "www.grandwazir.com"
};

// When the plugin is started, register all our commands and ConVars.
public OnPluginStart() {
	// Register plugin specfic ConVars and set default values.
	CreateConVar("a4d_version", PLUGIN_VERSION, "The version of All4Dead plugin.", FCVAR_PLUGIN);
	developer_mode = CreateConVar("a4d_developer_mode", "1", "Whether or not developer mode is enabled.", FCVAR_PLUGIN);
	logging_mode = CreateConVar("a4d_logging_mode", "3", "The level.", FCVAR_PLUGIN);		
	PlayerNotifications = CreateConVar("a4d_player_notifications", "1", "Whether or not we announce actions in game.", FCVAR_PLUGIN);
	// Register all director related commands
	RegAdminCmd("a4d_delay_rescue", Command_DelayRescue, FLAG_REQUIRED);
	RegAdminCmd("a4d_force_panic", Command_ForcePanic, FLAG_REQUIRED);
	RegAdminCmd("a4d_force_tank", Command_ForceTank, FLAG_REQUIRED);
	RegAdminCmd("a4d_force_witch", Command_ForceWitch, FLAG_REQUIRED);
	RegAdminCmd("a4d_panic_forever", Command_PanicForever, FLAG_REQUIRED);
	// Register all spawning related commands
	RegAdminCmd("a4d_enable_auto_placement", Command_AutoPlacement, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_spawn_infected", Command_SpawnInfected, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_spawn_item", Command_SpawnItem, ADMFLAG_CHEATS);
	RegAdminCmd("a4d_spawn_weapon", Command_SpawnWeapon, ADMFLAG_CHEATS);
	// Create fake command client
	fake_command_client = CreateFakeClient("A4D Command Bot");
	if (GetConVarInt(logging_mode) < 2) { LogAction(0, -1, "[DEBUG]: OnPluginStart called."); }
}

// This seems to be called straight after plugin load and when a map change occurs.
public OnConfigsExecuted() {
	if (GetConVarInt(logging_mode) < 2) { LogAction(0, -1, "[DEBUG]: Configuation file plugin.all4dead.cfg has been executed."); }
}

// When the plugin unloads make sure we clean up after ourselves.
public OnPluginEnd() {
	if (GetConVarInt(logging_mode) < 2) { LogAction(0, -1, "[DEBUG]: Plugin has been unloaded."); }
}



// Commands

// Force the AI Director to delay the rescue vehicle indefinitely
// This means that the end wave essentially never stops. The director makes sure that one tank is always alive at all times during the last wave. 
// Disabling this once the survivors have reached the last wave of the finale seems to have no effect (can anyone test this to be sure?)
public Action:Command_DelayRescue(client, args) {
	// Make sure we have been given some arguments	
	if (args < 1) { 
		ReplyToCommand(client, "%s Usage: a4d_delay_rescue <0|1>", PLUGIN_TAG); 
		return Plugin_Handled; 
	} 	
	new String:arg[2]
	GetCmdArg(1, arg, sizeof(arg))
	if (StrEqual(value, "0") || StrEqual(value, "1")) {
		DelayRescue(client, value)		
	} else {
		ReplyToCommand(client, "%s Usage: a4d_delay_rescue <0|1>", PLUGIN_TAG); 
	}
	return Plugin_Handled;
}

DelayRescue(client, value) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_delay_rescue(%s)", client, value); }
	StripAndChangeServerConVar("director_finale_infinite", value, client) 	
	if (StrEqual(value, "1")) {
		Feedback(client, "The rescue vehicle has been delayed indefinitely.");
	} else {
		Feedback(client, "The rescue vehicle is on its way.");
	}	
}

/* Force the AI director to trigger a panic event */
/* There does seem to be a cooldown on this command and it is very noisy. If you just want to spawn more zombies, use spawn mob instead */
public Action:Command_ForcePanic(client, args) {
	ForcePanic(client)
	return Plugin_Handled;
}

ForcePanic(client) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_force_panic(%s)", client, value); }
	StripAndExecuteFakeClientCommand(client, "director_force_panic_event")
	Feedback(client, "A panic event has been started.")
}

// This command forces the AI Director to spawn a tank this round. The admin doesn't have control over where it spawns or when. 
// I am not certain but pretty confident that if a tank has already been spawned this won't force the director to spawn another.
public Action:Command_ForceTank(client, args) {
	if (args < 1) { 
		ReplyToCommand(client, "%s Usage: a4d_force_tank <0|1>", PLUGIN_TAG); 
		return Plugin_Handled; 
	}	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))
	if (StrEqual(value, "0") || StrEqual(value, "1")) {
		ForceTank(client, value)		
	} else {
		ReplyToCommand(client, "%s Usage: a4d_force_tank <0|1>", PLUGIN_TAG); 
	}
	return Plugin_Handled;
}

ForceTank(client, value) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_force_tank(%s)", client, value); }
	StripAndChangeServerConVar("director_force_tank", value, client) 	
	if (StrEqual(value, "1")) {
		Feedback(client, "A tank is guaranteed to spawn this round");
	} else {
		Feedback(client, "A tank is no longer guaranteed to spawn this round");
	}	
}

// Force the AI Director to spawn a witch somewhere in the players path this round. The admin doesn't have control over where it spawns or when.
// I am not certain but pretty confident that if a witch has already been spawned this won't force the director to spawn another.
public Action:Command_ForceWitch(client, args) {
	if (args < 1) { 
		ReplyToCommand(client, "%s Usage: a4d_force_witch <0|1>", PLUGIN_TAG); 
		return Plugin_Handled; 
	}	
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))
	if (StrEqual(value, "0") || StrEqual(value, "1")) {
		ForceWitch(client, value)		
	} else {
		ReplyToCommand(client, "%s Usage: a4d_force_witch <0|1>", PLUGIN_TAG); 
	}
	return Plugin_Handled;
}

ForceWitch(client, value) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_force_witch(%s)", client, value); }
	StripAndChangeServerConVar("director_force_witch", value, client) 	
	if (StrEqual(value, "1")) {
		Feedback(client, "A witch is guaranteed to spawn this round");
	} else {
		Feedback(client, "A witch is no longer guaranteed to spawn this round");
	}	
}

/* Force the AI Director to start panic events constantly, one after each another, until asked politely to stop. */
/* It won't start working until a panic event has been triggered. If you want it to start doing this straight away trigger a panic event. */
public Action:Command_PanicForever(client, args) {
	if (args < 1) { 
		ReplyToCommand(client, "%s Usage: a4d_panic_forever <0|1>", PLUGIN_TAG); 
		return Plugin_Handled; 
	}
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))
	if (StrEqual(value, "0") || StrEqual(value, "1")) {
		PanicForever(client, value)		
	} else {
		ReplyToCommand(client, "%s Usage: a4d_panic_forever <0|1>", PLUGIN_TAG); 
	}
	return Plugin_Handled;
}

PanicForever(client, String:value[]) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_panic_forever(%s)", client, value); }	
	StripAndChangeServerConVar("director_panic_forever", value)	
	if (StrEqual(value, "1")) {
		Feedback(client, "Endless panic events have started.");
	} else {
		Feedback(client, "Endless panic events have ended.");
	}
}

// Spawn Commands

// This toggles whether or not we want the director to automatically place the things we spawn
// The director will place mobs outside the players sight so it will not look like they are magically appearing
public Action:Command_AutoPlacement(client, args) {
	if (args < 1) { 
		ReplyToCommand(client, "%s Usage: a4d_auto_placement <0|1>", PLUGIN_TAG); 
		return Plugin_Handled; 
	}
	new String:value[2]
	GetCmdArg(1, value, sizeof(value))
	if (StrEqual(value, "0") || StrEqual(value, "1")) {
		AutoPlacement(client, value)		
	} else {
		ReplyToCommand(client, "%s Usage: a4d_auto_placement <0|1>", PLUGIN_TAG); 
	}
	return Plugin_Handled;
}

AutoPlacement(client, value) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_auto_placement(%s)", client, value); }	
	StripAndChangeServerConVar("a4d_automatic_placement", value)
	if (StrEqual(value, "1")) {
		Feedback(client, "Automatic placement of spawned infected has been enabled.");
	} else {
		Feedback(client, "Automatic placement of spawned infected has been disabled.");
	}	
}

// This menu deals with all commands related to spawning creatures
public Action:Menu_SpawnInfected(client, args) {
	new Handle:menu = CreateMenu(MenuHandler_SpawnInfected)
	// Set the menu title
	SetMenuTitle(menu, "Spawn Infected")
	// Add menu options
	AddMenuItem(menu, "st", "Spawn a tank")
	AddMenuItem(menu, "sw", "Spawn a witch")
	AddMenuItem(menu, "sb", "Spawn a boomer")
	AddMenuItem(menu, "sh", "Spawn a hunter")
	AddMenuItem(menu, "ss", "Spawn a smoker")
	AddMenuItem(menu, "sm", "Spawn a mob")
	if (GetConVarBool(FindConVar("a4d_automatic_placement"))) { AddMenuItem(menu, "ap", "Disable automatic placement"); } else { AddMenuItem(menu, "ap", "Enable automatic placement"); }
	// Make sure there is an exit option	
	SetMenuExitButton(menu, true)
	// Display the menu for 20 seconds
	DisplayMenu(menu, client, 20)
	return Plugin_Handled
}

public MenuHandler_SpawnInfected(Handle:menu, MenuAction:action, cindex, itempos) {
	if (action == MenuAction_Select) {
		switch (itempos) {
			case 0: {
				SpawnInfected(cindex, "tank")
			} case 1: {
				SpawnInfected(cindex, "witch")
			} case 2: {
				SpawnInfected(cindex, "boomer")
			} case 3: {
				SpawnInfected(cindex, "hunter")
			} case 4: {
				SpawnInfected(cindex, "smoker")
			} case 5: {
				SpawnInfected(cindex, "mob")
			} case 6: { 
				if (GetConVarBool(FindConVar("a4d_automatic_placement"))) { 
					AutoPlacement(cindex, "0") 
				} else {
					AutoPlacement(cindex, "1") 
				}
			}
		}
		Menu_SpawnInfected(cindex, false)
	}
	// If the menu has ended, destroy it
	else if (action == MenuAction_End) {
		CloseHandle(menu)
	}
}

// Spawn an infected of your choice.
// If a4d_automatic_placement is off the creature will spawn at the clients crosshair.
public Action:Command_SpawnInfected(client, args) {
	if (client == 0 && !GetConVarBool(FindConVar("a4d_automatic_placement"))) {
		if (GetConVarInt(logging_mode) <= 0) { LogAction(client, -1, "[ERROR]: a4d_spawn_infected can not be used remotely unless a4d_automatic_placement is true!"); }
		ReplyToCommand(client, "%s Usage: a4d_spawn_infected can not be used remotely unless a4d_automatic_placement is true")
		return Plugin_Handled; 
	} else if (args < 1) { 
		ReplyToCommand(client, "%s Usage: a4d_spawn_infected <tank|witch|boomer|hunter|smoker|common|mob>", PLUGIN_TAG); 
		return Plugin_Handled;
	}
	new String:value[16]
	GetCmdArg(1, value, sizeof(value))
	if (StrEqual(value, "tank") || StrEqual(value, "witch") || StrEqual(value, "boomer") || StrEqual(value, "hunter") || StrEqual(value, "smoker") || StrEqual(value, "common") || StrEqual(value, "mob")) {
		SpawnInfected(client, value)		
	} else {
		ReplyToCommand(client, "%s Usage: a4d_spawn_infected <tank|witch|boomer|hunter|smoker|common|mob>", PLUGIN_TAG); 
	}
	return Plugin_Handled;
}

SpawnInfected(client, String:value[]) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_spawn_infected(%s)", client, value); }	
	// If automatic placement is on then append that to the command	
	new String:command[32] = "z_spawn "	
	new String:param[32] = value
	if (GetConVarBool(FindConVar("a4d_automatic_placement"))) { StrCat(param, sizeof(param), " auto"); }	
	StrCat(command, sizeof(command), value)	
	StripAndExecuteFakeClientCommand(client, command)
	Feedback(client, "A %s has been spawned")
}

// This menu deals with spawning items in the game world
public Action:Menu_SpawnItems(client, args) {
	new Handle:menu = CreateMenu(MenuHandler_SpawnItems)
	// Set the menu title
	SetMenuTitle(menu, "Spawn Items")
	// Add menu options
	AddMenuItem(menu, "sg", "Spawn a gas tank")
	AddMenuItem(menu, "sm", "Spawn a medkit")
	AddMenuItem(menu, "sv", "Spawn a molotov")
	AddMenuItem(menu, "sp", "Spawn some pills")
	AddMenuItem(menu, "sb", "Spawn a pipe bomb")	
	AddMenuItem(menu, "st", "Spawn a propane tank")}
	// Make sure there is an exit option	
	SetMenuExitButton(menu, true)
	// Display the menu for 20 seconds
	DisplayMenu(menu, client, 20)
	return Plugin_Handled
}

public MenuHandler_SpawnItems(Handle:menu, MenuAction:action, cindex, itempos) {
	if (action == MenuAction_Select) {
		switch (itempos) {
			case 0: {
				SpawnItem(cindex, "gascan")
			} case 1: {
				SpawnItem(cindex, "first_aid_kit")
			} case 2: {
				SpawnItem(cindex, "molotov")
			} case 3: {
				SpawnItem(cindex, "pain_pills")
			} case 4: {
				SpawnItem(cindex, "pipe_bomb")
			} case 5: {
				SpawnItem(cindex, "propanetank")
			} 
		}
		Menu_SpawnItems(cindex, false)
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End) {
		CloseHandle(menu)
	}
}

// Spawn an item of your choice.
// This command can not be used remotely
public Action:Command_SpawnItem(client, args) {
	if (client == 0) {
		if (GetConVarInt(logging_mode) <= 0) { LogAction(client, -1, "[ERROR]: a4d_spawn_item can not be be used remotely!"); }
		ReplyToCommand(client, "%s Usage: a4d_spawn_item can not be used remotely")
		return Plugin_Handled; 
	} else if (args < 1) { 
		ReplyToCommand(client, "%s Usage: a4d_spawn_item <first_aid_kit|gastank|molotov|pain_pills|pipe_bomb|propanetank>", PLUGIN_TAG); 
		return Plugin_Handled;
	}
	new String:value[16]
	GetCmdArg(1, value, sizeof(value))
	if (StrEqual(value, "first_aid_kit") || StrEqual(value, "gastank") || StrEqual(value, "molotov") || StrEqual(value, "pain_pills") || StrEqual(value, "pipe_bomb") || StrEqual(value, "propanetank")) {
		SpawnItem(client, value)		
	} else {
		ReplyToCommand(client, "%s Usage: a4d_spawn_item <first_aid_kit|gastank|molotov|pain_pills|pipe_bomb|propanetank>", PLUGIN_TAG); 
	}
	return Plugin_Handled;
}

SpawnItem(client, String:value[]) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_spawn_item(%s)", client, value); }	
	// If automatic placement is on then append that to the command	
	new String:command[32] = "give "	
	StrCat(command, sizeof(command), value)	
	StripAndExecuteFakeClientCommand(client, command)
	Feedback(client, "A %s has been spawned")
}

// This menu deals with spawning weapons in the game world
public Action:Menu_SpawnWeapons(client, args) {
	new Handle:menu = CreateMenu(MenuHandler_SpawnWeapons)
	// Set the menu title
	SetMenuTitle(menu, "Spawn Weapons")
	// Add menu options
	AddMenuItem(menu, "sa", "Spawn an auto shotgun")
	AddMenuItem(menu, "sh", "Spawn a hunting rifle")
	AddMenuItem(menu, "sp", "Spawn a pistol")	
	AddMenuItem(menu, "sr", "Spawn a rifle")
	AddMenuItem(menu, "ss", "Spawn a shotgun")
	AddMenuItem(menu, "sm", "Spawn a sub machine gun")
	// Make sure there is an exit option	
	SetMenuExitButton(menu, true)
	// Display the menu for 20 seconds
	DisplayMenu(menu, client, 20)
	return Plugin_Handled
}

public MenuHandler_SpawnWeapons(Handle:menu, MenuAction:action, cindex, itempos) {
	if (action == MenuAction_Select) {
		switch (itempos) {
			case 0: {
				SpawnItem(cindex, "autoshotgun")
			} case 1: {
				SpawnItem(cindex, "hunting_rifle")
			} case 2: {
				SpawnItem(cindex, "pistol")
			} case 3: {
				SpawnItem(cindex, "rifle")
			} case 4: {
				SpawnItem(cindex, "pumpshotgun")
			} case 5: {
				SpawnItem(cindex, "smg")
			} 
		}
		Menu_SpawnWeapons(cindex, false)
	}
	// If the menu has ended, destroy it
	else if (action == MenuAction_End) {
		CloseHandle(menu)
	}
}

// Spawn a weapon of your choice.
// This command can not be used remotely
public Action:Command_SpawnWeapon(client, args) {
	if (client == 0) {
		if (GetConVarInt(logging_mode) <= 0) { LogAction(client, -1, "[ERROR]: a4d_spawn_weapon can not be be used remotely!"); }		
		ReplyToCommand(client, "%s Usage: a4d_spawn_weapon can not be used remotely")				
		return Plugin_Handled; 
	} else if (args < 1) { 
		ReplyToCommand(client, "%s Usage: a4d_spawn_weapon <autoshotgun|pistol|hunting_rifle|rifle|pumpshotgun|smg>", PLUGIN_TAG); 
		return Plugin_Handled;
	}
	new String:value[16]
	GetCmdArg(1, value, sizeof(value))
	if (StrEqual(value, "autoshotgun") || StrEqual(value, "pistol") || StrEqual(value, "hunting_rifle") || StrEqual(value, "rifle") || StrEqual(value, "pumpshotgun") || StrEqual(value, "smg")) {
		SpawnWeapon(client, value)		
	} else {
		ReplyToCommand(client, "%s Usage: a4d_spawn_weapon <autoshotgun|pistol|hunting_rifle|rifle|pumpshotgun|smg>", PLUGIN_TAG); 
	}
	return Plugin_Handled;
}

SpawnWeapon(client, String:value[]) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_spawn_weapon(%s)", client, value); }	
	// If automatic placement is on then append that to the command	
	new String:command[32] = "give "	
	StrCat(command, sizeof(command), value)	
	StripAndExecuteFakeClientCommand(client, command)
	Feedback(client, "A %s has been spawned")
}

// Configuration Commands

// Create the menu to access the all the configuration commands
public Action:Menu_Config(client, args) {
	new Handle:menu = CreateMenu(MenuHandler_Config)
	// Set the menu title
	SetMenuTitle(menu, "Configuration Commands")
	// Add menu options
	if (GetConVarBool(FindConVar("a4d_notify_players"))) { AddMenuItem(menu, "pn", "Disable player notifications"); } else { AddMenuItem(menu, "pn", "Enable player notifications"); }
	AddMenuItem(menu, "rs", "Restore all settings to game defaults now")
	// Make sure there is an exit option	
	SetMenuExitButton(menu, true)
	// Display the menu for 20 seconds
	DisplayMenu(menu, client, 20)
	return Plugin_Handled
}

public MenuHandler_Config(Handle:menu, MenuAction:action, cindex, itempos) {
	// If a player has selected something on the menu find out what they chose
	if (action == MenuAction_Select) {
		switch (itempos) {
			case 0: {
				if (GetConVarBool(FindConVar("a4d_notify_players"))) { 
					EnableNotifications(cindex, "0") 
				} else {
					EnableNotifications(cindex, "1") 
				} 
			} case 1: {
				ResetToDefaults(cindex)
			}
		}
		Menu_Config(cindex, false)
	}
	// If the menu has ended, destroy it
	else if (action == MenuAction_End) {
		CloseHandle(menu)
	}
}

// Toggle player notifications using ShowActivity2 through the Feedback function
// Logging is always on can not be disabled
public Action:Command_EnableNotifications(client, args) {
	if (args < 1) { 
		ReplyToCommand(client, "%s Usage: Usage: a4d_enable_notifications <0|1>", PLUGIN_TAG); 
		return Plugin_Handled; 
	}	
	new String:arg[2]
	GetCmdArg(1, arg, sizeof(arg))
	if (StrEqual(value, "0") || StrEqual(value, "1")) {
		EnableNotifications(client, value)		
	} else {
		ReplyToCommand(client, "%s Usage: a4d_enable_notifications <0|1>", PLUGIN_TAG); 
	}
	return Plugin_Handled;
}

EnableNotifications(client, value) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_enable_notifications(%s)", client, value); }
	StripAndChangeServerConVar("a4d_notify_players", value, client) 	
	if (StrEqual(value, "1")) {
		Feedback(client, "Player notifications have been enabled.");
	} else {
		Feedback(client, "Player notifications have been disabled.");
	}
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: (%L) set %s to %i", client, "a4d_notify_players", value); }	
}

// Resets all ConVars to their default settings
// Should be used if you screwed something up or at the beginning of every map to have a normal game
public Action:Command_ResetToDefaults(client, args) {
	ResetToDefaults(client)
	return Plugin_Handled;
}

ResetToDefaults(client) {
	if (GetConVarInt(logging_mode) < 1) { LogAction(client, -1, "[NOTICE]: \"%L\" executed command a4d_reset_to_defaults", client); }
	// Reset configuration settings
	EnableNotifications(client, "1")	
	// Reset director settings
	ForceTank(client, "0")
	ForceWitch(client, "0")
	PanicForever(client, "0")
	DelayRescue(client, "0")
}


// Helper Commands

// Strips and executes a fake client command.
StripAndExecuteFakeClientCommand(client, String:command[]) {
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(fake_command_client, command)
	SetCommandFlags(command, flags);
	if (GetConVarInt(logging_mode) < 2) { LogAction(client, runas, "[DEBUG]: \"%L\" executed fake client command %s as \"%L\"", command, runas); }
}
StripAndChangeServerConVar(String:convar, value, client) {
	new flags = GetCommandFlags(convar);
	SetCommandFlags(convar, flags & ~FCVAR_CHEAT);
	SetConVarString(FindConVar(command), value, false, false);
	SetCommandFlags(convar, flags);
	if (GetConVarInt(logging_mode) < 2) { LogAction(client, -1, "[DEBUG]: \"%L\" set %s to %s", client, convar, value); }
}
	
// This plugin provides feedback to all players.
Feedback(client, String:message[]) {
	if (GetConVarBool(NotifyPlayers)) {
		ShowActivity2(client, PLUGIN_TAG, message)
	}
}	
