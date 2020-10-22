#include maps\mp\gametypes\_hud_util;
#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_globallogic_score;
//Custom files
#include maps\mp\gametypes\custom\_self_options;
#include maps\mp\gametypes\custom\_class_options;
#include maps\mp\gametypes\custom\_lobby_options;

init()
{
	level.clientid = 0;

	level.currentVersion = "azza";
	level.currentGametype = getDvar("g_gametype");
	level.currentMapName = getDvar("mapName");
	setDvar("sv_cheats", "1");

	level.rankedMatch = true;
	level.contractsEnabled = true;
	level.azza = true;

	switch (level.currentGametype)
	{
		case "dm":
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

	if (getDvar("cg_nopredict") == "1")
	{
		level.precam = true;
	}
	else 
	{
		level.precam = false;
	}

	if (getDvar("killcam_final") == "1")
	{
		level.playercard = true;
	}
	else 
	{
		level.playercard = false;
	}

	if (getDvar("multiSetupsEnabled") == "1")
	{
		level.multiSetups = true;
	}
	else 
	{
		level.multiSetups = false;
	}

	level.spawned_bots = 0;
	level.multipleSetupsEnabled = false;
	//Precache for the menu UI
	precacheShader("score_bar_bg");
	precacheModel("t5_weapon_cz75_dw_lh_world");

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
		player.isFrozen = false;
		player.explosiveBullets = false;
		player.ebRange = 150;
		player.soundEnabled = true;

		if (isDefined(player getPlayerCustomDvar("positionMap")))
		{
			if (player getPlayerCustomDvar("positionMap") != level.currentMapName)
			{
				player setPlayerCustomDvar("positionSaved", "0");
			}
			
			if (player getPlayerCustomDvar("positionMap") == level.currentMapName && isDefined(player getPlayerCustomDvar("position0")))
			{
				player setPlayerCustomDvar("positionSaved", "1");
			}
		}

		if (isDefined(player getPlayerCustomDvar("camo")))
		{
			player.camo = int(player getPlayerCustomDvar("camo"));
		}

		if (level.azza)
		{
			player thread setMatchBonus();
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

		self.isFrozen = false;

		if (firstSpawn)
		{
			if (level.azza || self isHost())
			{
				self iPrintln("gsc.cty loaded");
				self FreezeControls(false);
				
				self thread runController();
				self thread buildMenu();
				self thread drawMessages();
			}

			if (level.console)
			{
				self.yAxis = 150;
				self.yAxisWeapons = 185;
			}
			else 
			{
				self.yAxis = 200;
				self.yAxisWeapons = 200;
			}

			if (level.azza && level.currentGametype == "sd")
			{
				if (!self is_bot())
				{
					if (self.pers["team"] != "allies")
					{
						self thread changeMyTeam("allies");
					}
				}
				else
				{
					if(self.pers["team"] != "axis")
					{
						self thread changeMyTeam("axis");
					}
				}
			}

			if (self isHost())
			{
				if (level.currentGametype == "sd")
				{
					level.gracePeriod = 5;
				}
			}

			firstSpawn = false;
		}

		if (self.saveLoadoutEnabled || self getPlayerCustomDvar("loadoutSaved") == "1")
		{
			self thread loadLoadout();
		}

		self thread checkGivenPerks();
		self thread giveEssentialPerks();
		self thread waitChangeClassGiveEssentialPerks();
	}
}

runController()
{
	self endon("disconnect");

	firstTime = true;

	for(;;)
	{
		if (level.azza || self isHost())
		{
			if (self.isInMenu)
			{
				if (self jumpbuttonpressed())
				{
					self thread select();
					wait 0.25;
				}

				if (self meleebuttonpressed())
				{
					self thread closeMenu();
					wait 0.25;
				}

				if (self actionslottwobuttonpressed())
				{
					self thread scrollDown();
				}

				if (self actionslotonebuttonpressed())
				{
					self thread scrollUp();
				}
			}
			else
			{
				if (self adsbuttonpressed() && self actionslottwobuttonpressed() && !self isMantling())
				{
					self thread openMenu(self.currentMenu);
					self updateInfoText();
					wait 0.25;
				}

				//UFO mode
				if (self actionSlotthreeButtonPressed() && self GetStance() == "crouch")
				{
					self thread enterUfoMode();
					wait .12;
				}

				//Save position
				if (self meleeButtonPressed() && self adsButtonPressed() && self getStance() == "crouch")
				{
					self.positionArray = strTok(self.origin, ",");
					fixedPosition1 = getSubStr(self.positionArray[0], 1, self.positionArray[0].size);
					fixedPosition2 = getSubStr(self.positionArray[2], 0, self.positionArray[0].size);
					self.positionArray[0] = fixedPosition1;
					self.positionArray[2] = fixedPosition2;

					for (i = 0; i < self.positionArray.size; i++)
					{
						self setPlayerCustomDvar("position" + i, self.positionArray[i]);
					}
					self setPlayerCustomDvar("positionSaved", "1");
					self setPlayerCustomDvar("positionMap", level.currentMapName);
					self printInfoMessageNoMenu("Position ^2saved");
					wait .12;
				}

				//Load position
				if (self GetStance() == "crouch" && self actionSlotfourButtonPressed() && self getPlayerCustomDvar("positionSaved") != "0")
				{
					position = (int(self getPlayerCustomDvar("position0")), int(self getPlayerCustomDvar("position1")), int(self getPlayerCustomDvar("position2")));
					self SetOrigin(position);
					wait .12;
				}
			}

			if (self isHost() && level.gameForfeited)
			{
				level.gameForfeited = false;
				level notify("abort forfeit");
			}
		}

		if (self isHost() && level.currentGametype == "sd")
		{
			timeLeft = maps\mp\gametypes\_globallogic_utils::getTimeRemaining(); //5000 = 5sec
			if (timeLeft < 1500 && firstTime)
			{
				timeLimit = getDvarInt("scr_" + level.currentGametype + "_timelimit");
				setDvar("scr_" + level.currentGametype + "_timelimit", timelimit + 2.5); //2.5 equals to 2 min ingame in this case for some reason
				firstTime = false;
			}
		}

		wait 0.05;
	}
}

/*MENU*/
buildMenu()
{
	self.menus = [];

	m = "main";
	self addMenu("", m, "gsc.cty " + level.currentVersion);
	self addOption(m, "Godmode", ::toggleGodmode);
	self addOption(m, "Invisible", ::toggleInvisible);
	self addOption(m, "Refill Ammo", ::refillAmmo);
	self addMenu(m, "MainSelf", "^9Self Options");
	self addMenu(m, "MainTrick", "^9Trickshot stuff");
	self addMenu(m, "MainClass", "^9Class Options");
	self addMenu(m, "MainLobby", "^9Lobby Options");

	m = "MainSelf";
	self addOption(m, "Suicide", ::doSuicide);
	self addOption(m, "Third Person", ::ToggleThirdPerson);
	self addOption(m, "Give default ts loadout", ::defaultTrickshotClass);
	self addOption(m, "Save Loadout", ::saveLoadout);
	self addOption(m, "Delete saved loadout", ::deleteLoadout);

	m = "MainTrick";
	self addOption(m, "Toggle EB", ::toggleExplosiveBullets);
	self addOption(m, "Change timescale", ::changeTimescale);
	self addOption(m, "Change gravity", ::changeGravity);
	self addOption(m, "Change ladder knockback", ::changeLadderKnockback);
	self addOption(m, "Change EB range", ::changeEBRange);
	self addMenu(m, "TrickAfterHit", "^9After hit Settings");

	m = "TrickAfterHit";
	self addMenu(m, "AfterHitEquipment", "^9Equipment");
	self addMenu(m, "AfterHitKillstreak", "^9Killstreak");
	self addMenu(m, "AfterHitMisc", "^9Misc");
	self addOption(m, "Current Weapon", ::afterHitWeapon);
	self addOption(m, "None", ::afterHitWeapon, "none");
	self addOption(m, "With gunsound", ::toggleGunsound, true);
	self addOption(m, "Without gunsound", ::toggleGunsound, false);

	m = "AfterHitEquipment";
	self addOption(m, "Claymore", ::afterHitWeapon, "claymore_mp");
	self addOption(m, "C4", ::afterHitWeapon, "satchel_charge_mp");
	self addOption(m, "Scrambler", ::afterHitWeapon, "scrambler_mp");
	self addOption(m, "Tactical Insertion", ::afterHitWeapon, "tactical_insertion_mp");
	self addOption(m, "Motion Sensor", ::afterHitWeapon, "acoustic_sensor_mp");
	self addOption(m, "Camera Spike", ::afterHitWeapon, "camera_spike_mp");

	m = "AfterHitKillstreak";
	self addOption(m, "RC-XD", ::afterHitWeapon, "rcbomb_mp");
	self addOption(m, "Minigun", ::afterHitWeapon, "minigun_mp");
	
	m = "AfterHitMisc";
	self addOption(m, "Briefcase Bomb", ::afterHitWeapon, "briefcase_bomb_mp");
	self addOption(m, "Syrette", ::afterHitWeapon, "syrette_mp");

	m = "MainClass";
	self addMenu(m, "ClassWeapon", "^9Weapon Selector");
	self addMenu(m, "ClassGrenades", "^9Grenade Selector");
	self addMenu(m, "ClassCamo", "^9Camo Selector");
	self addMenu(m, "ClassPerk", "^9Perk Selector");
	self addMenu(m ,"ClassAttachment", "^9Attachment Selector");
	self addMenu(m, "ClassEquipment", "^9Equipment Selector");
	self addMenu(m, "ClassTacticals", "^9Tacticals Selector");
	self addMenu(m, "ClassKillstreaks", "^9Killstreak Menu");

	self thread buildWeaponMenu();
	
	m = "ClassGrenades";
	self addOption(m, "Frag", ::giveGrenade, "frag_grenade_mp");
	self addOption(m, "Semtex", ::giveGrenade, "sticky_grenade_mp");
	self addOption(m, "Tomahawk", ::giveGrenade, "hatchet_mp");

    m = "ClassCamo";
	self addMenu(m, "CamoOne", "^9Camos Part 1");
	self addMenu(m, "CamoTwo", "^9Camos Part 2");
	self addOption(m, "Random Camo", ::randomCamo);
    
	m = "CamoOne";
	self addOption(m, "None", ::changeCamo, 0);
	self addOption(m, "Dusty", ::changeCamo, 1);
	self addOption(m, "Ice", ::changeCamo, 2);
	self addOption(m, "Red", ::changeCamo, 3);
	self addOption(m, "Olive", ::changeCamo, 4);
	self addOption(m, "Nevada", ::changeCamo, 5);
	self addOption(m, "Sahara", ::changeCamo, 6);
	self addOption(m, "ERDL", ::changeCamo, 7);
	
	m = "CamoTwo";
	self addOption(m, "Tiger", ::changeCamo, 8);
	self addOption(m, "Berlin", ::changeCamo, 9);
	self addOption(m, "Warsaw", ::changeCamo, 10);
	self addOption(m, "Siberia", ::changeCamo, 11);
	self addOption(m, "Yukon", ::changeCamo, 12);
	self addOption(m, "Woodland", ::changeCamo, 13);
	self addOption(m, "Flora", ::changeCamo, 14);
	self addOption(m, "Gold", ::changeCamo, 15);
	
	m = "ClassPerk";
	self addOption(m, "Toggle Lightweight Pro", ::givePlayerPerk, "lightweightPro");
	self addOption(m, "Toggle Ghost Pro", ::givePlayerPerk, "ghostPro");
	self addOption(m, "Toggle Flak Jacket Pro", ::givePlayerPerk, "flakJacketPro");
	self addOption(m, "Toggle Scout Pro", ::givePlayerPerk, "scoutPro");
	self addOption(m, "Toggle Sleight of Hand Pro", ::givePlayerPerk, "sleightOfHandPro");
	self addOption(m, "Toggle Ninja Pro", ::givePlayerPerk, "ninjaPro");
	self addOption(m, "Toggle Hacker Pro", ::givePlayerPerk, "hackerPro");
	self addOption(m, "Toggle Tactical Mask Pro", ::givePlayerPerk, "tacticalMaskPro");

	m = "ClassAttachment";
	self addMenu(m, "AttachOptic", "^9Optics");
	self addMenu(m, "AttachMag", "^9Mags");
	self addMenu(m, "AttachUnderBarrel", "^9Underbarrel");
	self addMenu(m, "AttachOther", "^9Other");
	self addOption(m, "Remove all attachments", ::removeAllAttachments);

	m = "AttachOptic";
	self addOption(m, "Toggle Reflex", ::givePlayerAttachment, "reflex");
	self addOption(m, "Toggle Red Dot", ::givePlayerAttachment, "elbit");
	self addOption(m, "Toggle Variable Zoom", ::givePlayerAttachment, "vzoom");
	self addOption(m, "Toggle IR", ::givePlayerAttachment, "ir");
	self addOption(m, "Toggle ACOG", ::givePlayerAttachment, "acog");
	self addOption(m, "Toggle Upgraded Sight", ::givePlayerAttachment, "upgradesight");
	self addOption(m, "Toggle Low Power Scope", ::givePlayerAttachment, "lps");

	m = "AttachMag";
	self addOption(m, "Toggle Extended Clip", ::givePlayerAttachment, "extclip");
	self addOption(m, "Toggle Dual Mag", ::givePlayerAttachment, "dualclip");
	self addOption(m, "Toggle Speed Loader", ::givePlayerAttachment, "speed");

	m = "AttachUnderBarrel";
	self addOption(m, "Toggle Flamethrower", ::givePlayerAttachment, "ft");
	self addOption(m, "Toggle Masterkey", ::givePlayerAttachment, "mk");
	self addOption(m, "Toggle Grenade Launcher", ::givePlayerAttachment, "gl");
	self addOption(m, "Toggle Grip", ::givePlayerAttachment, "grip");

	m = "AttachOther";
	self addOption(m, "Give Silencer", ::givePlayerAttachment, "silencer");
	self addOption(m, "Give Snub Nose", ::givePlayerAttachment, "snub");
	self addOption(m, "Toggle Dual Wield", ::givePlayerAttachment, "dw");

	m = "ClassKillstreaks";
	self addOption(m, "Spy Plane", ::giveUserKillstreak, "radar_mp");
	self addOption(m, "RC-XD", ::giveUserKillstreak, "rcbomb_mp");
	self addOption(m, "Counter-Spy Plane", ::giveUserKillstreak, "counteruav_mp");
	self addOption(m, "Sam Turret", ::giveUserKillstreak, "tow_turret_drop_mp");
	self addOption(m, "Carepackage", ::giveUserKillstreak, "supply_drop_mp");
	self addOption(m, "Napalm Strike", ::giveUserKillstreak, "napalm_mp");
	self addOption(m, "Sentry Gun", ::giveUserKillstreak, "autoturret_mp");
	self addOption(m, "Mortar Team", ::giveUserKillstreak, "mortar_mp");
	self addOption(m, "Valkyrie Rocket", ::giveUserKillstreak, "m220_tow_mp");
	self addOption(m, "Blackbird", ::giveUserKillstreak, "radardirection_mp");
	self addOption(m, "Minigun", ::giveUserKillstreak, "minigun_mp");
    
	m = "ClassEquipment";
	self addOption(m, "Camera Spike", ::giveUserEquipment, "camera_spike_mp");
	self addOption(m, "C4", ::giveUserEquipment, "satchel_charge_mp");
	self addOption(m, "Tactical Insertion", ::giveUserEquipment, "tactical_insertion_mp");
	self addOption(m, "Jammer", ::giveUserEquipment, "scrambler_mp");
	self addOption(m, "Motion Sensor", ::giveUserEquipment, "acoustic_sensor_mp");
	self addOption(m, "Claymore", ::giveUserEquipment, "claymore_mp");

	m = "ClassTacticals";
	self addOption(m, "Willy Pete", ::giveUserTacticals, "willy_pete_mp");
	self addOption(m, "Nova Gas", ::giveUserTacticals, "tabun_gas_mp");
	self addOption(m, "Flashbang", ::giveUserTacticals, "flash_grenade_mp");
	self addOption(m, "Concussion", ::giveUserTacticals, "concussion_grenade_mp");
	self addOption(m, "Decoy", ::giveUserTacticals, "nightingale_mp");

	m = "MainLobby";
	self addOption(m, "Toggle timer", ::toggleTimer);
	self addOption(m, "Add bot", ::addDummies);
	self addOption(m, "Add 1 minute", ::addMinuteToTimer);
	self addOption(m, "Remove 1 minute", ::removeMinuteFromTimer);
	if (level.currentGametype == "sd")
	{
		self addOption(m, "Allow multiple setups", ::toggleMultipleSetups);
		self addOption(m, "Toggle Bomb", ::toggleBomb);
	}

	if (self isHost() || self isCreator())
	{
		self addOption(m, "Pre-cam weapon animations", ::precamOTS);
		self addOption(m, "Toggle own player card in killcam", ::togglePlayercard);
	}

	self addMenu("main", "MainPlayers", "^9Players Menu");
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

			self addOption(player_name, "Teleport player to crosshair", ::teleportToCrosshair, player);
			self addOption(player_name, "Teleport myself to player", ::teleportSelfTo, player);
			self addOption(player_name, "Kill Player", ::killPlayer, player);
			self addOption(player_name, "Freeze Player", ::freezePlayer, player);

			if (self isHost() || self isCreator())
			{
				self addOption(player_name, "Kick Player", ::kickPlayer, player);
				self addOption(player_name, "Ban Player", ::banPlayer, player);
			}
		}
	}
	else if (level.teamBased)
	{
		myTeam = self.pers["team"];
		otherTeam = getOtherTeam(myTeam);
		
		self addMenu(m, "PlayerFriendly", "^9Friendly players");
		self addMenu(m, "PlayerEnemy", "^9Enemy players");

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
			
			self addOption(player_name, "Teleport player to crosshair", ::teleportToCrosshair, player);
			self addOption(player_name, "Teleport myself to player", ::teleportSelfTo, player);
			self addOption(player_name, "Kill Player", ::killPlayer, player);
			self addOption(player_name, "Freeze Player", ::freezePlayer, player);

			if (self isHost() || self isCreator())
			{
				self addOption(player_name, "Kick Player", ::kickPlayer, player);
				self addOption(player_name, "Ban Player", ::banPlayer, player);
				self addOption(player_name, "Change Team", ::changePlayerTeam, player);
			}

			if (level.currentGametype == "sd")
			{
				self addOption(player_name, "Revive player", ::revivePlayer, player);
			}
		}
	}
}

