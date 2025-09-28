/*
*     /$$$$$$  /$$   /$$ /$$$$$$$$ /$$       /$$              /$$$$$$   /$$$$$$  /$$      /$$ /$$$$$$$$        /$$$$$$  /$$$$$$$  /$$$$$$
*    /$$__  $$| $$  | $$| $$_____/| $$      | $$             /$$__  $$ /$$__  $$| $$$    /$$$| $$_____/       /$$__  $$| $$__  $$|_  $$_/
*   | $$  \__/| $$  | $$| $$      | $$      | $$            | $$  \__/| $$  \ $$| $$$$  /$$$$| $$            | $$  \ $$| $$  \ $$  | $$  
*   |  $$$$$$ | $$$$$$$$| $$$$$   | $$      | $$            | $$ /$$$$| $$$$$$$$| $$ $$/$$ $$| $$$$$         | $$$$$$$$| $$$$$$$/  | $$  
*    \____  $$| $$__  $$| $$__/   | $$      | $$            | $$|_  $$| $$__  $$| $$  $$$| $$| $$__/         | $$__  $$| $$____/   | $$  
*    /$$  \ $$| $$  | $$| $$      | $$      | $$            | $$  \ $$| $$  | $$| $$\  $ | $$| $$            | $$  | $$| $$        | $$  
*   |  $$$$$$/| $$  | $$| $$$$$$$$| $$$$$$$$| $$$$$$$$      |  $$$$$$/| $$  | $$| $$ \/  | $$| $$$$$$$$      | $$  | $$| $$       /$$$$$$
*    \______/ |__/  |__/|________/|________/|________/       \______/ |__/  |__/|__/     |__/|________/      |__/  |__/|__/      |______/
*
*   By itsneufox @2025 | https://github.com/itsneufox | https://itsneufox.xyz
*/                                                                                                                                    
//==============================================================================================================================================================
//
//      ** SHELL GAME API **
//      Integration hooks for external payment systems
//      Include this file in your gamemode to handle shell game payments
//      If you can read this: avPr, wfv ohmrenag.
//
//==============================================================================================================================================================

#if defined _INC_shellgame_api
    #endinput
#endif
#define _INC_shellgame_api

//==============================================================================================================================================================
//
//      ** CONSTANTS **
//
//==============================================================================================================================================================

// Maximum number of tables supported
#define MAX_TABLES 10

//==============================================================================================================================================================
//
//      ** GLOBAL VARIABLES **
//
//==============================================================================================================================================================


//==============================================================================================================================================================
//
//      ** FORWARD DECLARATIONS **
//
//==============================================================================================================================================================

/**
 * Called when a player needs to pay the bet amount to start playing
 *
 * @param playerid The player who wants to play
 * @param tableid The table where the payment is happening
 * @param amount The bet amount required
 * @return true if payment successful, false if failed
 */
forward OnShellGamePayment(playerid, tableid, amount);

/**
 * Called when a player wins and should receive winnings
 *
 * @param playerid The player who won
 * @param tableid The table where the payout happened
 * @param amount The winnings amount
 * @return true if payout successful, false if failed
 */
forward OnShellGamePayout(playerid, tableid, amount);

/**
 * Called to check if a player has enough money for the bet
 *
 * @param playerid The player to check
 * @param tableid The table where the check is happening
 * @param amount The amount to check
 * @return true if player has enough money, false if not
 */
forward OnShellGameCheckMoney(playerid, tableid, amount);

/**
 * Called when a shell game starts
 *
 * @param playerid The player starting the game
 * @param tableid The table where the game started
 * @param level The current level
 * @param betAmount The bet amount for this level
 */
forward OnShellGameStart(playerid, tableid, level, betAmount);

/**
 * Called when a shell game ends
 *
 * @param playerid The player who finished the game
 * @param tableid The table where the game ended
 * @param level The level that was completed
 * @param totalWinnings The total winnings accumulated
 */
forward OnShellGameEnd(playerid, tableid, level, totalWinnings);

/**
 * Called when a player levels up in the shell game
 *
 * @param playerid The player who leveled up
 * @param tableid The table where they leveled up
 * @param newLevel The new level they reached
 */
forward OnShellGameLevelUp(playerid, tableid, newLevel);

/**
 * Called to get the base price for level 1
 *
 * @return Base price (will be multiplied by level in filterscript)
 */
forward OnShellGameGetBasePrice();

/**
 * Called to get the win multiplier
 *
 * @return Win multiplier value
 */
forward OnShellGameGetWinMultiplier();


/**
 * Called to get a player's current table
 *
 * @param playerid The player to check
 * @return The table ID the player is at, or -1 if not at any table
 */
forward OnShellGameGetPlayerTable(playerid);


//==============================================================================================================================================================
//
//      ** API FUNCTIONS **
//      Call these functions from the shell game filterscript
//
//==============================================================================================================================================================

/**
 * Process payment for shell game bet
 *
 * @param playerid The player making the payment
 * @param tableid The table where the payment is happening
 * @param amount The bet amount
 * @return true if successful, false if failed
 */
stock ShellGame_ProcessPayment(playerid, tableid, amount)
{
    if (!CallRemoteFunction("OnShellGameCheckMoney", "iii", playerid, tableid, amount))
        return false;

    return CallRemoteFunction("OnShellGamePayment", "iii", playerid, tableid, amount);
}

