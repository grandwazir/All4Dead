All4Dead: Control the AI director
====================================

All4Dead is a plugin for the Left4Dead wrapper [SourceMod](http://sourcemod.net/) that allows adminstrators and other trusted users to spawn infected, zombie hordes and additional items. The basic idea is allow players to control the director and spawn items without having to turn sv_chats on.

## Features

- Menu driven interface
- Force the director to spawn a tank
- Force the director to spawn a witch
- Force the director to trigger a panic event
- Force the director to keep triggering panic events until you tell it to stop
- Delay the rescue vehicle indefinitely
- Add more zombies to the horde
- Spawn any infected you like
- Spawn any weapon you like
- Spawn any item you like
- Enable all bot teams
- Use the old versus boss spawning logic (and ensure consistency of boss spawns between teams)

## License

All4Dead is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

All4Dead is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

## Documentation

If you are a server administrator, many of the features specific to BanHammer are documented [on the wiki](https://github.com/grandwazir/BanHammer/wiki). If you are looking to change the messages used in BanHammer or localise the plugin into your own language you will want to look at [this page](https://github.com/grandwazir/BukkitUtilities/wiki/Localisation) instead.

If you are a developer you may find the [JavaDocs](http://grandwazir.github.com/BanHammer/apidocs/index.html) and a [Maven website](http://grandwazir.github.com/BanHammer/) useful to you as well.

## Installation

Before installing, you need to make sure you are running at least the [latest version](http://www.sourcemod.net/downloads.php) of SourceMod. Support is only given for problems when using the most recent build. This does not mean that the plugin will not work on other versions, the likelihood is it will, but it is not supported.

### Getting the latest version

The best way to install All4Dead is to download it from the GitHub repository. A [feature changelog](https://github.com/grandwazir/All4Dead/wiki/changelog) is also available.

### Getting older versions

Alternatively [older versions](http://repository.james.richardson.name/releases/name/richardson/james/bukkit/ban-hammer/) are available as well, however they are not supported. If you are forced to use an older version for whatever reason, please let me know why by [opening a issue](https://github.com/grandwazir/BanHammer/issues/new) on GitHub.

### Building from source

You can also build All4Dead from the source if you would prefer to do so. This is useful for those who wish to modify All4Dead before using it. If you wish to do this you will need a copy of the SourcePawn compiler. For later versions you will also require a copy of [SDKHooks](http://forums.alliedmods.net/showthread.php?t=106748) extension.

## Reporting issues

If you want to make a bug report or feature request please do so using the [issue tracking](https://github.com/grandwazir/All4Dead/issues) on GitHub.