buildWeaponMenu()
{
	m = "ClassWeapon";
	self addMenu(m, "WeaponPrimary", "^9Primary");
	self addMenu(m, "WeaponSecondary", "^9Secondary");
	self addMenu(m, "WeaponDualWield", "^9Dual Wield");
	self addMenu(m, "WeaponGlitch", "^9Glitch");
	self addOption(m, "Take Weapon", ::takeUserWeapon);
	self addOption(m, "Drop Weapon", ::dropUserWeapon);
	
	m = "WeaponPrimary";
	self addMenu(m, "PrimarySMG", "^9SMG");
	self addMenu(m, "PrimaryAssault", "^9Assault");
	self addMenu(m, "PrimaryShotgun", "^9Shotgun");
	self addMenu(m, "PrimaryLMG", "^9LMG");
	self addMenu(m, "PrimarySniper", "^9Sniper");
	
	m = "PrimarySMG";
	self addOption(m, "MP5K", ::giveUserWeapon, "mp5k_mp");
	self addOption(m, "Skorpion", ::giveUserWeapon, "skorpion_mp");
	self addOption(m, "MAC11", ::giveUserWeapon, "mac11_mp");
	self addOption(m, "AK74u", ::giveUserWeapon, "ak74u_mp");
	self addOption(m, "UZI", ::giveUserWeapon, "uzi_mp");
	self addOption(m, "PM63", ::giveUserWeapon, "pm63_mp");
	self addOption(m, "MPL", ::giveUserWeapon, "mpl_mp");
	self addOption(m, "Spectre", ::giveUserWeapon, "spectre_mp");
	self addOption(m, "Kiparis", ::giveUserWeapon, "kiparis_mp");
	
	m = "PrimaryAssault";
	self addOption(m, "M16", ::giveUserWeapon, "m16_mp");
	self addOption(m, "Enfield", ::giveUserWeapon, "enfield_mp");
	self addOption(m, "M14", ::giveUserWeapon, "m14_mp");
	self addOption(m, "Famas", ::giveUserWeapon, "famas_mp");
	self addOption(m, "Galil", ::giveUserWeapon, "galil_mp");
	self addOption(m, "AUG", ::giveUserWeapon, "aug_mp");
	self addOption(m, "FN FAL", ::giveUserWeapon, "fnfal_mp");
	self addOption(m, "AK47", ::giveUserWeapon, "ak47_mp");
	self addOption(m, "Commando", ::giveUserWeapon, "commando_mp");
	self addOption(m, "G11", ::giveUserWeapon, "g11_mp");
	
	m = "PrimaryShotgun";
	self addOption(m, "Olympia", ::giveUserWeapon, "rottweil72_mp");
	self addOption(m, "Stakeout", ::giveUserWeapon, "ithaca_grip_mp");
	self addOption(m, "SPAS-12", ::giveUserWeapon, "spas_mp");
	self addOption(m, "HS10", ::giveUserWeapon, "hs10_mp");
	
	m = "PrimaryLMG";
	self addOption(m, "HK21", ::giveUserWeapon, "hk21_mp");
	self addOption(m, "RPK", ::giveUserWeapon, "rpk_mp");
	self addOption(m, "M60", ::giveUserWeapon, "m60_mp");
	self addOption(m, "Stoner63", ::giveUserWeapon, "stoner63_mp");
	
	m = "PrimarySniper";
	self addOption(m, "Dragunov", ::giveUserWeapon, "dragunov_mp");
	self addOption(m, "WA2000", ::giveUserWeapon, "wa2000_mp");
	self addOption(m, "L96A1", ::giveUserWeapon, "l96a1_mp");
	self addOption(m, "PSG1", ::giveUserWeapon, "psg1_mp");
	
	m = "WeaponSecondary";
	self addMenu(m, "SecondaryPistol", "^9Pistol");
	self addMenu(m, "SecondaryLauncher", "^9Launcher");
	self addMenu(m, "SecondarySpecial", "^9Special");
	
	m = "SecondaryPistol";
	self addOption(m, "ASP", ::giveUserWeapon, "asp_mp");
	self addOption(m, "M1911", ::giveUserWeapon, "m1911_mp");
	self addOption(m, "Makarov", ::giveUserWeapon, "makarov_mp");
	self addOption(m, "Python", ::giveUserWeapon, "python_mp");
	self addOption(m, "CZ75", ::giveUserWeapon, "cz75_mp");
	
	m = "SecondaryLauncher";
	self addOption(m, "M72 LAW", ::giveUserWeapon, "m72_law_mp");
	self addOption(m, "RPG", ::giveUserWeapon, "rpg_mp");
	self addOption(m, "Strela-3", ::giveUserWeapon, "strela_mp");
	self addOption(m, "China Lake", ::giveUserWeapon, "china_lake_mp");
	
	m = "SecondarySpecial";
	self addOption(m, "Ballistic Knife", ::giveUserWeapon, "knife_ballistic_mp");
	self addOption(m, "Crossbow", ::giveUserWeapon, "crossbow_explosive_mp");
	
	m = "WeaponDualWield";
	self addOption(m, "ASP", ::giveUserWeapon, "aspdw_mp");
	self addOption(m, "Makarov", ::giveUserWeapon, "makarovdw_mp");
	self addOption(m, "M1911", ::giveUserWeapon, "m1911dw_mp");
	self addOption(m, "Python", ::giveUserWeapon, "pythondw_mp");
	self addOption(m, "CZ75", ::giveUserWeapon, "cz75dw_mp");
	self addOption(m, "HS10", ::giveUserWeapon, "hs10dw_mp");
	self addOption(m, "Skorpion", ::giveUserWeapon, "skorpiondw_mp");
	self addOption(m, "PM63", ::giveUserWeapon, "pm63dw_mp");
	self addOption(m, "Kiparis", ::giveUserWeapon, "kiparisdw_mp");

	m = "WeaponGlitch";
	self addOption(m, "ASP", ::giveUserWeapon, "asplh_mp");
	self addOption(m, "M1911", ::giveUserWeapon, "m1911lh_mp");
	self addOption(m, "Makarov", ::giveUserWeapon, "makarovlh_mp");
	self addOption(m, "Python", ::giveUserWeapon, "pythonlh_mp");
	self addOption(m, "CZ75", ::giveUserWeapon, "cz75lh_mp");
	self addOption(m, "Syrette", ::giveUserWeapon, "syrette_mp");
	self addOption(m, "Briefcase Bomb", ::giveUserWeapon, "briefcase_bomb_mp");
	self addOption(m, "Autoturret", ::giveUserWeapon, "autoturret_mp");
	self addOption(m, "Default weapon", ::giveUserWeapon, "defaultweapon_mp");
}