/**
 * Process payout for shell game winnings
 *
 * @param playerid The player receiving the payout
 * @param tableid The table where the payout is happening
 * @param amount The winnings amount
 * @return true if successful, false if failed
 */
stock ShellGame_ProcessPayout(playerid, tableid, amount)
{
    return CallRemoteFunction("OnShellGamePayout", "iii", playerid, tableid, amount);
}

/**
 * Check if player has enough money for bet
 *
 * @param playerid The player to check
 * @param tableid The table where the check is happening
 * @param amount The amount to check
 * @return 1 if player has enough, 0 if not
 */
stock ShellGame_CheckMoney(playerid, tableid, amount)
{
    return CallRemoteFunction("OnShellGameCheckMoney", "iii", playerid, tableid, amount);
}

/**
 * Get base price from gamemode configuration
 *
 * @return Base price for level 1
 */
stock ShellGame_GetBasePrice()
{
    return CallRemoteFunction("OnShellGameGetBasePrice", "");
}

/**
 * Get win multiplier from gamemode configuration
 *
 * @return Multiplier for calculating winnings
 */
stock ShellGame_GetWinMultiplier()
{
    return CallRemoteFunction("OnShellGameGetWinMultiplier", "");
}

/**
 * Get shell game table position from gamemode configuration
 *
 * @param tableid Table ID
 * @param x Float reference for X coordinate
 * @param y Float reference for Y coordinate
 * @param z Float reference for Z coordinate
 * @param angle Float reference for rotation angle
 * @return true if successful, false if failed
 */
stock ShellGame_GetTablePosition(tableid, &Float:x, &Float:y, &Float:z, &Float:angle)
{
    // Read the values from server variables (set by gamemode during initialization)
    new
        string[64]
    ;

    format(string, sizeof(string), "TablePosX_%d", tableid);
    x = GetSVarFloat(string);
    
    // Check if table exists (if X coordinate is 0, assume table doesn't exist)
    if (x == 0.0) {
        format(string, sizeof(string), "TablePosY_%d", tableid);

        new
            Float:testY = GetSVarFloat(string)
        ;

        format(string, sizeof(string), "TablePosZ_%d", tableid);
        
        new
            Float:testZ = GetSVarFloat(string)
        ;
        
        // If all coordinates are 0, table doesn't exist
        if (testY == 0.0 && testZ == 0.0) {
            return false;
        }
    }
    
    format(string, sizeof(string), "TablePosY_%d", tableid);
    y = GetSVarFloat(string);
    
    format(string, sizeof(string), "TablePosZ_%d", tableid);
    z = GetSVarFloat(string);
    
    format(string, sizeof(string), "TablePosAngle_%d", tableid);
    angle = GetSVarFloat(string);
    
    return true;
}

/**
 * Create a new shell game table at specified coordinates
 *
 * @param tableid Table ID (0 to MAX_TABLES-1)
 * @param x X coordinate
 * @param y Y coordinate
 * @param z Z coordinate
 * @param angle Rotation angle (default: 0.0)
 * @return true if successful, false if failed
 */
stock CreateShellGameTable(tableid, Float:x, Float:y, Float:z, Float:angle = 0.0)
{
    if (tableid < 0 || tableid >= MAX_TABLES) {
        printf("[SHELL GAME API] ERROR: Invalid table ID %d (must be 0-%d)", tableid, MAX_TABLES - 1);
        return false;
    }

    new
        string[64]
    ;

    format(string, sizeof(string), "TablePosX_%d", tableid);
    SetSVarFloat(string, x);
    format(string, sizeof(string), "TablePosY_%d", tableid);
    SetSVarFloat(string, y);
    format(string, sizeof(string), "TablePosZ_%d", tableid);
    SetSVarFloat(string, z);
    format(string, sizeof(string), "TablePosAngle_%d", tableid);
    SetSVarFloat(string, angle);

    printf("[SHELL GAME API] Table %d created at (%.2f, %.2f, %.2f) with angle %.2f", tableid, x, y, z, angle);
    return true;
}

/**
 * Remove a specific shell game table
 *
 * @param tableid Table ID to remove (0 to MAX_TABLES-1)
 * @return true if successful, false if failed
 */
stock RemoveShellGameTable(tableid)
{
    if (tableid < 0 || tableid >= MAX_TABLES) {
        printf("[SHELL GAME API] ERROR: Invalid table ID %d (must be 0-%d)", tableid, MAX_TABLES - 1);
        return false;
    }

    new
        string[64]
    ;

    format(string, sizeof(string), "TablePosX_%d", tableid);
    DeleteSVar(string);
    format(string, sizeof(string), "TablePosY_%d", tableid);
    DeleteSVar(string);
    format(string, sizeof(string), "TablePosZ_%d", tableid);
    DeleteSVar(string);
    format(string, sizeof(string), "TablePosAngle_%d", tableid);
    DeleteSVar(string);

    printf("[SHELL GAME API] Table %d removed", tableid);
    return true;
}

/**
 * Remove all shell game tables
 *
 * @return Number of tables cleaned up
 */
stock CleanupShellGameTables()
{
    printf("[SHELL GAME API] Cleaning up all table position server variables...");

    new
        cleaned = 0
    ;
    for(new tableid = 0; tableid < MAX_TABLES; tableid++) {
        if (RemoveShellGameTable(tableid)) {
            cleaned++;
        }
    }

    printf("[SHELL GAME API] %d table position variables cleaned up!", cleaned);
    return cleaned;
}