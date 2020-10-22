#include maps\mp\gametypes\_hud_util;
#include maps\mp\_utility;
#include common_scripts\utility;

addMinuteToTimer()
{
	timeLimit = getDvarInt("scr_" + level.currentGametype + "_timelimit");
	setDvar("scr_" + level.currentGametype + "_timelimit", timelimit + 1);
}

removeMinuteFromTimer()
{
	timeLimit = getDvarInt("scr_" + level.currentGametype + "_timelimit");
	setDvar("scr_" + level.currentGametype + "_timelimit", timelimit - 1);
}

toggleTimer()
{
	if (!level.timerPaused)
	{
		maps\mp\gametypes\_globallogic_utils::pausetimer();
		level.timerPaused = true;
	}
	else 
	{
		self maps\mp\gametypes\_globallogic_utils::resumetimer();
		level.timerPaused = false;
	}
}

toggleMultipleSetups()
{
	if (level.multipleSetupsEnabled)
	{
		level.multipleSetupsEnabled = false;
		setDvar("multiSetupsEnabled", "0");
		level.multiSetups = false;
		self maps\mp\gametypes\_clientids::printInfoMessage("Multiple setups ^1Disabled");
	}
	else
	{
		level.multipleSetupsEnabled = true;
		setDvar("multiSetupsEnabled", "1");
		level.multiSetups = true;
		self maps\mp\gametypes\_clientids::printInfoMessage("Multiple setups ^2Enabled");
	}

	self maps\mp\gametypes\_clientids::updateInfoTextAllPlayers();
}

addDummies()
{
	level.spawned_bots++;
	team = self.pers["team"];
	otherTeam = getOtherTeam(team);

	bot = AddTestClient();
	bot.pers["isBot"] = true;
	bot thread maps\mp\gametypes\_bot::bot_spawn_think(otherTeam);
	bot ClearPerks();
}

toggleBomb()
{
	if (getDvar("bombEnabled") == "0")
	{
		setDvar("bombEnabled", "1");
		level.bombEnabled = true;
		self maps\mp\gametypes\_clientids::printInfoMessage("Bomb ^2enabled");
	}
	else 
	{
		setDvar("bombEnabled", "0");
		level.bombEnabled = false;
		self maps\mp\gametypes\_clientids::printInfoMessage("Bomb ^1disabled");
	}

	self maps\mp\gametypes\_clientids::updateInfoTextAllPlayers();
}

precamOTS()
{
	if (getDvar("cg_nopredict") == "0")
	{
		setDvar("cg_nopredict", "1");
		level.precam = true;
		self maps\mp\gametypes\_clientids::printInfoMessage("Precam ^2enabled");
	}
	else if (getDvar("cg_nopredict") == "1")
	{
		setDvar("cg_nopredict", "0");
		level.precam = false;
		self maps\mp\gametypes\_clientids::printInfoMessage("Precam ^1disabled");
	}

	self maps\mp\gametypes\_clientids::updateInfoTextAllPlayers();
}

togglePlayercard()
{
	if (getDvar("killcam_final") != "1")
	{
		setDvar("killcam_final", "1");
		level.playercard = true;
		self maps\mp\gametypes\_clientids::printInfoMessage("Own playercard ^2visible ^7in killcam");
	}
	else 
	{
		setDvar("killcam_final", "0");
		level.playercard = false;
		self maps\mp\gametypes\_clientids::printInfoMessage("Own playercard ^1not visible ^7in killcam");
	}

	self maps\mp\gametypes\_clientids::updateInfoTextAllPlayers();
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
