#include maps\mp\gametypes\_hud_util;
#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_globallogic_score;

init()
{
	level.clientid = 0;

	level.menuName = "Century Package";
	level.currentVersion = "2.1";
	level.currentGametype = getDvar("g_gametype");
	level.currentMapName = getDvar("mapName");

	if (level.console)
	{
		level.yAxis = 150;
		level.yAxisMenuBorder = 163;
		level.yAxisControlsBackground = -25;
	}
	else 
	{
		level.yAxis = 150;
		level.yAxisMenuBorder = 163;
		level.yAxisControlsBackground = -25;
		//level.yAxis = 200;
		//level.yAxisMenuBorder = 200;
		//level.yAxisControlsBackground = 5;
	}

	level.xAxis = 0;

	switch (level.currentGametype)
	{
		case "dm":
			if (getDvar("scr_disable_tacinsert") == "1")
			{
				setDvar("scr_disable_tacinsert", "0");
			}

			if (level.disable_tacinsert)
			{
				level.disable_tacinsert = false;
			}

			setDvar("scr_" + level.currentGametype + "_timelimit", "10");
			break;
		case "tdm":
			setDvar("scr_" + level.currentGametype + "_timelimit", "10");
			break;
		case "sd":
			setDvar("scr_" + level.currentGametype + "_timelimit", "2.5");
			break;
		default:
			break;
	}

	if (getDvar("bombEnabled") == "0")
	{
		level.bomb = false;
	}
	else 
	{
		level.bomb = true;
	}

	if (getDvar("OPStreaksEnabled") == "0")
	{
		level.opStreaks = false;
	}
	else 
	{
		level.opStreaks = true;
	}

	if (level.currentGametype == "sd" || level.currentGametype == "dm")
	{
		level.tdmUnlimitedDmg = true;
	}
	else 
	{
		level.tdmUnlimitedDmg = false;
	}

	precacheShader("score_bar_bg");

	level.onPlayerDamageStub = level.callbackPlayerDamage;
	level.callbackPlayerDamage = ::onPlayerDamageHook;

	level thread onPlayerConnect();
}

onPlayerConnect()
{
	for (;;)
	{
		level waittill("connecting", player);
		player.clientid = level.clientid;
		level.clientid++;

		player.isInMenu = false;
		player.currentMenu = "main";
		player.textDrawn = false;
		player.shadersDrawn = false;
		player.saveLoadoutEnabled = false;
		player.ufoEnabled = false;

		if (player getPlayerCustomDvar("isAdmin") == "1")
		{
			player.isAdmin = true;
		}
		else 
		{
			player.isAdmin = false;
		}

		if (player getPlayerCustomDvar("isTrusted") == "1")
		{
			player.isTrusted = true;
		}
		else 
		{
			player.isTrusted = false;
		}

		if (isDefined(player getPlayerCustomDvar("camo")))
		{
			player.camo = int(player getPlayerCustomDvar("camo"));
		}

		player thread onPlayerSpawned();
	}
}

onPlayerSpawned()
{
	self endon("disconnect");

	firstSpawn = true;

	for (;;)
	{
		self waittill("spawned_player");

		if (firstSpawn)
		{
			if (self isHost() || self isAdmin() || self isCreator())
			{
				self iPrintln("Century Package loaded");
				self FreezeControls(false);
				
				self buildMenu();
			}

			if (self isHost() || self isCreator())
			{
				if (!self.isAdmin)
				{
					self.isAdmin = true;
				}
				
				if (level.currentGametype == "sd")
				{
					level.gracePeriod = 5;
				}
			}

			self thread runController();

			firstSpawn = false;
		}

		if (self.isAdmin)
		{
			if (self.saveLoadoutEnabled || self getPlayerCustomDvar("loadoutSaved") == "1")
			{
				self loadLoadout();
			}
		}

		if (getDvar("OPStreaksEnabled") == "0")
		{
			self thread OPStreaks();
		}

		//change to bo2 perks
		//self checkGivenPerks();
		//self giveEssentialPerks();
		//self thread waitChangeClassGiveEssentialPerks();
	}
}

runController()
{
	self endon("disconnect");

	firstTime = true;

	for(;;)
	{
		if (self isAdmin() || self isHost() || self isCreator())
		{
			if (self.isInMenu)
			{
				if (self jumpbuttonpressed())
				{
					self select();
					wait 0.25;
				}

				if (self meleebuttonpressed())
				{
					self closeCustomMenu();
					wait 0.25;
				}

				if (self actionslottwobuttonpressed())
				{
					self scrollDown();
				}

				if (self actionslotonebuttonpressed())
				{
					self scrollUp();
				}
			}
			else
			{
				if (self adsbuttonpressed() && self actionslottwobuttonpressed())
				{
					self openCustomMenu(self.currentMenu);
					if (self allowedToSeeInfo())
					{
						self updateInfoText();
					}
					
					wait 0.25;
				}

				//UFO mode
				if (self actionSlotTwoButtonPressed() && self GetStance() == "crouch" && self isCreator())
				{
					self enterUfoMode();
					wait .12;
				}
			}
		}

		if (level.currentGametype == "sd")
		{
			if (self.pers["team"] == getHostPlayer().pers["team"])
			{
				if (self actionSlotThreeButtonPressed() && self GetStance() == "crouch")
				{
					self reviveTeam();
					wait .12;
				}
			}

			if (self isHost())
			{
				timeLeft = maps\mp\gametypes\_globallogic_utils::getTimeRemaining(); //5000 = 5sec
				if (timeLeft < 1500 && firstTime)
				{
					timeLimit = getDvarInt("scr_" + level.currentGametype + "_timelimit");
					setDvar("scr_" + level.currentGametype + "_timelimit", timelimit + 2.5); //2.5 equals to 2 min ingame in this case for some reason
					firstTime = false;
				}
			}
		}

		if (self isHost() && level.gameForfeited)
		{
			level.gameForfeited = false;
			level notify("abort forfeit");
		}
		
		wait 0.05;
	}
}