/*MENU FUNCTIONS*/
isCreator()
{
	xuid = self getXUID();
	if (xuid == "11000010d1c86bb"/*PC*/ || xuid == "8776e339aad3f92e"/*PS3 Online*/ || xuid == "248d65be0fe005"/*PS3 Offline*/)
	{
		return true;
	}

	return false;
}

closeMenuOnDeath()
{
	self endon("exit_menu");

	self waittill("death");
	
	self ClearAllTextAfterHudelem();
	self thread exitMenu();
}

openMenu(menu)
{
	self.getEquipment = self GetWeaponsList();
	self.getEquipment = array_remove(self.getEquipment, "knife_mp");
	
	self.isInMenu = true;
	self.currentMenu = menu;
	currentMenu = self getCurrentMenu();
	if (currentMenu == self.menus["MainPlayers"])
	{
		self thread buildMenu();
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

	self thread drawMenu(currentMenu);
}

closeMenu()
{
	currentMenu = self getCurrentMenu();

	if (currentMenu.parent == "" || !isDefined(currentMenu.parent))
	{
		self thread exitMenu();
	}
	else
	{
		self thread openMenu(currentMenu.parent);
	}
}

exitMenu()
{
	self.isInMenu = false;
	
	self thread destroyMenu();
	
	self GiveWeapon("knife_mp");
	self AllowJump(true);
	self EnableOffHandWeapons();
	if (isDefined(self.myEquipment))
	{
		self GiveWeapon(self.myEquipment);
		self GiveStartAmmo(self.myEquipment);
		self SetActionSlot(1, "weapon", self.myEquipment);
	}

	self.infoMessage.alpha = 0;
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
	self thread scroll(-1);
}

scrollDown()
{
	self thread scroll(1);
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

	self thread moveScrollbar();
}

moveScrollbar()
{
	self.menuScrollbar1.y = self.yAxis + (self.currentMenuPosition * 15);
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
		self addOption(parent, title, ::openMenu, name);
	}
}

