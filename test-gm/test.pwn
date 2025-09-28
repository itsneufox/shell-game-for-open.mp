#include <open.mp>
#include <shellgame_api>

new
    PlayerMoney[MAX_PLAYERS]
;

main()
{
    printf("  ----------------------------------");
    printf("  |  test gamemode initialised! |");
    printf("  ----------------------------------");
}

public OnGameModeInit()
{
    SetGameModeText("shell game test");
    AddPlayerClass(0, 2495.3547, -1688.2319, 13.6774, 351.1646, WEAPON_M4, 500, WEAPON_KNIFE, 1, WEAPON_COLT45, 100);
    AddStaticVehicle(522, 2493.7583, -1683.6482, 12.9099, 270.8069, -1, -1);

    // Create shell game tables
    printf("[GAMEMODE] Initialising shell game tables...");
    CreateShellGameTable(0, 1465.75060, -1661.72693, 13.45120, 90.0);
    CreateShellGameTable(1, 1466.1078, -1654.0469, 13.4512, 180.0);
    CreateShellGameTable(2, 1459.5853, -1657.5963, 13.4512, 270.0);
    CreateShellGameTable(3, 1460.1467, -1664.1534, 13.4512, 45.0);
    printf("[GAMEMODE] All shell game tables initialised!");

    return true;
}

public OnGameModeExit()
{
    printf("[GAMEMODE] Cleaning up shell game tables...");
    CleanupShellGameTables();
    printf("[GAMEMODE] Shell game table cleanup complete!");
    return true;
}

public OnPlayerConnect(playerid)
{
    PlayerMoney[playerid] = 10000;
    GivePlayerMoney(playerid, 10000);
    return true;
}

public OnPlayerDisconnect(playerid, reason)
{
    return true;
}

public OnPlayerRequestClass(playerid, classid)
{
    SetPlayerPos(playerid, 217.8511, -98.4865, 1005.2578);
    SetPlayerFacingAngle(playerid, 113.8861);
    SetPlayerInterior(playerid, 15);
    SetPlayerCameraPos(playerid, 215.2182, -99.5546, 1006.4);
    SetPlayerCameraLookAt(playerid, 217.8511, -98.4865, 1005.2578);
    return true;
}

public OnPlayerSpawn(playerid)
{
    SetPlayerInterior(playerid, 0);
    return true;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason)
{
    return true;
}

//==============================================================================================================================================================
//
//      ** SHELL GAME CONFIGURATION **
//      Configure shell game economy settings here
//
//==============================================================================================================================================================

// Shell game economy settings
#define SHELL_GAME_BASE_PRICE 100        // Base price for level 1 (level 2 = 200, level 3 = 300, etc.)
#define SHELL_GAME_WIN_MULTIPLIER 2      // Winnings = bet * multiplier

//==============================================================================================================================================================
//
//      ** SHELL GAME API IMPLEMENTATION **
//      Handles payments and money management for the shell game
//
//==============================================================================================================================================================

/**
 * Called to check if a player has enough money for the bet
 */
public OnShellGameCheckMoney(playerid, tableid, amount)
{
    if (GetPlayerMoney(playerid) >= amount)
    {
        return true;
    }
    else
    {
        return false;
    }
}

/**
 * Called when a shell game starts
 */
public OnShellGameStart(playerid, tableid, level, betAmount)
{
    printf("[SHELL GAME] Player %d started shell game at table %d - Level %d, Bet $%d", playerid, tableid, level, betAmount);
    return true;
}

/**
 * Called when a shell game ends
 */
public OnShellGameEnd(playerid, tableid, level, totalWinnings)
{
    printf("[SHELL GAME] Player %d ended shell game at table %d - Level %d, Total $%d", playerid, tableid, level, totalWinnings);
    return true;
}

/**
 * Called when a player levels up in the shell game
 */
public OnShellGameLevelUp(playerid, tableid, newLevel)
{
    new
        message[128]
    ;
    format(message, sizeof(message), "Congratulations! You've reached level %d!", newLevel);
    SendClientMessage(playerid, 0xFFFF00FF, message);
    printf("[SHELL GAME] Player %d levelled up to level %d at table %d", playerid, newLevel, tableid);
    return true;
}

/**
 * Called when a player needs to pay for a bet
 */
public OnShellGamePayment(playerid, tableid, amount)
{
    GivePlayerMoney(playerid, -amount);
    printf("[SHELL GAME] Player %d paid $%d at table %d", playerid, amount, tableid);
    return true;
}

/**
 * Called when a player wins and needs to be paid
 */
public OnShellGamePayout(playerid, tableid, amount)
{
    GivePlayerMoney(playerid, amount);
    printf("[SHELL GAME] Player %d won $%d at table %d", playerid, amount, tableid);
    return true;
}

/**
 * Called to get the base price for level 1 (filterscript multiplies by level)
 */
public OnShellGameGetBasePrice()
{
    return SHELL_GAME_BASE_PRICE; // $100 base price
}

/**
 * Called to get the win multiplier
 */
public OnShellGameGetWinMultiplier()
{
    return SHELL_GAME_WIN_MULTIPLIER; // 2x multiplier
}

/**
 * Called to get a player's current table (handled by filterscript)
 */
public OnShellGameGetPlayerTable(playerid)
{
    return -1; // This should never be called directly, handled by filterscript
}

//==============================================================================================================================================================
//
//      ** COMMANDS **
//
//==============================================================================================================================================================

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (strcmp("/shellgame", cmdtext, true, 10) == 0) {
        // Teleport to shell game area
        SetPlayerPos(playerid, 1465.75, -1661.73, 13.45);
        SetPlayerFacingAngle(playerid, 180.0);
        SendClientMessage(playerid, 0x00FF00FF, "Welcome to the Shell Game! Walk up to any table and press SPACE to play!");
        return true;
    }

    return false;
}