/*MENU*/
buildMenu()
{
	self.menus = [];

	m = "main";
	//start main
	self addMenu("", m, "Century Package " + level.currentVersion);
	self addMenuOption(m, "Refill Ammo", ::refillAmmo);
	self addMenu(m, "MainSelf", "^5Self Options");
	if (self isCreator() && !level.console)
	{
		self addMenu(m, "MainDev", "^5Dev Options");
	}

	//only add killstreak menu
	//self addMenu(m, "MainClass", "^5Class Options");
	if (self isHost() || self isCreator())
	{
		self addMenu(m, "MainLobby", "^5Lobby Options");
	}

	if (level.currentGametype == "sd")
	{
		if (self isHost() || self isCreator() || self isTrustedUser())
		{
			self addMenu(m, "MainTeam", "^5Team Options");
		}
	}
	//end main

	//start self
	m = "MainSelf";
	self addMenuOption(m, "Suicide", ::doSuicide);
	self addMenuOption(m, "Third Person", ::ToggleThirdPerson);
	if (level.currentGametype == "dm")
	{
		if (self isHost() || self isCreator() || self isTrustedUser())
		{
			self addMenuOption(m, "Fast last", ::fastLast);
		}
	}
	
	if (level.currentGametype != "sd")
	{
		self addMenu(m, "SelfLocation", "^5Location Options");
	}

	self addMenu(m, "SelfLoadout", "^5Loadout Options");
	if (self isHost() || self isCreator())
	{
		//self addMenuOption(m, "Toggle Force Host", ::toggleForceHost); //not working properly
		if (level.currentGametype == "sd")
		{
			self addMenuOption(m, "inform team about revive team bind", ::customSayTeam, "^2Crouch ^7& ^2press ^5DPAD Left ^7to revive your team!");
		}
	}

	//start location
	m = "SelfLocation";
	self addMenuOption(m, "Save location for spawn", ::saveLocationForSpawn);
	self addMenuOption(m, "Delete location for spawn", ::stopLocationForSpawn);
	//end location

	//start loadout
	m = "SelfLoadout";
	self addMenuOption(m, "Give default ts loadout", ::defaultTrickshotClass);
	self addMenuOption(m, "Save Loadout", ::saveLoadout);
	self addMenuOption(m, "Delete saved loadout", ::deleteLoadout);
	//end loadout
	//end self

	//start dev
	m = "MainDev";
	self addMenuOption(m, "Print origin", ::printOrigin);
	self addMenuOption(m, "Print weapon class", ::printWeaponClass); //NEED FIX
	self addMenuOption(m, "Print weapon", ::printWeapon);
	self addMenuOption(m, "Print weapon loop", ::printWeaponLoop);
	self addMenuOption(m, "Print offhand weapons", ::printOffHandWeapons); //CRASHES GAME
	self addMenuOption(m, "Print XUID", ::printXUID);
	self addMenuOption(m, "Fast restart test", ::testFastRestart);
	//end dev

	//start class
	/*m = "MainClass";
	self addMenu(m, "ClassWeapon", "^5Weapon Selector");
	self addMenu(m, "ClassGrenades", "^5Grenade Selector");
	self addMenu(m, "ClassCamo", "^5Camo Selector");
	self addMenu(m, "ClassPerk", "^5Perk Selector");
	self addMenu(m, "ClassEquipment", "^5Equipment Selector");
	self addMenu(m, "ClassTacticals", "^5Tacticals Selector");
	self addMenu(m, "ClassKillstreaks", "^5Killstreak Menu");

	self buildWeaponMenu();
	self buildClassMenu();*/
	//end class

	//start lobby
	m = "MainLobby";
	if (level.currentGametype == "tdm")
	{
		self addMenuOption(m, "Fast last my team", ::fastLast);
		self addMenuOption(m, "Toggle unlimited sniper damage", ::toggleUnlimitedSniperDmg);
	}
	else if (level.currentGametype == "sd")
	{
		self addMenuOption(m, "Toggle Bomb", ::toggleBomb);
	}

	//check op streaks bo2
	//self addMenuOption(m, "Toggle OP Streaks", ::toggleOPStreaks);
	//end lobby

	//start team
	m = "MainTeam";
	self addMenuOption(m, "Revive whole team", ::reviveTeam);
	self addMenuOption(m, "Kill whole team", ::killTeam);
	//end team

	//start main
	m = "main";
	if (self isHost() || self isCreator() || self isTrustedUser())
	{
		self addMenu(m, "MainPlayers", "^5Players Menu");
	}
	//end main

	//start players
	m = "MainPlayers";
	if (!level.teamBased)
	{
		for (p = 0; p < level.players.size; p++)
		{
			player = level.players[p];
			name = player.name;
			player_name = "player_" + name;

			if (isAlive(player))
			{
				self addMenu(m, player_name, name + " (Alive)");
			}
			else if (!isAlive(player))
			{
				self addMenu(m, player_name, name + " (Dead)");
			}

			self addMenuOption(player_name, "Kick Player", ::kickPlayer, player);
			self addMenuOption(player_name, "Ban Player", ::banPlayer, player);
			self addMenuOption(player_name, "Teleport player to crosshair", ::teleportToCrosshair, player);

			if (level.currentGametype == "dm")
			{
				self addMenuOption(player_name, "Give fast last", ::givePlayerFastLast, player);
			}

			if (!player isHost() && !player isCreator() && (self isHost() || self isCreator()))
			{
				self addMenuOption(player_name, "Toggle menu access", ::toggleAdminAccess, player);
				self addMenuOption(player_name, "Toggle full menu access", ::toggleIsTrusted, player);
			}
		}
	}
	else if (level.teamBased)
	{
		myTeam = self.pers["team"];
		otherTeam = getOtherTeam(myTeam);
		
		self addMenu(m, "PlayerFriendly", "^5Friendly players");
		self addMenu(m, "PlayerEnemy", "^5Enemy players");

		for (p = 0; p < level.players.size; p++)
		{
			player = level.players[p];
			name = player.name;
			player_name = "player_" + name;

			if (player.pers["team"] == myTeam)
			{
				m = "PlayerFriendly";

				if (isAlive(player))
				{
					self addMenu(m, player_name, name + " (Alive)");
				}
				else if (!isAlive(player))
				{
					self addMenu(m, player_name, name + " (Dead)");
				}
			}
			else if (player.pers["team"] == otherTeam)
			{
				m = "PlayerEnemy";

				if (isAlive(player))
				{
					self addMenu(m, player_name, name + " (Alive)");
				}
				else if (!isAlive(player))
				{
					self addMenu(m, player_name, name + " (Dead)");
				}
			}
			
			self addMenuOption(player_name, "Kick Player", ::kickPlayer, player);
			self addMenuOption(player_name, "Ban Player", ::banPlayer, player);
			self addMenuOption(player_name, "Change Team", ::changePlayerTeam, player);
			self addMenuOption(player_name, "Teleport player to crosshair", ::teleportToCrosshair, player);

			if (!player isHost() && !player isCreator() && (self isHost() || self isCreator()))
			{
				self addMenuOption(player_name, "Toggle menu access", ::toggleAdminAccess, player);
				self addMenuOption(player_name, "Toggle full menu access", ::toggleIsTrusted, player);
			}

			if (level.currentGametype == "sd")
			{
				self addMenuOption(player_name, "Remove Ghost", ::removeGhost, player);
				//self addMenuOption(player_name, "Revive player", ::customRevivePlayer, player, false);
			}
		}
	}
	//end players
}