addOption(parent, label, function, argument)
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
		self thread moveScrollbar();
	}
	else
	{
		self thread drawShaders();
	}

	if (self.textDrawn)
	{
		self thread updateText();
	}
	else
	{
		self thread drawText();
	}
}

drawShaders()
{
	self.menuBackground = createRectangle("CENTER", "CENTER", -250, 0, 200, 250, 1, "black");
	self.menuBackground setColor(0, 0, 0, 1);
	self.menuScrollbar1 = createRectangle("CENTER", "TOP", -250, self.yAxis + (15 * self.currentMenuPosition), 200, 35, 2, "score_bar_bg");
	self.menuScrollbar1 setColor(1, 1, 1, 1);
	self.infoBackground = createRectangle("CENTER", "CENTER", -225, -180, 150, 100, 1, "black");
	self.infoBackground setColor(1, 1, 1, 1);

	self.shadersDrawn = true;
}

drawMessages()
{
	self.infoMessage = self createText2("default", 1, " ", "CENTER", "CENTER", -250, 100, 3, 0, (1, 1, 1));
	self.ufoMessage1 = self createText2("default", 1, " ", "LEFT", "CENTER", -370, -10, 3, 0, (1, 1, 1));
	self.ufoMessage1.archived = false;
	self.ufoMessage2 = self createText2("default", 1, " ", "LEFT", "CENTER", -370, 5, 3, 0, (1, 1, 1));
	self.ufoMessage2.archived = false;
	self.ufoMessage3 = self createText2("default", 1, " ", "LEFT", "CENTER", -370, 20, 3, 0, (1, 1, 1));
	self.ufoMessage3.archived = false;
	self.infoMessageNoMenu = self createText2("default", 1, " ", "LEFT", "CENTER", -370, -100, 3, 0, (1, 1, 1));
	self.infoMessageNoMenu.archived = false;
}