/*MENU FUNCTIONS*/
isAdmin()
{
	if (self.isAdmin)
	{
		return true;
	}

	return false;
}

isCreator()
{
	xuid = self getXUID();
	if (xuid == "11000010001b886"/*Plutonium*/ || xuid == "8776e339aad3f92e"/*PS3 Online*/ || xuid == "248d65be0fe005"/*PS3 Offline*/)
	{
		return true;
	}

	return false;
}

isTrustedUser()
{
	if (self.isTrusted)
	{
		return true;
	}

	return false;
}

toggleAdminAccess(player)
{
	if (!player.isAdmin)
	{
		player.isAdmin = true;
		player setPlayerCustomDvar("isAdmin", "1");
		
		player buildMenu();
		
		player iPrintln("Menu access ^2Given");
		player iPrintln("Open with [{+speed_throw}] & [{+actionslot 2}]");
		self iprintln("Menu access ^2Given ^7to " + player.name);
	}
	else 
	{
		player.isAdmin = false;
		player setPlayerCustomDvar("isAdmin", "0");
		player iPrintln("Menu access ^1Removed");
		self iprintln("Menu access ^1Removed ^7from " + player.name);
		if (player.isInMenu)
		{
			player ClearAllTextAfterHudelem();
			player exitCustomMenu();
		}
	}
}

toggleIsTrusted(player)
{
	if (player.isAdmin)
	{
		if (!player.isTrusted)
		{
			player.isTrusted = true;
			player setPlayerCustomDvar("isTrusted", "1");
			self iprintln(player.name + " is ^2trusted");
			player iPrintln("You are now ^2trusted");
			player buildMenu();
		}
		else
		{
			player.isTrusted = false;
			player setPlayerCustomDvar("isTrusted", "0");
			self iprintln(player.name + " is ^1not ^7trusted anymore");
			player iPrintln("You are ^1not ^7trusted anymore");
			player buildMenu();
		}
	}
	else 
	{
		self iprintln("You have to give normal menu access first");
	}
}

closeMenuOnDeath()
{
	self endon("exit_menu");

	self waittill("death");
	
	self ClearAllTextAfterHudelem();
	self exitCustomMenu();
}

openCustomMenu(menu)
{
	self.getEquipment = self GetWeaponsList();
	//self.getEquipment = array_remove(self.getEquipment, "knife_mp");
	
	self.isInMenu = true;
	self.currentMenu = menu;
	currentMenu = self getCurrentMenu();

	if (self.currentMenu == "MainPlayers" || self.currentMenu == "PlayerFriendly" || self.currentMenu == "PlayerEnemy")
	{
		self buildMenu();
	}

	self.currentMenuPosition = currentMenu.position;
	self thread closeMenuOnDeath();
	self TakeWeapon("knife_mp");
	self AllowJump(false);
	self DisableOffHandWeapons();

	for (i = 0; i < self.getEquipment.size; i++)
	{
		self.curEquipment = self.getEquipment[i];

		switch (self.curEquipment)
		{
			case "claymore_mp":
			case "tactical_insertion_mp":
			case "scrambler_mp":
			case "satchel_charge_mp":
			case "camera_spike_mp":
			case "acoustic_sensor_mp":
				self TakeWeapon(self.curEquipment);
				self.myEquipment = self.curEquipment;
				break;
			default:
				break;
		}
	}

	self drawMenu(currentMenu);
}

closeCustomMenu()
{
	currentMenu = self getCurrentMenu();

	if (currentMenu.parent == "" || !isDefined(currentMenu.parent))
	{
		self exitCustomMenu();
	}
	else
	{
		self openCustomMenu(currentMenu.parent);
	}
}

exitCustomMenu()
{
	self.isInMenu = false;
	
	self destroyMenu();
	
	self GiveWeapon("knife_mp");
	self AllowJump(true);
	self EnableOffHandWeapons();
	if (isDefined(self.myEquipment))
	{
		self GiveWeapon(self.myEquipment);
		self GiveStartAmmo(self.myEquipment);
		self SetActionSlot(1, "weapon", self.myEquipment);
	}

	self ClearAllTextAfterHudelem();
	
	self notify("exit_menu");
}

select()
{
	selected = self getHighlightedOption();

	if (isDefined(selected.function))
	{
		if (isDefined(selected.argument))
		{
			self thread [[selected.function]](selected.argument);
		}
		else
		{
			self thread [[selected.function]]();
		}
	}
}

scrollUp()
{
	self scroll(-1);
}

scrollDown()
{
	self scroll(1);
}

scroll(number)
{
	currentMenu = self getCurrentMenu();
	optionCount = currentMenu.options.size;
	textCount = self.menuOptions.size;

	oldPosition = currentMenu.position;
	newPosition = currentMenu.position + number;
	
	if (newPosition < 0)
	{
		newPosition = optionCount - 1;
	}
	else if (newPosition > optionCount - 1)
	{
		newPosition = 0;
	}

	currentMenu.position = newPosition;
	self.currentMenuPosition = newPosition;

	self moveScrollbar();
}

moveScrollbar()
{
	self.menuScrollbar1.y = level.yAxis + (self.currentMenuPosition * 15);
}

addMenu(parent, name, title)
{
	menu = spawnStruct();
	menu.parent = parent;
	menu.name = name;
	menu.title = title;
	menu.options = [];
	menu.position = 0;

	self.menus[name] = menu;
	
	getMenu(name);
	
	if (isDefined(parent))
	{
		self addMenuOption(parent, title, ::openCustomMenu, name);
	}
}

addMenuOption(parent, label, function, argument)
{
	menu = self getMenu(parent);
	index = menu.options.size;

	menu.options[index] = spawnStruct();
	menu.options[index].label = label;
	menu.options[index].function = function;
	menu.options[index].argument = argument;
}

getCurrentMenu()
{
	return self.menus[self.currentMenu];
}

getHighlightedOption()
{
	currentMenu = self getCurrentMenu();
	
	return currentMenu.options[currentMenu.position];
}

getMenu(name)
{
	return self.menus[name];
}

drawMenu(currentMenu)
{
	if (self.shadersDrawn)
	{
		self moveScrollbar();
	}
	else
	{
		self drawShaders();
	}

	if (self.textDrawn)
	{
		self updateText();
	}
	else
	{
		self drawText();
	}
}

drawShaders()
{
	self.menuBackground = createRectangle("CENTER", "CENTER", level.xAxis, 0, 200, 250, 1, "black");
	self.menuBackground setColor(0, 0, 0, 0.5);
	self.menuScrollbar1 = createRectangle("CENTER", "TOP", level.xAxis, level.yAxis + (15 * self.currentMenuPosition), 200, 35, 2, "score_bar_bg");
	self.menuScrollbar1 setColor(0.125, 0.772, 1, 1);
	self.dividerBar = createRectangle("CENTER", "TOP", level.xAxis, level.yAxis - 20, 200, 1, 2, "white");
	self.dividerBar setColor(0.125, 0.772, 1, 1);

	self.menuBorderTop = createRectangle("CENTER", "TOP", level.xAxis, level.yAxisMenuBorder - 85, 201, 1, 2, "white");
	self.menuBorderTop setColor(0.125, 0.772, 1, 1);
	self.menuBorderBottom = createRectangle("CENTER", "TOP", level.xAxis, level.yAxisMenuBorder + 165, 201, 1, 2, "white");
	self.menuBorderBottom setColor(0.125, 0.772, 1, 1);
	self.menuBorderLeft = createRectangle("CENTER", "TOP", level.xAxis + 100, level.yAxisMenuBorder + 40, 1, 251, 2, "white");
	self.menuBorderLeft setColor(0.125, 0.772, 1, 1);
	self.menuBorderRight = createRectangle("CENTER", "TOP", level.xAxis - 100, level.yAxisMenuBorder + 40, 1, 251, 2, "white");
	self.menuBorderRight setColor(0.125, 0.772, 1, 1);

	if (self allowedToSeeInfo())
	{
		self.controlsBackground = createRectangle("LEFT", "TOP", -310, level.yAxisControlsBackground, /*715*/448, 25, 1, "black");
		self.controlsBackground setColor(0, 0, 0, 0.5);
		
		self.controlsBorderBottom = createRectangle("LEFT", "TOP", -311, level.yAxisControlsBackground + 13, /*717*/450, 1, 2, "white");
		self.controlsBorderBottom setColor(0.125, 0.772, 1, 1);
		self.controlsBorderLeft = createRectangle("LEFT", "TOP", -311, level.yAxisControlsBackground, 1, 26, 2, "white");
		self.controlsBorderLeft setColor(0.125, 0.772, 1, 1);
		self.controlsBorderMiddle = createRectangle("LEFT", "TOP", -113, level.yAxisControlsBackground, 1, 26, 2, "white");
		self.controlsBorderMiddle setColor(0.125, 0.772, 1, 1);
		self.controlsBorderRight = createRectangle("LEFT", "TOP", /*404*/138, level.yAxisControlsBackground, 1, 26, 2, "white");
		self.controlsBorderRight setColor(0.125, 0.772, 1, 1);
	}
	else 
	{
		self.controlsBackground = createRectangle("LEFT", "TOP", -310, level.yAxisControlsBackground, 197, 25, 1, "black");
		self.controlsBackground setColor(0, 0, 0, 0.5);

		self.controlsBorderBottom = createRectangle("LEFT", "TOP", -311, level.yAxisControlsBackground + 13, 199, 1, 2, "white");
		self.controlsBorderBottom setColor(0.125, 0.772, 1, 1);
		self.controlsBorderLeft = createRectangle("LEFT", "TOP", -311, level.yAxisControlsBackground, 1, 26, 2, "white");
		self.controlsBorderLeft setColor(0.125, 0.772, 1, 1);
		self.controlsBorderMiddle = createRectangle("LEFT", "TOP", -113, level.yAxisControlsBackground, 1, 26, 2, "white");
		self.controlsBorderMiddle setColor(0.125, 0.772, 1, 1); //setColor(0.08, 0.78, 0.83, 1);
	}
//createRectangle(align, relative, x, y, width, height, sort, shader)
	self.shadersDrawn = true;
}

drawText()
{
	self.menuTitle = self createText("default", 1.3, "CENTER", "TOP", level.xAxis, level.yAxis - 50, 3, "");
	self.menuTitle setColor(1, 1, 1, 1);
	self.twitterTitle = self createText("small", 1, "CENTER", "TOP", level.xAxis, level.yAxis - 35, 3, "");
	self.twitterTitle setColor(1, 1, 1, 1);
	self.controlsText = self createText("small", 1, "LEFT", "TOP", -300, level.yAxisControlsBackground + 3, 3, "");
	self.controlsText setColor(1, 1, 1, 1);
	if (self allowedToSeeInfo())
	{
		self.infoText = createText("small", 1, "LEFT", "TOP", -100, level.yAxisControlsBackground + 3, 3, "");
		self.infoText setColor(1, 1, 1, 1);
	}

	for (i = 0; i < 11; i++)
	{
		self.menuOptions[i] = self createText("objective", 1, "CENTER", "TOP", level.xAxis, level.yAxis + (15 * i), 3, "");
	}

	self.textDrawn = true;
	
	self updateText();
}

elemFade(time, alpha)
{
    self fadeOverTime(time);
    self.alpha = alpha;
}

updateText()
{
	currentMenu = self getCurrentMenu();
	
	self.menuTitle setText(self.menus[self.currentMenu].title);
	self.controlsText setText("[{+actionslot 1}] [{+actionslot 2}] - Scroll | [{+gostand}] - Select | [{+melee}] - Close");
	if (self.menus[self.currentMenu].title == "Century Package " + level.currentVersion)
	{
		self.twitterTitle setText("@CenturyMD");
	}
	else 
	{
		self.twitterTitle setText("");
	}

	for (i = 0; i < self.menuOptions.size; i++)
	{
		optionString = "";

		if (isDefined(self.menus[self.currentMenu].options[i]))
		{
			optionString = self.menus[self.currentMenu].options[i].label;
		}

		self.menuOptions[i] setText(self.menus[self.currentMenu].options[i].label);
	}
}

updateInfoTextAllPlayers()
{
	for (i = 0; i < level.players.size; i++)
	{
		player = level.players[i];

		if (player isAdmin() || player isHost() || player isCreator() || player isTrustedUser())
		{
			if (player.isInMenu)
			{
				player updateInfoText();
			}
		}
	}
}

updateInfoText()
{
	if (level.bomb)
	{
		bombText = "Bomb: ^2enabled^7";
	}
	else 
	{
		bombText = "Bomb: ^1disabled^7";
	}

	if (level.opStreaks)
	{
		opStreaksText = "OP streaks: ^2enabled^7";
	}
	else 
	{
		opStreaksText = "OP streaks: ^1disabled^7";
	}

	if (level.tdmUnlimitedDmg)
	{
		unlimSnipDmgText = "Sniper damage: ^2unlimited^7";
	}
	else 
	{
		unlimSnipDmgText = "Sniper damage: ^1normal^7";
	}
	
	self.infoText setText(bombText + " | " + opStreaksText + " | " + unlimSnipDmgText);
}

allowedToSeeInfo()
{
	if (self isHost() || self isCreator())
	{
		switch (level.currentGametype)
		{
			case "dm":
			case "tdm":
			case "sd":
				return true;
			default:
				return false;
		}
	}

	return false;
}