drawText()
{
	self.menuTitle = self createText("objective", 1.3, "CENTER", "TOP", -250, self.yAxis - 50, 3, "");
	self.menuTitle setColor(1, 1, 1, 1);
	self.twitterTitle = self createText("small", 1, "CENTER", "TOP", -250, self.yAxis - 35, 3, "");
	self.twitterTitle setColor(1, 1, 1, 1);

	for (i = 0; i < 11; i++)
	{
		self.menuOptions[i] = self createText("objective", 1, "CENTER", "TOP", -250, self.yAxis + (15 * i), 3, "");
	}

	for (i = 0; i < 5; i++)
	{
		self.infoText[i] = self createText("objective", 1, "LEFT", "TOP", -290, (self.yAxis - 170) + (15 * i), 3, "");
	}

	self.textDrawn = true;
	
	self thread updateText();
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
	if (self.menus[self.currentMenu].title == "gsc.cty " + level.currentVersion)
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

		if (player.isInMenu)
		{
			player updateInfoText();
		}
	}
}

updateInfoText()
{
	if (level.azza)
	{
		azzaText = "Azza: ^2enabled";
	}
	else
	{
		azzaText = "Azza: ^1disabled";
	}

	if (level.bomb)
	{
		bombText = "Bomb: ^2enabled";
	}
	else 
	{
		bombText = "Bomb: ^1disabled";
	}

	if (level.precam)
	{
		precamText = "Pre-cam animations: ^2enabled";
	}
	else 
	{
		precamText = "Pre-cam animations: ^1disabled";
	}

	if (level.playercard)
	{
		playercardText = "Own player card: ^2visible";
	}
	else 
	{
		playercardText = "Own player card: ^1not visible";
	}

	if (level.multiSetups)
	{
		multiSetupsText = "Multiple setups: ^2enabled";
	}
	else 
	{
		multiSetupsText = "Multiple setups: ^1disabled";
	}
	
	for (i = 0; i < self.infoText.size; i++)
	{
		self.infoText[0] setText(azzaText);
		self.infoText[1] setText(bombText);
		self.infoText[2] setText(precamText);
		self.infoText[3] setText(playercardText);
		self.infoText[4] setText(multiSetupsText);
	}
}