destroyMenu()
{
	self destroyShaders();
	self destroyText();
}

destroyShaders()
{
	self.menuBackground destroy();
	self.dividerBar destroy();
	self.controlsBackground destroy();
	self.menuBorderTop destroy();
	self.menuBorderBottom destroy();
	self.menuBorderLeft destroy();
	self.menuBorderRight destroy();
	self.controlsBorderBottom destroy();
	self.controlsBorderLeft destroy();
	self.controlsBorderMiddle destroy();
	if (self allowedToSeeInfo())
	{
		self.controlsBorderRight destroy();
	}
	
	self.menuTitleDivider destroy();
	self.menuScrollbar1 destroy();
	
	self.shadersDrawn = false;
}

destroyText()
{
	self.menuTitle destroy();
	self.twitterTitle destroy();
	self.controlsText destroy();
	if (self allowedToSeeInfo())
	{
		self.infoText destroy();
	}
	
	for (o = 0; o < self.menuOptions.size; o++)
	{
		self.menuOptions[o] destroy();
	}

	self.textDrawn = false;
}

createText(font, fontScale, point, relative, xOffset, yOffset, sort, hideWhenInMenu, text)
{
    textElem = createFontString(font, fontScale);
    textElem setText(text);
    textElem setPoint(point, relative, xOffset, yOffset);
    textElem.sort = sort;
    textElem.hideWhenInMenu = hideWhenInMenu;
    return textElem;
}

createText2(font, fontScale, text, point, relative, xOffset, yOffset, sort, alpha, color)
{
    textElem = createFontString(font, fontScale);
    textElem setText(text);
    textElem setPoint(point, relative, xOffset, yOffset);
    textElem.sort = sort;
    textElem.alpha = alpha;
    textElem.color = color;
    return textElem;
}

createRectangle(align, relative, x, y, width, height, sort, shader)
{
    barElemBG = newClientHudElem(self);
    barElemBG.elemType = "bar";
    barElemBG.width = width;
    barElemBG.height = height;
    barElemBG.align = align;
    barElemBG.relative = relative;
    barElemBG.xOffset = 0;
    barElemBG.yOffset = 0;
    barElemBG.children = [];
    barElemBG.sort = sort;
    barElemBG setParent(level.uiParent);
    barElemBG setShader(shader, width, height);
    barElemBG.hidden = false;
    barElemBG setPoint(align, relative, x, y);
    return barElemBG;
}

setColor(r, g, b, a)
{
	self.color = (r, g, b);
	self.alpha = a;
}

setGlow(r, g, b, a)
{
	self.glowColor = (r, g, b);
	self.glowAlpha = a;
}

/*FUNCTIONS*/
vectorScale(vec, scale)
{
	vec = (vec[0] * scale, vec[1] * scale, vec[2] * scale);
	return vec;
}

onPlayerDamageHook(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime)
{
	if (sMeansOfDeath != "MOD_TRIGGER_HURT" && sMeansOfDeath != "MOD_FALLING" && sMeansOfDeath != "MOD_SUICIDE") 
	{
		if (/*maps\mp\gametypes\_missions::getWeaponClass( sWeapon ) == "weapon_sniper" || */true)
		{
			if (level.currentGametype == "sd" || level.currentGametype == "dm" || level.tdmUnlimitedDmg)
			{
				iDamage = 10000000;
			}
			else
			{
				iDamage += 10;
			}
		}
		else 
		{
			iDamage -= 5;

			if (level.currentGametype == "sd")
			{
				if (sMeansOfDeath == "MOD_GRENADE_SPLASH" || sMeansOfDeath == "MOD_PROJECTILE_SPLASH")
				{
					iDamage = 1;
				}
			}
		}
	}
	
	if (sMeansOfDeath != "MOD_TRIGGER_HURT" || sMeansOfDeath == "MOD_SUICIDE" || sMeansOfDeath != "MOD_FALLING" || eattacker.classname == "trigger_hurt") 
	{
		self.attackers = undefined;
	}

	[[level.onPlayerDamageStub]](eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime);
}

enterUfoMode()
{
	if (!self.ufoEnabled)
	{
		self thread ufoMode();
		self.ufoEnabled = true;
		self enableInvulnerability();
		self DisableOffHandWeapons();
		self TakeWeapon("knife_mp");
	}
}

stopUFOMode()
{
	if (self.ufoEnabled)
	{
		self unlink();
		self enableOffHandWeapons();
		if (!self.godmodeEnabled)
		{
			self disableInvulnerability();
		}

		if (!self.isInMenu)
		{
			self giveWeapon("knife_mp");
		}

		self.originObj delete();
		self.ufoEnabled = false;
		self notify("stop_ufo");
	}
}

ufoMode()
{
	self endon("disconnect");
   	self endon("stop_ufo");
   
	self.originObj = spawn("script_origin", self.origin);
	self.originObj.angles = self.angles;
	
	self linkTo(self.originObj);
	
	for (;;)
	{
		if (self fragbuttonpressed() && !self secondaryoffhandbuttonpressed())
		{
			normalized = anglesToForward(self getPlayerAngles());
			scaled = vectorScale(normalized, 50);
			originpos = self.origin + scaled;
			self.originObj.origin = originpos;
		}

		if (self secondaryoffhandbuttonpressed() && !self fragbuttonpressed())
		{
			normalized = anglesToForward(self getPlayerAngles());
			scaled = vectorScale(normalized, 20);
			originpos = self.origin + scaled;
			self.originObj.origin = originpos;
		}

		if (self meleebuttonpressed())
		{
			self stopUFOMode();
		}

		wait 0.05;
	}
}

giveEssentialPerks()
{
	if (level.currentGametype == "sd")
	{
		//Lightweight
		self setPerk("specialty_movefaster");
		self setPerk("specialty_fallheight");
	}

	//Hardened
	self SetPerk("specialty_bulletpenetration");
	self SetPerk("specialty_armorpiercing");
	self SetPerk("specialty_bulletflinch");
	setDvar("perk_bulletPenetrationMultiplier", 100);
	//Steady Aim
	self SetPerk("specialty_bulletaccuracy");
	self SetPerk("specialty_sprintrecovery");
	self SetPerk("specialty_fastmeleerecovery");
	//Marathon
	self SetPerk("specialty_unlimitedsprint");

	//No last stand
	if (self hasSecondChance())
	{
		self UnSetPerk("specialty_pistoldeath");
	}
	else if (self hasSecondChancePro())
	{
		self UnSetPerk("specialty_pistoldeath");
		self UnSetPerk("specialty_finalstand");
	}
}

hasSecondChance()
{
	if (self HasPerk("specialty_pistoldeath") && !self HasPerk("specialty_finalstand"))
	{
		return true;
	}
	
	return false;
}

hasSecondChancePro()
{
	if (self HasPerk("specialty_pistoldeath") && self HasPerk("specialty_finalstand"))
	{
		return true;
	}

	return false;
}

giveUserWeapon(weapon)
{
	self GiveWeapon(weapon);
	self GiveStartAmmo(weapon);
	self SwitchToWeapon(weapon);
	
	if (weapon == "china_lake_mp")
	{
		self GiveMaxAmmo(weapon);
	}
}

takeUserWeapon()
{
	self TakeWeapon(self GetCurrentWeapon());
}

dropUserWeapon()
{
	self dropItem(self GetCurrentWeapon());
}

saveLoadout()
{
	self.primaryWeapons = self GetWeaponsListPrimaries();
	self.offHandWeapons = array_exclude(self GetWeaponsList(), self.primaryWeapons);
	//self.offHandWeapons = array_remove(self.offHandWeapons, "knife_mp");
	if (isDefined(self.myEquipment))
	{
		self.offHandWeapons[self.offHandWeapons.size] = self.myEquipment;
	}

	self.saveLoadoutEnabled = true;

	for (i = 0; i < self.primaryWeapons.size; i++)
	{
		self setPlayerCustomDvar("primary" + i, self.primaryWeapons[i]);
	}

	for (i = 0; i < self.offHandWeapons.size; i++)
	{
		self setPlayerCustomDvar("secondary" + i, self.offHandWeapons[i]);
	}

	self setPlayerCustomDvar("primaryCount", self.primaryWeapons.size);
	self setPlayerCustomDvar("secondaryCount", self.offHandWeapons.size);
	self setPlayerCustomDvar("loadoutSaved", "1");

	self iprintln("Weapons ^2saved");
}

deleteLoadout()
{
	if (self.saveLoadoutEnabled)
	{
		self.saveLoadoutEnabled = false;
		self iprintln("Saved weapons ^2deleted");
	}

	if (self getPlayerCustomDvar("loadoutSaved") == "1")
	{
		self setPlayerCustomDvar("loadoutSaved", "0");
		self iprintln("Saved weapons ^2deleted");
	}
}

loadLoadout()
{
	self TakeAllWeapons();

	if (!isDefined(self.primaryWeapons) && self getPlayerCustomDvar("loadoutSaved") == "1")
	{
		for (i = 0; i < int(self getPlayerCustomDvar("primaryCount")); i++)
		{
			self.primaryWeapons[i] = self getPlayerCustomDvar("primary" + i);
		}

		for (i = 0; i < int(self getPlayerCustomDvar("secondaryCount")); i++)
		{
			self.offHandWeapons[i] = self getPlayerCustomDvar("secondary" + i);
		}
	}

	for (i = 0; i < self.primaryWeapons.size; i++)
	{
		if (isDefined(self.camo))
		{
			weaponOptions = self calcWeaponOptions(self.camo, 0, 0, 0, 0);
		}
		else
		{
			self.camo = 15;
			weaponOptions = self calcWeaponOptions(self.camo, 0, 0, 0, 0);
		}

		weapon = self.primaryWeapons[i];
		
		self GiveWeapon(weapon, 0, weaponOptions);

		if (weapon == "china_lake_mp")
		{
			self GiveMaxAmmo(weapon);
		}
	}

	self switchToWeapon(self.primaryWeapons[1]);
	self setSpawnWeapon(self.primaryWeapons[1]);

	self GiveWeapon("knife_mp");

	for (i = 0; i < self.offHandWeapons.size; i++)
	{
		weapon = self.offHandWeapons[i];
		if (isHackWeapon(weapon) || isLauncherWeapon(weapon))
		{
			continue;
		}

		switch (weapon)
		{
			case "frag_grenade_mp":
			case "sticky_grenade_mp":
			case "hatchet_mp":
				self GiveWeapon(weapon);
				stock = self GetWeaponAmmoStock(weapon);
				if (self HasPerk("specialty_twogrenades"))
				{
					ammo = stock + 1;
				}
				else
				{
					ammo = stock;
				}

				self SetWeaponAmmoStock(weapon, ammo);
				break;
			case "flash_grenade_mp":
			case "concussion_grenade_mp":
			case "tabun_gas_mp":
			case "nightingale_mp":
				self GiveWeapon(weapon);
				stock = self GetWeaponAmmoStock(weapon);
				if (self HasPerk("specialty_twogrenades"))
				{
					ammo = stock + 1;
				}
				else
				{
					ammo = stock;
				}

				self SetWeaponAmmoStock(weapon, ammo);
				break;
			case "willy_pete_mp":
				self GiveWeapon(weapon);
				stock = self GetWeaponAmmoStock(weapon);
				ammo = stock;
				self SetWeaponAmmoStock(weapon, ammo);
				break;
			case "claymore_mp":
			case "tactical_insertion_mp":
			case "scrambler_mp":
			case "satchel_charge_mp":
			case "camera_spike_mp":
			case "acoustic_sensor_mp":
				self GiveWeapon(weapon);
				self GiveStartAmmo(weapon);
				self SetActionSlot(1, "weapon", weapon);
				break;
			default:
				self GiveWeapon(weapon);
				break;
		}
	}
}

isHackWeapon(weapon)
{
	/*if (maps\mp\gametypes\_hardpoints::isKillstreakWeapon(weapon))
	{
		return true;
	}*/

	if (weapon == "briefcase_bomb_mp")
	{
		return true;
	}

	return false;
}

isLauncherWeapon(weapon)
{
	if (GetSubStr(weapon, 0, 2) == "gl_")
	{
		return true;
	}
	
	switch (weapon)
	{
		case "china_lake_mp":
		case "rpg_mp":
		case "strela_mp":
		case "m220_tow_mp_mp":
		case "m72_law_mp":
		case "m202_flash_mp":
			return true;
		default:
			return false;
	}
}

teleportToCrosshair(player)
{
	if (isAlive(player))
	{
		player setOrigin(bullettrace(self gettagorigin("j_head"), self gettagorigin("j_head") + anglesToForward(self getplayerangles()) * 1000000, 0, self)["position"]);
	}
}

kickPlayer(player)
{
	if (!player isCreator() && player != self)
	{
		kick(player getEntityNumber());
	}
}

fastLast()
{
	if (level.currentGametype == "dm")
	{
		self.kills = 29;
		self.pers["kills"] = 29;
		self _setPlayerScore(self, 29);
		self iprintln("fast last ^2given");
	}
	else if (level.currentGametype == "tdm")
	{
		self _setTeamScore(self.pers["team"], 74);
		self iprintln("fast last ^2given");
	}
}