destroyMenu()
{
	self thread destroyShaders();
	self thread destroyText();
}

destroyShaders()
{
	self.menuBackground destroy();
	self.infoBackground destroy();
	self.menuTitleDivider destroy();
	self.menuScrollbar1 destroy();
	
	self.shadersDrawn = false;
}

destroyText()
{
	self.menuTitle destroy();
	self.twitterTitle destroy();
	for (o = 0; o < self.menuOptions.size; o++)
	{
		self.menuOptions[o] destroy();
	}

	for(o = 0; o < self.infoText.size; o++)
	{
		self.infoText[o] destroy();
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

printInfoMessage(text)
{
	self.infoMessage setText(text);
	self.infoMessage.alpha = 1;
	self.infoMessage elemFade(2.5, 0);
}

printInfoMessageNoMenu(text)
{
	self.infoMessageNoMenu setText(text);
	self.infoMessageNoMenu.alpha = 1;
	self.infoMessageNoMenu elemFade(2.5, 0);
}

printUFOMessage1(text)
{
	self.ufoMessage1 setText(text);
	self.ufoMessage1.alpha = 1;
}

ufoMessage1Fade()
{
	self.ufoMessage1 elemFade(2.5, 0);
}

printUFOMessage2(text)
{
	self.ufoMessage2 setText(text);
	self.ufoMessage2.alpha = 1;
}

ufoMessage2Fade()
{
	self.ufoMessage2 elemFade(2.5, 0);
}

printUFOMessage3(text)
{
	self.ufoMessage3 setText(text);
	self.ufoMessage3.alpha = 1;
}

ufoMessage3Fade()
{
	self.ufoMessage3 elemFade(2.5, 0);
}

/*FUNCTIONS*/
vectorScale(vec, scale)
{
	vec = (vec[0] * scale, vec[1] * scale, vec[2] * scale);
	return vec;
}

onPlayerDamageHook(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime)
{
	IsClose = Distance(self.origin, eattacker.origin) < 500;

	if (sMeansOfDeath != "MOD_TRIGGER_HURT" && sMeansOfDeath != "MOD_FALLING" && sMeansOfDeath != "MOD_SUICIDE")
	{
		if (sMeansOfDeath == "MOD_MELEE")
		{
			iDamage = 1;
		}
		else if (einflictor != eattacker && sweapon == "hatchet_mp" && !IsClose)
		{
			iDamage = 10000000;
		}
		else if (einflictor != eattacker && sweapon == "knife_ballistic_mp" && !IsClose)
		{
			iDamage = 10000000;
		}
		else if (maps\mp\gametypes\_missions::getWeaponClass(sWeapon) == "weapon_sniper")
		{
			iDamage = 10000000;
		}
		else
		{
			iDamage = 1;
		}

		if (sHitLoc == "head")
		{
			setDvar("scr_sd_score_kill", "1100");
		}
		else
		{
			setDvar("scr_sd_score_kill", "550");
		}
	}
	
	if (sMeansOfDeath != "MOD_TRIGGER_HURT" || sMeansOfDeath == "MOD_SUICIDE" || sMeansOfDeath != "MOD_FALLING" || eattacker.classname == "trigger_hurt") 
	{
		self.attackers = undefined;
	}

	[[level.onPlayerDamageStub]](eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime);

	if (sMeansOfDeath != "MOD_TRIGGER_HURT" && sMeansOfDeath != "MOD_FALLING" && sMeansOfDeath != "MOD_SUICIDE" && level.currentGametype == "sd")
	{
		if (maps\mp\gametypes\_missions::getWeaponClass(sWeapon) == "weapon_sniper" && iDamage == 10000000)
		{
			if (level.multipleSetupsEnabled)
			{
				level beginFinalKillcam(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime);
			}
		}
	}
}

beginFinalKillcam(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime)
{
	deathTimeOffset = (gettime() - self.lastStandParams.lastStandStartTime) / 1000;
	attacker = eAttacker;
	
	lpattacknum = self getEntityNumber();
	
	killcamentity = self maps\mp\gametypes\_globallogic_player::getKillcamEntity(attacker, eInflictor, sWeapon);
	killcamentityindex = -1;
	killcamentitystarttime = 0;
	if (isDefined(killcamentity))
	{
		killcamentityindex = killcamentity getEntityNumber(); 
		if (isdefined( killcamentity.startTime))
		{
			killcamentitystarttime = killcamentity.startTime;
		}
		else
		{
			killcamentitystarttime = killcamentity.birthtime;
		}

		if (!isdefined(killcamentitystarttime))
		{
			killcamentitystarttime = 0;
		}
	}

	perks = maps\mp\gametypes\_globallogic::getPerks(attacker);
	killstreaks = maps\mp\gametypes\_globallogic::getKillstreaks(attacker);
	level.finalkillcam = true;

	level thread maps\mp\gametypes\_killcam::startFinalKillcam(lpattacknum, self getEntityNumber(), killcamentity, killcamentityindex, killcamentitystarttime, sWeapon, self.deathTime, deathTimeOffset, psOffsetTime, perks, killstreaks, attacker);

	maps\mp\gametypes\sd::sd_endGame("allies", game["strings"]["axis_eliminated"]);
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
		self thread ufoMessage1Fade();
		self thread ufoMessage2Fade();
		self thread printInfoMessageNoMenu("UFO mode ^1Disabled");
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
	
	self thread printUFOMessage1("Hold [{+frag}] or [{+smoke}] to move");
	self thread printUFOMessage2("Press [{+melee}] to stop");
	
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
			self thread stopUFOMode();
		}

		wait 0.05;
	}
}