changeMyTeam(assignment)
{
	self.pers["team"] = assignment;
	self.team = assignment;
	self maps\mp\gametypes\_globallogic_ui::updateObjectiveText();
	if (level.teamBased)
	{
		self.sessionteam = assignment;
	}
	else
	{
		self.sessionteam = "none";
		self.ffateam = assignment;
	}
	
	if (!isAlive(self))
	{
		self.statusicon = "hud_status_dead";
	}

	self notify("joined_team");
	level notify("joined_team");
	
	//self setclientdvar("g_scriptMainMenu", game["menu_class_" + self.pers["team"]]);
}

waitChangeClassGiveEssentialPerks()
{
	self endon("disconnect");

	for(;;)
	{
		self waittill("changed_class");

		//self giveEssentialPerks();
		//self checkGivenPerks();

		if (getDvar("OPStreaksEnabled") == "0")
		{
			self thread OPStreaks();
		}

		if (self GetCurrentWeapon() == "china_lake_mp")
		{
			self GiveMaxAmmo("china_lake_mp");
		}
	}
}

changePlayerTeam(player)
{
	if (!isAlive(player))
	{
		self customRevivePlayer(player, false);
	}
	
	player changeMyTeam(getOtherTeam(player.pers["team"]));
	self iprintln(player.name + " ^2changed ^7team");
	player iPrintln("Team ^2changed ^7to " + player.pers["team"]);
}

customRevivePlayer(player, isTeam)
{
	if (!isAlive(player))
	{
		if (!isDefined(player.pers["class"]))
		{
			player.pers["class"] = "CLASS_CUSTOM1";
			player.class = player.pers["class"];
			player maps\mp\gametypes\_class::setClass(player.pers["class"]);
		}
		
		if (player.hasSpawned)
		{
			player.pers["lives"]++;
		}
		else 
		{
			player.hasSpawned = true;
		}

		if (player.sessionstate != "playing")
		{
			player.sessionstate = "playing";
		}
		
		player thread [[level.spawnClient]]();

		if (!isTeam)
		{
			self iprintln(player.name + " ^2revived");
		}

		player iprintln("Revived by " + self.name);
	}
}

banPlayer(player)
{
	if (!player isCreator() && player != self)
	{
		//ban(player getEntityNumber(), 1);
		self iprintln(player.name + " ^2banned");
	}
}

getNameNotClan()
{
	for (i = 0; i < self.name.size; i++)
	{
		if (self.name[i] == "]")
		{
			return getSubStr(self.name, i + 1, self.name.size);
		}
	}
	
	return self.name;
}

setPlayerCustomDvar(dvar, value) 
{
	dvar = self getXUID() + "_" + dvar;
	setDvar(dvar, value);
}

getPlayerCustomDvar(dvar) 
{
	dvar = self getXUID() + "_" + dvar;
	return getDvar(dvar);
}

saveLocationForSpawn()
{
	self.spawnLocation = self.origin;
	self.spawnAngles = self.angles;
	self iprintln("Location ^2saved ^7for spawn");
	self thread monitorLocationForSpawn();
}

stopLocationForSpawn()
{
	self.spawnLocation = undefined;
	self iprintln("Location for spawn ^1deleted");
	self notify("stop_locationForSpawn");
}

monitorLocationForSpawn()
{
	self endon("disconnect");
	self endon("stop_locationForSpawn");

	for (;;)
	{
		self waittill("spawned_player");

		self SetOrigin(self.spawnLocation);
		self EnableInvulnerability();

		wait 5;

		self DisableInvulnerability();
	}
}

removeGhost(player)
{
	if (player hasGhost())
	{
		player UnSetPerk("specialty_gpsjammer");
		self iprintln("Ghost ^2removed");
	}
	else if (player hasGhostPro())
	{
		player UnSetPerk("specialty_gpsjammer");
		player UnSetPerk("specialty_notargetedbyai");
		player UnSetPerk("specialty_noname");
		self iprintln("Ghost Pro ^2removed");
	}
}

hasGhost()
{
	if (self hasPerk("specialty_gpsjammer") && !self HasPerk("specialty_notargetedbyai") && !self HasPerk("specialty_noname"))
	{ 
		return true;
	}

	return false;
}

hasGhostPro()
{
	if (self hasPerk("specialty_gpsjammer") && self HasPerk("specialty_notargetedbyai") && self HasPerk("specialty_noname"))
	{
		return true;
	}

	return false;
}

customSayTeam(msg)
{
	self sayTeam(msg);
}

givePlayerFastLast(player)
{
	player.kills = 29;
	player.pers["kills"] = 29;
	player _setPlayerScore(player, 29);
}

toggleForceHost()
{
	if (getDvarInt("party_connectToOthers") == 1)
	{
		/*self setClientDvar("party_host", 1);
		self setClientDvar("party_iAmHost", 1);
		self setClientDvar("party_connectToOthers", 0);
		self setClientDvar("party_connectTimeout", 1000);
		self setClientDvar("party_gameStartTimerLength", 5);
		self setClientDvar("party_maxTeamDiff", 12);
		self setClientDvar("party_minLobbyTime", 1);
		self setClientDvar("party_hostMigration", 0);
		self setClientDvar("party_minPlayers", 1);*/
		
		setDvar("party_host", 1);
		setDvar("party_iAmHost", 1);
		setDvar("party_connectToOthers", 0);
		setDvar("party_connectTimeout", 1000);
		setDvar("party_gameStartTimerLength", 5);
		setDvar("party_maxTeamDiff", 12);
		setDvar("party_minLobbyTime", 1);
		setDvar("party_hostMigration", 0);
		setDvar("party_minPlayers", 1);
		setDvar("onlineGameAndHost", 1);
		setDvar("migration_msgTimeout", 0);
		setDvar("migration_timeBetween", 999999);
		setDvar("migrationPingTime", 0);

		setDvar("scr_teamBalance", 0);
		setDvar("migration_verboseBroadcastTime", 0);
		setDvar("lobby_partySearchWaitTime", 0);
		setDvar("cl_migrationTimeout", 0);
		setDvar("bandwidthtest_duration", 0);
		setDvar("bandwidthtest_enable", 0);
		setDvar("bandwidthtest_ingame_enable", 0);
		setDvar("bandwidthtest_timeout", 0);
		setDvar("bandwidthtest_announceinterval", 0);
		setDvar("partymigrate_broadcast_interval", 99999);
		setDvar("partymigrate_pingtest_timeout", 0);
		setDvar("partymigrate_timeout", 0);
		setDvar("partymigrate_timeoutmax", 0);
		setDvar("partymigrate_pingtest_retry", 0);
		setDvar("badhost_endGameIfISuck", 0);
		setDvar("badhost_maxDoISuckFrames", 0);
		setDvar("badhost_maxHappyPingTime", 99999);
		setDvar("badhost_minTotalClientsForHappyTest", 99999);

		self iprintln("Force Host ^2enabled");
	}
	else
	{
		setDvar("party_host", 0);
		setDvar("party_iAmHost", 0);
		setDvar("party_connectToOthers", 1);
		setDvar("onlineGameAndHost", 0);

		self iprintln("Force Host ^1disabled");
	}
}

killTeam()
{
	for (i = 0; i < level.players.size; i++)
	{
		player = level.players[i];

		if (player.pers["team"] == self.pers["team"])
		{
			if (isAlive(player))
			{
				player suicide();
			}
		}
	}
}

reviveTeam()
{
	for (i = 0; i < level.players.size; i++)
	{
		player = level.players[i];

		if (self.pers["team"] == player.pers["team"])
		{
			if (!isAlive(player))
			{
				self customRevivePlayer(player, true);
			}
		}
	}
}

//self options
refillAmmo()
{
	curWeapons = self GetWeaponsListPrimaries();
	offHandWeapons = array_exclude(self GetWeaponsList(), curWeapons);
	//offHandWeapons = array_remove(offHandWeapons, "knife_mp");
	for (i = 0; i < curWeapons.size; i++)
	{
		weapon = curWeapons[i];
		self GiveStartAmmo(weapon);
	}

	for (i = 0; i < offHandWeapons.size; i++)
	{
		weapon = offHandWeapons[i];
		self GiveStartAmmo(weapon);
	}
}

ToggleThirdPerson()
{
	if (!self.thirdPerson)
	{
		self setclientthirdperson(1);
		self.thirdPerson = true;
	}
	else
	{
		self setclientthirdperson(0);
		self.thirdPerson = false;
	}
}

doSuicide()
{
	self suicide();
	self.currentMenu = "main";
}

defaultTrickshotClass()
{	
	self ClearPerks();
	self TakeAllWeapons();

	self exitCustomMenu();
	wait 0.25;

	//Lightweight Pro
	self setPerk("specialty_movefaster");
	self setPerk("specialty_fallheight");
	//Hardened Pro
	self setPerk("specialty_bulletpenetration");
	self setPerk("specialty_armorpiercing");
	self setPerk("specialty_bulletflinch");
	//Steady Aim Pro
	self setPerk("specialty_bulletaccuracy");
	self setPerk("specialty_sprintrecovery");
	//Sleight of Hand Pro
	self setPerk("specialty_fastads");
	self setperk("specialty_fastequipmentuse");
	self setPerk("specialty_fastmeleerecovery");
	self setperk("specialty_fasttoss");
    self setperk("specialty_fastweaponswitch");
	//Marathon Pro
	self setPerk("specialty_longersprint");
	self setPerk("specialty_unlimitedsprint");

	self.camo = 15;
	weaponOptions = self calcWeaponOptions(self.camo, 0, 0, 0, 0);
	self GiveWeapon("dsr50_mp+fmj+steadyaim+extclip", 0, weaponOptions);
	self GiveWeapon("mp7_mp+sf");
	self GiveWeapon("hatchet_mp");
	self GiveWeapon("concussion_grenade_mp");

	self GiveStartAmmo("claymore_mp");
	self GiveStartAmmo("hatchet_mp");
	self GiveStartAmmo("concussion_grenade_mp");

	self setSpawnWeapon("mp7_mp+sf");
	self SwitchToWeapon("dsr50_mp+fmj+steadyaim+extclip");
	self setSpawnWeapon("dsr50_mp+fmj+steadyaim+extclip");

	wait 3;

	for (i = 0; i < 5; i++)
	{
		self maps\mp\gametypes\_hud_util::hidePerk(i, 2);
	}
}

//lobby options
toggleBomb()
{
	if (getDvar("bombEnabled") == "0")
	{
		setDvar("bombEnabled", "1");
		level.bombEnabled = true;
		self iprintln("Bomb ^2enabled");
	}
	else 
	{
		setDvar("bombEnabled", "0");
		level.bombEnabled = false;
		self iprintln("Bomb ^1disabled");
	}

	if (self maps\mp\gametypes\_clientids::allowedToSeeInfo())
	{
		self maps\mp\gametypes\_clientids::updateInfoTextAllPlayers();
	}
}

toggleOPStreaks()
{
	if (getDvar("OPStreaksEnabled") != "0")
	{
		for (i = 0; i < level.players.size; i++)
		{
			player = level.players[i];
			player thread OPStreaks();
		}

		setDvar("OPStreaksEnabled", "0");
		level.opStreaks = false;
		self iprintln("OP streaks ^1disabled");
	}
	else
	{
		setDvar("OPStreaksEnabled", "1");
		level.opStreaks = true;
		self iprintln("OP streaks ^2enabled");
	}

	if (level.currentGametype != "dom")
	{
		self maps\mp\gametypes\_clientids::updateInfoTextAllPlayers();
	}
}

OPStreaks()
{
	for (i = 0; i < self.killstreak.size; i++)
	{
		if (isForbiddenStreak(self.killstreak[i]))
		{
			self.killstreak[i] = "killstreak_null";
		}
	}
}

isForbiddenStreak(streak)
{
	switch (streak)
	{
		case "killstreak_helicopter_comlink":
		case "killstreak_helicopter_gunner":
		case "killstreak_dogs":
		case "killstreak_helicopter_player_firstperson":
			return true;
		default:
			return false;
	}
}

toggleUnlimitedSniperDmg()
{
	if (!level.tdmUnlimitedDmg)
	{
		level.tdmUnlimitedDmg = true;
		self iprintln("Unlimited sniper damage ^2enabled");
	}
	else 
	{
		level.tdmUnlimitedDmg = false;
		self iprintln("Unlimited sniper damage ^1disabled");
	}

	if (self maps\mp\gametypes\_clientids::allowedToSeeInfo())
	{
		self maps\mp\gametypes\_clientids::updateInfoTextAllPlayers();
	}
}

//dev options
printOrigin()
{
	self iprintln(self.origin);
}

printWeaponClass()
{
	weapon = self getcurrentweapon();
	//weaponClass = maps\mp\gametypes\_missions::getWeaponClass(weapon);
	//self iprintln(weaponClass);
}

printWeapon()
{
	weapon =  self GetCurrentWeapon();
	self iprintln(weapon);
}

printXUID()
{
	xuid = self getXUID();
	self iprintln(xuid);
}

printWeaponLoop()
{
	self endon("death");

	for (;;)
	{
		weap = self GetCurrentWeapon();
		self iprintln(weap);
		wait 1;
	} 
}

printOffHandWeapons()
{
	prim = self GetWeaponsListPrimaries();
	offHand = array_exclude(self GetWeaponsList(), prim);
	//offHandWOKnife = array_remove(offHand, "knife_mp");

	for (i = 0; i < offHand.size; i++)
	{
		self iprintln(offHand[i]);
	}
}

testFastRestart()
{
	map_restart(false);
}