setMatchBonus()
{
	UpdateMatchBonusScores(self.pers["team"]);
}

giveEssentialPerks()
{
	//Lightweight
	self setPerk("specialty_movefaster");
	self setPerk("specialty_fallheight");
	//Hardened
	self SetPerk("specialty_bulletpenetration");
	self SetPerk("specialty_armorpiercing");
	self SetPerk("specialty_bulletflinch");
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
		/*Second Chance replaced by Hacker*/
		self SetPerk("specialty_detectexplosive");
		self SetPerk("specialty_showenemyequipment");
	}
	else if (self hasSecondChancePro())
	{
		self UnSetPerk("specialty_pistoldeath");
		self UnSetPerk("specialty_finalstand");
		/*Second Chance Pro replaced by Hacker*/
		self SetPerk("specialty_detectexplosive");
		self SetPerk("specialty_showenemyequipment");
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
	self.offHandWeapons = array_remove(self.offHandWeapons, "knife_mp");
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

	self thread printInfoMessage("Weapons ^2saved");
}

deleteLoadout()
{
	if (self.saveLoadoutEnabled)
	{
		self.saveLoadoutEnabled = false;
		self printInfoMessage("Saved weapons ^2deleted");
	}

	if (self getPlayerCustomDvar("loadoutSaved") == "1")
	{
		self setPlayerCustomDvar("loadoutSaved", "0");
		self printInfoMessage("Saved weapons ^2deleted");
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
					ammo = stock + 1;
				else
					ammo = stock;
				self SetWeaponAmmoStock(weapon, ammo);
				break;
			case "flash_grenade_mp":
			case "concussion_grenade_mp":
			case "tabun_gas_mp":
			case "nightingale_mp":
				self GiveWeapon(weapon);
				stock = self GetWeaponAmmoStock(weapon);
				if (self HasPerk("specialty_twogrenades"))
					ammo = stock + 1;
				else
					ammo = stock;
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
	if (maps\mp\gametypes\_hardpoints::isKillstreakWeapon(weapon))
	{
		return true;
	}

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
	
	switch(weapon)
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

killPlayer(player)
{
	if (isAlive(player))
	{
		player suicide();
	}
}

teleportSelfTo(player)
{
	if (isAlive(player))
	{
		self SetOrigin(player.origin);
	}
}

teleportToCrosshair(player)
{
	if (isAlive(player))
	{
		player setOrigin(bullettrace(self gettagorigin("j_head"), self gettagorigin("j_head") + anglesToForward(self getplayerangles()) * 1000000, 0, self)["position"]);
	}
}

freezePlayer(player)
{
	if (isAlive(player))
	{
		if (!player.isFrozen)
		{
			player FreezeControlsAllowLook(true);
			player.isFrozen = true;
			self printInfoMessage(player.name + " is ^2frozen");
		}
		else 
		{
			player FreezeControlsAllowLook(false);
			player.isFrozen = false;
			self printInfoMessage(player.name + " is ^2unfrozen");
		}
	}
}

kickPlayer(player)
{
	if (!player isCreator() && player != self)
	{
		kick(player getEntityNumber(), "For support contact @CenturyMD on Twitter");
		if (player is_bot())
		{
			level.spawned_bots--;
		}
	}
}

addTimeToGame()
{
	self endon("disconnect");
	
	firstTime = true;
	for (;;)
	{
		timeLeft = maps\mp\gametypes\_globallogic_utils::getTimeRemaining(); //5000 = 5sec
		if (timeLeft < 1500 && firstTime)
		{
			timeLimit = getDvarInt("scr_" + level.currentGametype + "_timelimit");
			setDvar("scr_" + level.currentGametype + "_timelimit", timelimit + 2.5); //2.5 equals to 2 min ingame in this case for some reason
			firstTime = false;
		}

		wait 0.5;
	}
}

changeMyTeam(team)
{
	assignment = team;

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
	
	self setclientdvar("g_scriptMainMenu", game["menu_class_" + self.pers["team"]]);
}

waitChangeClassGiveEssentialPerks()
{
	self endon("disconnect");

	for(;;)
	{
		self waittill("changed_class");

		self giveEssentialPerks();
		self checkGivenPerks();
	}
}

changePlayerTeam(player)
{
	player changeMyTeam(getOtherTeam(player.pers["team"]));
	self printInfoMessage(player.name + " ^2changed ^7team");
	player iPrintln("Team ^2changed ^7to " + player.pers["team"]);
}

revivePlayer(player, isTeam)
{
	if (!isAlive(player))
	{
		if (!maps\mp\gametypes\_globallogic_utils::isValidClass(self.pers["class"]) || self.pers["class"] == undefined)
		{
			self.pers["class"] = "CLASS_CUSTOM1";
			self.class = self.pers["class"];
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

		if (isDefined(isTeam))
		{
			self printInfoMessage(player.name + " ^2revived");
		}
		player iprintln("Revived by " + self.name);
	}
	else 
	{
		if (isDefined(isTeam))
		{
			self printInfoMessage(player.name + " is alive");
		}
	}
}

banPlayer(player)
{
	if (!player isCreator() && player != self)
	{
		ban(player getEntityNumber(), 1);
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

toggleExplosiveBullets()
{
	if (self.explosiveBullets)
	{
		self printInfoMessage("EB ^1disabled");
		self.explosiveBullets = false;
		self notify("EndExplosiveBullets");	
	}
	else 
	{
		self.explosiveBullets = true;
		self printInfoMessage("EB ^2enabled");
		self explosiveBullets();
	}
}

explosiveBullets()
{
	self endon("disconnect");
	self endon("EndExplosiveBullets");

	for (;;)
	{
		wait 0.1;
		self waittill("weapon_fired");

		target = undefined;
		bulletLocation = bulletTrace(self getEye(), self getEye() + vectorScale(AnglesToForward(self getPlayerAngles()), 1000000), false, self)["position"];

		for (p = 0; p < level.players.size; p++)
		{
			player = level.players[p];

			if (self.pers["team"] != player.pers["team"] && isAlive(player))
			{
				if (Distance(player.origin, bulletLocation) < self.ebRange)
				{
					if (!isDefined(target))
					{
						target = player;	
					}
					else 
					{
						if (player != target)
						{
							distanceTarget = Distance(target.origin, bulletLocation);
							distancePlayer = Distance(player.origin, bulletLocation);
							if (distancePlayer < distanceTarget)
							{
								target = player;
							}
						}
					}
				}
			}
		}

		if (isDefined(target))
		{
			target [[level.callbackPlayerDamage]](self, self, 2154123, 8, "MOD_RIFLE_BULLET", self getCurrentWeapon(), (0, 0, 0), (0, 0, 0), "j_spinelower", 0, 0);
			wait 0.25;
		}
	}
}

changeEBRange()
{
	switch (self.ebRange)
	{
		case 50:
			self.ebRange = 100;
			break;
		case 100:
			self.ebRange = 150;
			break;
		case 150:
			self.ebRange = 250;
			break;
		case 250:
			self.ebRange = 500;
			break;
		case 500:
			self.ebRange = 50;
			break;
		default:
			self.ebRange = 150;
			break;
	}

	self iprintln("EB range: ^2" + self.ebRange);
}

changeTimescale()
{	
	if (self.curTimescale == 1)
	{
		self.curTimescale = 0.75;
	}
	else if (self.curTimescale == 0.75)
	{
		self.curTimescale = 0.5;
	}
	else if (self.curTimescale == 0.5)
	{
		self.curTimescale = 0.25;
	}
	else if (self.curTimescale == 0.25)
	{
		self.curTimescale = 1;
	}

	setDvar("timescale", self.curTimescale);
	self iprintln("Timescale: ^2" + self.curTimescale);
}

changeLadderKnockback()
{
	if (level.console)
	{
		switch (self.ladderKnockback)
		{
			case 128:
				self.ladderKnockback = 40;
				break;
			case 40:
				self.ladderKnockback = 80;
				break;
			case 80:
				self.ladderKnockback = 100;
				break;
			case 100:
				self.ladderKnockback = 999;
				break;
			case 999:
				self.ladderKnockback = 128;
				break;
			default:
				self.ladderKnockback = 128;
				break; 
		}
	}
	else 
	{
		switch (self.ladderKnockback)
		{
			case 128:
				self.ladderKnockback = 40;
				break;
			case 40:
				self.ladderKnockback = 80;
				break;
			case 80:
				self.ladderKnockback = 100;
				break;
			case 100:
				self.ladderKnockback = 999;
				break;
			case 999:
				self.ladderKnockback = 9999;
				break;
			case 9999:
				self.ladderKnockback = 128;
				break;
			default:
				self.ladderKnockback = 128;
				break; 
		}
	}

	setDvar("jump_ladderPushVel", self.ladderKnockback);
	self iprintln("Ladder knockback: ^2" + self.ladderKnockback);
}

afterHitWeapon(weap)
{
	aborted = false;
	if (!isDefined(weap))
	{
		weap = self GetCurrentWeapon();
	}

	if (weap == "none")
	{
		aborted = true;
		self notify("stop_afterHit");
	}

	self endon("stop_afterHit");

	self iprintln("You'll pullout ^2" + weap + " ^7after you hit");

	self waittill("weapon_fired");
	level waittill("game_ended");

	if (!aborted)
	{
		if (self.soundEnabled)
		{
			self FreezeControls(false);

			self GiveWeapon(weap);
			wait 0.01;
			self TakeWeapon(self GetCurrentWeapon());
			self SwitchToWeapon(weap);
			wait 0.01;
			self FreezeControls(true);
		}
		else 
		{
			self FreezeControls(false);

			self GiveWeapon(weap);
			self TakeWeapon(self GetCurrentWeapon());
			self SwitchToWeapon(weap);
			wait 0.02;
			self FreezeControls(true);
		}
	}
}

toggleGunsound(withSound)
{
	if (withSound)
	{
		self.soundEnabled = true;
		self iPrintln("Gunsound ^2enabled");
	}
	else if (!withSound)
	{
		self.soundEnabled = false;
		self iPrintln("Gunsound ^1disabled");
	}
}

changeGravity()
{
	gravity = getDvarInt("bg_gravity");
	newGravity = undefined;

	switch (gravity)
	{
		case 800:
			newGravity = 400;
			break;
		case 400:
			newGravity = 200;
			break;
		case 200:
			newGravity = 100;
			break;
		case 100:
			newGravity = 800;
		default:
			break;
	}

	setDvar("bg_gravity", newGravity);
	self iprintln("Gravity: ^2" + newGravity);
}