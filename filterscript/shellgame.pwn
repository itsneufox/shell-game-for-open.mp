/*
*     /$$$$$$  /$$   /$$ /$$$$$$$$ /$$       /$$              /$$$$$$   /$$$$$$  /$$      /$$ /$$$$$$$$
*    /$$__  $$| $$  | $$| $$_____/| $$      | $$             /$$__  $$ /$$__  $$| $$$    /$$$| $$_____/
*   | $$  \__/| $$  | $$| $$      | $$      | $$            | $$  \__/| $$  \ $$| $$$$  /$$$$| $$
*   |  $$$$$$ | $$$$$$$$| $$$$$   | $$      | $$            | $$ /$$$$| $$$$$$$$| $$ $$/$$ $$| $$$$$
*    \____  $$| $$__  $$| $$__/   | $$      | $$            | $$|_  $$| $$__  $$| $$  $$$| $$| $$__/
*    /$$  \ $$| $$  | $$| $$      | $$      | $$            | $$  \ $$| $$  | $$| $$\  $ | $$| $$
*   |  $$$$$$/| $$  | $$| $$$$$$$$| $$$$$$$$| $$$$$$$$      |  $$$$$$/| $$  | $$| $$ \/  | $$| $$$$$$$$
*    \______/ |__/  |__/|________/|________/|________/       \______/ |__/  |__/|__/     |__/|________/
*
*   By itsneufox @2025 | https://github.com/itsneufox | https://itsneufox.xyz
*/
//==============================================================================================================================================================
//
//      ** SHELL GAME **
//      A multi-table shell game where players bet on which shell contains the ball
//      Features infinite levels with progressive difficulty and speed scaling
//      If you can read this: avPr, wfv ohmrenag.
//
//==============================================================================================================================================================

#define FILTERSCRIPT

#include <open.mp>
#include <streamer>
#include "shellgame_api"

//==============================================================================================================================================================
//
//      ** CONSTANTS **
//
//==============================================================================================================================================================

// Sound effect IDs for game feedback
#define SOUND_WIN 31205
#define SOUND_LOSE 31202
#define SOUND_RING_MOVE 6400
#define SOUND_SELECT 14405

// Game instruction and status messages
#define MSG_GAME_READY "Use LEFT/RIGHT arrows to move selection~n~~k~~PED_JUMPING~ to choose~n~~k~~VEHICLE_ENTER_EXIT~ to exit"
#define MSG_GAME_IN_PROGRESS "A shell game is already in progress at this table!"
#define MSG_SHUFFLING_WAIT "This table is shuffling! Please wait..."
#define MSG_INSUFFICIENT_MONEY "You need $%d to play level %d!"
#define MSG_PAYMENT_FAILED "Payment failed! Please try again."
#define MSG_WELCOME "Welcome to Shell Game!~n~Press ~k~~PED_JUMPING~ to start"
#define MSG_TELEPORT_WELCOME "Welcome to the Shell Game! Walk up to any table and press ~k~~PED_JUMPING~ to play!"
#define MSG_CANNOT_EXIT "Cannot exit during shuffle or reveal!"

//==============================================================================================================================================================
//
//      ** TABLE DATA STRUCTURE **
//
//==============================================================================================================================================================

enum E_TABLE_STATE {
    TABLE_STATE_IDLE,
    TABLE_STATE_SHUFFLING,
    TABLE_STATE_PLAYING,
    TABLE_STATE_REVEALING 
}

enum E_TABLE_DATA {
    // Table position and objects
    Float:TABLE_X, Float:TABLE_Y, Float:TABLE_Z, Float:TABLE_ANGLE,
    TABLE_OBJECT, SHELL_OBJECTS[3], BALL_OBJECT, RING_OBJECT, ACTOR_OBJECT,

    // Game state
    E_TABLE_STATE:TABLE_STATE, TABLE_PLAYER, TABLE_LEVEL, TABLE_BET_AMOUNT, TABLE_PLAYER_WINNINGS,
    Float:TABLE_CURRENT_SPEED,

    // Shell tracking (which shell is where)
    TABLE_BALL_POSITION, TABLE_SHELL_AT_CENTER, TABLE_SHELL_AT_LEFT, TABLE_SHELL_AT_RIGHT,
    TABLE_CURRENT_SELECTION, TABLE_SELECTED_SHELL, bool:TABLE_SELECTION_ALLOWED,

    // Shuffling mechanics
    TABLE_SHUFFLE_COUNT, TABLE_MAX_SHUFFLES, TABLE_PLAYER_BETS[3], TABLE_TOTAL_BET_AMOUNT,
    bool:TABLE_IS_ROTATING,

    // Movement animation data
    TABLE_MOVING_OBJECT1, TABLE_MOVING_OBJECT2, TABLE_CIRCULAR_SHELL1, TABLE_CIRCULAR_SHELL2,
    Float:TABLE_CIRCULAR_CENTER_X, Float:TABLE_CIRCULAR_CENTER_Y,
    Float:TABLE_CIRCULAR_POS1_X, Float:TABLE_CIRCULAR_POS1_Y,
    Float:TABLE_CIRCULAR_POS2_X, Float:TABLE_CIRCULAR_POS2_Y,
    Float:TABLE_CIRCULAR_ANGLE, Float:TABLE_CIRCULAR_FINAL_Y,
    TABLE_CIRCULAR_STEP, bool:TABLE_REVERSE_MOVEMENT, TABLE_SWAP_TYPE, TABLE_ENDING_PLAYER,

    // Shell positions after shuffling
    Float:TABLE_SHUFFLED_POS_CENTER_X, Float:TABLE_SHUFFLED_POS_CENTER_Y,
    Float:TABLE_SHUFFLED_POS_LEFT_X, Float:TABLE_SHUFFLED_POS_LEFT_Y,
    Float:TABLE_SHUFFLED_POS_RIGHT_X, Float:TABLE_SHUFFLED_POS_RIGHT_Y
}

new
    g_TableData[MAX_TABLES][E_TABLE_DATA]
;

new
    g_PlayerCurrentTable[MAX_PLAYERS],
    PlayerText:g_ShellGameTextDraw[MAX_PLAYERS],
    g_TextDrawTimer[MAX_PLAYERS],
    g_LastSelectionTime[MAX_PLAYERS]
;

new
    g_ProximityTimer = -1,
    g_SelectionTimer = -1,
    g_HandshakeRetryCount = 0
;

//==============================================================================================================================================================
//
//      ** TABLE UTILITY FUNCTIONS **
//
//==============================================================================================================================================================

// Reset table to default state
stock InitializeTable(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    g_TableData[tableid][TABLE_STATE] = TABLE_STATE_IDLE;
    g_TableData[tableid][TABLE_PLAYER] = INVALID_PLAYER_ID;
    g_TableData[tableid][TABLE_LEVEL] = 1;
    g_TableData[tableid][TABLE_BET_AMOUNT] = 0;
    g_TableData[tableid][TABLE_PLAYER_WINNINGS] = 0;
    g_TableData[tableid][TABLE_CURRENT_SPEED] = 1.0;

    g_TableData[tableid][TABLE_BALL_POSITION] = 1;
    g_TableData[tableid][TABLE_SHELL_AT_CENTER] = 1;
    g_TableData[tableid][TABLE_SHELL_AT_LEFT] = 2;
    g_TableData[tableid][TABLE_SHELL_AT_RIGHT] = 3;
    g_TableData[tableid][TABLE_CURRENT_SELECTION] = 1;
    g_TableData[tableid][TABLE_SELECTED_SHELL] = 0;
    g_TableData[tableid][TABLE_SELECTION_ALLOWED] = false;

    g_TableData[tableid][TABLE_SHUFFLE_COUNT] = 0;
    g_TableData[tableid][TABLE_MAX_SHUFFLES] = 5;
    g_TableData[tableid][TABLE_PLAYER_BETS][0] = 0;
    g_TableData[tableid][TABLE_PLAYER_BETS][1] = 0;
    g_TableData[tableid][TABLE_PLAYER_BETS][2] = 0;
    g_TableData[tableid][TABLE_TOTAL_BET_AMOUNT] = 0;
    g_TableData[tableid][TABLE_IS_ROTATING] = false;

    g_TableData[tableid][TABLE_MOVING_OBJECT1] = INVALID_OBJECT_ID;
    g_TableData[tableid][TABLE_MOVING_OBJECT2] = INVALID_OBJECT_ID;
    g_TableData[tableid][TABLE_CIRCULAR_SHELL1] = INVALID_OBJECT_ID;
    g_TableData[tableid][TABLE_CIRCULAR_SHELL2] = INVALID_OBJECT_ID;
    g_TableData[tableid][TABLE_CIRCULAR_STEP] = 0;
    g_TableData[tableid][TABLE_REVERSE_MOVEMENT] = false;
    g_TableData[tableid][TABLE_SWAP_TYPE] = 0;
    g_TableData[tableid][TABLE_ENDING_PLAYER] = INVALID_PLAYER_ID;


    return true;
}

stock GetPlayerTable(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    return g_PlayerCurrentTable[playerid];
}


stock IsTableAvailable(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;
    return (g_TableData[tableid][TABLE_STATE] == TABLE_STATE_IDLE &&
            g_TableData[tableid][TABLE_PLAYER] == INVALID_PLAYER_ID);
}

stock GetTableShellObject(tableid, shellid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return INVALID_OBJECT_ID;
    if (shellid < 1 || shellid > 3) return INVALID_OBJECT_ID;
    return g_TableData[tableid][SHELL_OBJECTS][shellid-1];
}

stock Float:GetDistanceBetweenPoints3D(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2) {
    return floatsqroot(floatpower(x2-x1, 2.0) + floatpower(y2-y1, 2.0) + floatpower(z2-z1, 2.0));
}

// Find nearest table within 3 units
stock GetPlayerNearTable(playerid) {
    new
        Float:playerX,
        Float:playerY,
        Float:playerZ
    ;
    
    GetPlayerPos(playerid, playerX, playerY, playerZ);

    for(new tableid = 0; tableid < MAX_TABLES; tableid++) {
        new
            Float:distance = GetDistanceBetweenPoints3D(playerX, playerY, playerZ,
                                                     g_TableData[tableid][TABLE_X],
                                                     g_TableData[tableid][TABLE_Y],
                                                     g_TableData[tableid][TABLE_Z])
        ;
        if(distance < 3.0) {
            return tableid;
        }
    }
    return -1;
}


//==============================================================================================================================================================
//
//      ** FORWARD DECLARATIONS **
//
//==============================================================================================================================================================

forward ContinueShuffling(tableid);
forward EndShuffle(tableid);
forward ShowBall(tableid);
forward RevealBall(tableid);
forward RaiseSelectedShell(tableid);
forward ShowResultMessage(tableid);
forward RaiseAllShells(tableid);
forward UpdateLevelSettings(tableid);
forward CheckMovementComplete(tableid);
forward CheckInitialMovementComplete(tableid);
forward StartNextLevel(tableid);
forward StartNextLevelPhase2(tableid);
forward EndGameSequence(tableid);
forward EndGameSequencePhase2(tableid);
forward RestorePlayerControl(tableid);
forward HideTextDrawTimer(playerid);
forward MoveShellElliptically(tableid, shell1, shell2, Float:pos1X, Float:pos1Y, Float:pos2X, Float:pos2Y);
forward UpdateCircularMovement(tableid);
forward WaitForGamemode();

stock CallGamemodeShellGameStart(playerid, tableid, level, betAmount) {
    return CallRemoteFunction("OnShellGameStart", "iiii", playerid, tableid, level, betAmount);
}

stock CallGamemodeShellGameEnd(playerid, tableid, level, totalWinnings) {
    return CallRemoteFunction("OnShellGameEnd", "iiii", playerid, tableid, level, totalWinnings);
}

stock CallGamemodeShellGameLevelUp(playerid, tableid, newLevel) {
    return CallRemoteFunction("OnShellGameLevelUp", "iii", playerid, tableid, newLevel);
}

//==============================================================================================================================================================
//
//      ** TEXTDRAW FUNCTIONS **
//
//==============================================================================================================================================================

stock CreateShellGameTextDraw(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;

    if (g_ShellGameTextDraw[playerid] != PlayerText:INVALID_TEXT_DRAW) return false;

    new
        PlayerText:pt = CreatePlayerTextDraw(playerid, 28.0, 150.0, " ")
    ;

    PlayerTextDrawLetterSize(playerid, pt, 0.416, 1.760);
    PlayerTextDrawAlignment(playerid, pt, TEXT_DRAW_ALIGN:1);
    PlayerTextDrawColour(playerid, pt, 0xFFFFFF96);
    PlayerTextDrawBackgroundColour(playerid, pt, 0x000000AA);
    PlayerTextDrawBoxColour(playerid, pt, 0x000000DD);
    PlayerTextDrawSetShadow(playerid, pt, 0);
    PlayerTextDrawSetOutline(playerid, pt, 0);
    PlayerTextDrawFont(playerid, pt, TEXT_DRAW_FONT:1);
    PlayerTextDrawSetProportional(playerid, pt, true);
    PlayerTextDrawUseBox(playerid, pt, true);
    PlayerTextDrawTextSize(playerid, pt, 212.0, 200.0);

    g_ShellGameTextDraw[playerid] = pt;
    return true;
}

stock DestroyShellGameTextDraw(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;

    if (g_TextDrawTimer[playerid] != -1) {
        KillTimer(g_TextDrawTimer[playerid]);
        g_TextDrawTimer[playerid] = -1;
    }

    if (g_ShellGameTextDraw[playerid] != PlayerText:INVALID_TEXT_DRAW) {
        PlayerTextDrawDestroy(playerid, g_ShellGameTextDraw[playerid]);
        g_ShellGameTextDraw[playerid] = PlayerText:INVALID_TEXT_DRAW;
    }
    return true;
}

stock ShowShellGameMessage(playerid, const message[], duration = 4000) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;

    if (g_ShellGameTextDraw[playerid] == PlayerText:INVALID_TEXT_DRAW) {
        CreateShellGameTextDraw(playerid);
    }

    if (g_TextDrawTimer[playerid] != -1) {
        KillTimer(g_TextDrawTimer[playerid]);
        g_TextDrawTimer[playerid] = -1;
    }

    PlayerTextDrawSetString(playerid, g_ShellGameTextDraw[playerid], message);
    PlayerTextDrawShow(playerid, g_ShellGameTextDraw[playerid]);

    if (duration > 0) {
        g_TextDrawTimer[playerid] = SetTimerEx("HideTextDrawTimer", duration, false, "i", playerid);
    }
    return true;
}

stock HideShellGameMessage(playerid) {
    if (g_TextDrawTimer[playerid] != -1) {
        KillTimer(g_TextDrawTimer[playerid]);
        g_TextDrawTimer[playerid] = -1;
    }

    if (g_ShellGameTextDraw[playerid] != PlayerText:INVALID_TEXT_DRAW) {
        PlayerTextDrawHide(playerid, g_ShellGameTextDraw[playerid]);
    }
}

public HideTextDrawTimer(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    g_TextDrawTimer[playerid] = -1;
    HideShellGameMessage(playerid);
    return true;
}

//==============================================================================================================================================================
//
//      ** SHELL POSITION CALCULATION **
//
//==============================================================================================================================================================

stock GetShellPositions(tableid, &Float:centerX, &Float:centerY, &Float:centerZ,
                        &Float:leftX, &Float:leftY, &Float:leftZ,
                        &Float:rightX, &Float:rightY, &Float:rightZ,
                        &Float:ballX, &Float:ballY, &Float:ballZ,
                        &Float:ringX, &Float:ringY, &Float:ringZ) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    new
        Float:tableX = g_TableData[tableid][TABLE_X],
        Float:tableY = g_TableData[tableid][TABLE_Y],
        Float:tableZ = g_TableData[tableid][TABLE_Z],
        Float:tableAngle = g_TableData[tableid][TABLE_ANGLE]
    ;

    new
        Float:cosAngle = floatcos(tableAngle, degrees),
        Float:sinAngle = floatsin(tableAngle, degrees)
    ;

    centerX = tableX;
    centerY = tableY;
    centerZ = tableZ + 0.5295;

    new
        Float:leftOffsetX = -0.15808 * (-sinAngle),
        Float:leftOffsetY = -0.15808 * cosAngle
    ;

    leftX = tableX + leftOffsetX;
    leftY = tableY + leftOffsetY;
    leftZ = tableZ + 0.5295;

    new
        Float:rightOffsetX = 0.15796 * (-sinAngle),
        Float:rightOffsetY = 0.15796 * cosAngle
    ;

    rightX = tableX + rightOffsetX;
    rightY = tableY + rightOffsetY;
    rightZ = tableZ + 0.5295;

    ballX = tableX;
    ballY = tableY;
    ballZ = tableZ + 0.4704;

    new
        Float:ringOffsetX = -0.012 * cosAngle,
        Float:ringOffsetY = -0.002 * sinAngle
    ;
    
    ringX = tableX + ringOffsetX;
    ringY = tableY + ringOffsetY;
    ringZ = tableZ + 0.4384;

    return true;
}

//==============================================================================================================================================================
//
//      ** TABLE CREATION AND MANAGEMENT **
//
//==============================================================================================================================================================

// Create all shell game tables and objects
stock CreateShellGameTables() {
    for(new tableid = 0; tableid < MAX_TABLES; tableid++) {
        new
            Float:tableX,
            Float:tableY,
            Float:tableZ,
            Float:tableAngle
        ;
        
        if (!ShellGame_GetTablePosition(tableid, tableX, tableY, tableZ, tableAngle)) {
            continue;
        }

        g_TableData[tableid][TABLE_X] = tableX;
        g_TableData[tableid][TABLE_Y] = tableY;
        g_TableData[tableid][TABLE_Z] = tableZ;
        g_TableData[tableid][TABLE_ANGLE] = tableAngle;

        InitializeTable(tableid);

        printf("Creating table %d at: %.2f, %.2f, %.2f (angle: %.2f)", tableid, tableX, tableY, tableZ, tableAngle);
        g_TableData[tableid][TABLE_OBJECT] = CreateDynamicObject(2725, tableX, tableY, tableZ, 0.0, 0.0, tableAngle, -1, -1, -1, 200.0);
        new
            Float:shellCenterX,
            Float:shellCenterY,
            Float:shellCenterZ,
            Float:shellLeftX,
            Float:shellLeftY,
            Float:shellLeftZ,
            Float:shellRightX,
            Float:shellRightY,
            Float:shellRightZ,
            Float:ballX,
            Float:ballY,
            Float:ballZ,
            Float:ringX,
            Float:ringY,
            Float:ringZ
        ;

        GetShellPositions(tableid, shellCenterX, shellCenterY, shellCenterZ,
                         shellLeftX, shellLeftY, shellLeftZ,
                         shellRightX, shellRightY, shellRightZ,
                         ballX, ballY, ballZ, ringX, ringY, ringZ);

        g_TableData[tableid][SHELL_OBJECTS][0] = CreateDynamicObject(19835, shellCenterX, shellCenterY, shellCenterZ, 180.0, 0.0, 0.0, -1, -1, -1, 200.0);
        g_TableData[tableid][SHELL_OBJECTS][1] = CreateDynamicObject(19835, shellLeftX, shellLeftY, shellLeftZ, 180.0, 0.0, 0.0, -1, -1, -1, 200.0);
        g_TableData[tableid][SHELL_OBJECTS][2] = CreateDynamicObject(19835, shellRightX, shellRightY, shellRightZ, 180.0, 0.0, 0.0, -1, -1, -1, 200.0);

        g_TableData[tableid][BALL_OBJECT] = CreateDynamicObject(3101, ballX, ballY, ballZ-1000.0, 150.0, 0.0, 0.0, -1, -1, -1, 200.0);

        g_TableData[tableid][RING_OBJECT] = CreateDynamicObject(2992, ringX, ringY, ringZ-50.0, 0.0, 0.0, 0.0, -1, -1, -1, 300.0);
        
        new
            Float:actorX = tableX + (0.6372 * floatcos(tableAngle + 180.0, degrees)),
            Float:actorY = tableY + (0.6372 * floatsin(tableAngle + 180.0, degrees)),
            Float:actorZ = tableZ + 0.5748,
            Float:actorFacingAngle = tableAngle - 90.0
        ;

        g_TableData[tableid][ACTOR_OBJECT] = CreateActor(7, actorX, actorY, actorZ, actorFacingAngle);

        g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_X] = shellCenterX;
        g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_Y] = shellCenterY;
        g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_X] = shellLeftX;
        g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_Y] = shellLeftY;
        g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_X] = shellRightX;
        g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_Y] = shellRightY;

        printf("Table %d created successfully with %d objects", tableid, 7);
    }
}

//==============================================================================================================================================================
//
//      ** CORE GAME MECHANICS **
//
//==============================================================================================================================================================

// Main shuffling loop - moves shells in random patterns
public ContinueShuffling(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    if (g_TableData[tableid][TABLE_SHUFFLE_COUNT] >= g_TableData[tableid][TABLE_MAX_SHUFFLES]) {
        EndShuffle(tableid);
        return false;
    }

    if (g_TableData[tableid][TABLE_SHUFFLE_COUNT] == 0) {
        ApplyActorAnimation(g_TableData[tableid][ACTOR_OBJECT], "INT_SHOP", "shop_loop", 4.1, true, true, true, true, 0);

        // Calculate shell positions using proper rotation
        new 
            Float:shellCenterX, Float:shellCenterY, Float:shellCenterZ,
            Float:shellLeftX, Float:shellLeftY, Float:shellLeftZ,
            Float:shellRightX, Float:shellRightY, Float:shellRightZ,
            Float:ballX, Float:ballY, Float:ballZ,
            Float:dummyRingX, Float:dummyRingY, Float:dummyRingZ
        ;
        
        GetShellPositions(tableid, shellCenterX, shellCenterY, shellCenterZ, shellLeftX, shellLeftY, shellLeftZ, shellRightX, shellRightY, shellRightZ, ballX, ballY, ballZ, dummyRingX, dummyRingY, dummyRingZ);
        ballZ = g_TableData[tableid][TABLE_Z] + 0.4704;


        MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][0], shellCenterX, shellCenterY, shellCenterZ, 3.0, 180.0, 0.0, 0.0);
        MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][1], shellLeftX, shellLeftY, shellLeftZ, 3.0, 180.0, 0.0, 0.0);
        MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][2], shellRightX, shellRightY, shellRightZ, 3.0, 180.0, 0.0, 0.0);

        SetDynamicObjectPos(g_TableData[tableid][BALL_OBJECT], ballX, ballY, ballZ-1000.0);

        SetTimerEx("CheckInitialMovementComplete", 100, false, "i", tableid);
        return false;
    }

    g_TableData[tableid][TABLE_IS_ROTATING] = true;

    new
        randomChoice = random(3)
    ;

    if (randomChoice == 0) {
        g_TableData[tableid][TABLE_SWAP_TYPE] = 0;

        new
            Float:centerX,
            Float:centerY,
            Float:centerZ,
            Float:leftX,
            Float:leftY,
            Float:leftZ
        ;

        GetDynamicObjectPos(GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_CENTER]), centerX, centerY, centerZ);
        GetDynamicObjectPos(GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_LEFT]), leftX, leftY, leftZ);

        MoveShellElliptically(tableid, GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_CENTER]), GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_LEFT]), centerX, centerY, leftX, leftY);
    }
    else if (randomChoice == 1) {
        g_TableData[tableid][TABLE_SWAP_TYPE] = 1;

        new
            Float:leftX,
            Float:leftY,
            Float:leftZ,
            Float:rightX,
            Float:rightY,
            Float:rightZ
        ;

        GetDynamicObjectPos(GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_LEFT]), leftX, leftY, leftZ);
        GetDynamicObjectPos(GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_RIGHT]), rightX, rightY, rightZ);

        MoveShellElliptically(tableid, GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_LEFT]), GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_RIGHT]), leftX, leftY, rightX, rightY);
    }
    else {
        g_TableData[tableid][TABLE_SWAP_TYPE] = 2;

        new
            Float:centerX,
            Float:centerY,
            Float:centerZ,
            Float:rightX,
            Float:rightY,
            Float:rightZ
        ;

        GetDynamicObjectPos(GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_CENTER]), centerX, centerY, centerZ);
        GetDynamicObjectPos(GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_RIGHT]), rightX, rightY, rightZ);

        MoveShellElliptically(tableid, GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_CENTER]), GetShellObject(tableid, g_TableData[tableid][TABLE_SHELL_AT_RIGHT]), centerX, centerY, rightX, rightY);
    }

    return true;
}

public EndShuffle(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    ClearActorAnimations(g_TableData[tableid][ACTOR_OBJECT]);

    g_TableData[tableid][TABLE_IS_ROTATING] = false;
    g_TableData[tableid][TABLE_STATE] = TABLE_STATE_PLAYING;
    g_TableData[tableid][TABLE_SELECTION_ALLOWED] = true;


    // Position ball under the shell that contains it by getting the actual shell position
    new
        Float:ballX,
        Float:ballY,
        Float:ballZ,
        ballShellID = g_TableData[tableid][TABLE_BALL_POSITION]
    ;
    GetDynamicObjectPos(GetShellObject(tableid, ballShellID), ballX, ballY, ballZ);
    ballZ = g_TableData[tableid][TABLE_Z] + 0.4704;
    SetDynamicObjectPos(g_TableData[tableid][BALL_OBJECT], ballX, ballY, ballZ);

    UpdateSelectionRing(tableid);

    if (g_TableData[tableid][TABLE_PLAYER] != INVALID_PLAYER_ID) {
        ShowShellGameMessage(g_TableData[tableid][TABLE_PLAYER], MSG_GAME_READY, 5000);
    }

    return true;
}

// Check if player won and handle results
public ShowBall(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    new
        playerid = g_TableData[tableid][TABLE_PLAYER]
    ;
    if (playerid == INVALID_PLAYER_ID) return false;

    if (g_TableData[tableid][TABLE_SELECTED_SHELL] == g_TableData[tableid][TABLE_BALL_POSITION] &&
        g_TableData[tableid][TABLE_SELECTED_SHELL] >= 1 && g_TableData[tableid][TABLE_SELECTED_SHELL] <= 3) {

        new
            winnings = g_TableData[tableid][TABLE_PLAYER_BETS][g_TableData[tableid][TABLE_SELECTED_SHELL]-1] * ShellGame_GetWinMultiplier()
        ;
        GameTextForPlayer(playerid, "~g~WINNER!~n~Won $%d", 3000, 3, winnings);
        PlayerPlaySound(playerid, SOUND_WIN, 0.0, 0.0, 0.0);

        ShellGame_ProcessPayout(playerid, tableid, winnings);
        g_TableData[tableid][TABLE_PLAYER_WINNINGS] += winnings;
        g_TableData[tableid][TABLE_LEVEL]++;

        CallGamemodeShellGameLevelUp(playerid, tableid, g_TableData[tableid][TABLE_LEVEL]);
        CallGamemodeShellGameEnd(playerid, tableid, g_TableData[tableid][TABLE_LEVEL]-1, g_TableData[tableid][TABLE_PLAYER_WINNINGS]);
    }
    else {
        GameTextForPlayer(playerid, "~r~GAME OVER!~n~Lost $%d", 3000, 3, g_TableData[tableid][TABLE_TOTAL_BET_AMOUNT]);
        PlayerPlaySound(playerid, SOUND_LOSE, 0.0, 0.0, 0.0);

        CallGamemodeShellGameEnd(playerid, tableid, g_TableData[tableid][TABLE_LEVEL], g_TableData[tableid][TABLE_PLAYER_WINNINGS]);
        g_TableData[tableid][TABLE_LEVEL] = 1;
        g_TableData[tableid][TABLE_PLAYER_WINNINGS] = 0;
    }

    return true;
}

public RevealBall(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    new
        Float:ballX,
        Float:ballY,
        Float:ballZ
    ;
    GetDynamicObjectPos(g_TableData[tableid][BALL_OBJECT], ballX, ballY, ballZ);
    SetDynamicObjectPos(g_TableData[tableid][BALL_OBJECT], ballX, ballY, g_TableData[tableid][TABLE_Z] + 0.4704 + 0.0512);
    return true;
}

public RaiseSelectedShell(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    new
        Float:tempZ
    ;
    GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][0], g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_X], g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_Y], tempZ);
    GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][1], g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_X], g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_Y], tempZ);
    GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][2], g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_X], g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_Y], tempZ);

    new
        Float:shellX,
        Float:shellY,
        Float:shellZ,
        Float:raiseZ = g_TableData[tableid][TABLE_Z] + 0.5855
    ;

    // Play NPC lifting animation
    ApplyActorAnimation(g_TableData[tableid][ACTOR_OBJECT], "GANGS", "DEALER_DEAL", 4.1, false, false, false, false, 0);

    if (g_TableData[tableid][TABLE_SELECTED_SHELL] == 1) {
        SetDynamicObjectRot(g_TableData[tableid][SHELL_OBJECTS][0], 180.0, -50.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
        GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][0], shellX, shellY, shellZ);
        MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][0], shellX + (0.1025 * floatcos(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), shellY + (0.1025 * floatsin(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), raiseZ, 4.0);
    }
    else if (g_TableData[tableid][TABLE_SELECTED_SHELL] == 2) {
        SetDynamicObjectRot(g_TableData[tableid][SHELL_OBJECTS][1], 180.0, -50.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
        GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][1], shellX, shellY, shellZ);
        MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][1], shellX + (0.1025 * floatcos(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), shellY + (0.1025 * floatsin(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), raiseZ, 2.0);
    }
    else if (g_TableData[tableid][TABLE_SELECTED_SHELL] == 3) {
        SetDynamicObjectRot(g_TableData[tableid][SHELL_OBJECTS][2], 180.0, -50.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
        GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][2], shellX, shellY, shellZ);
        MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][2], shellX + (0.1025 * floatcos(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), shellY + (0.1025 * floatsin(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), raiseZ, 2.0);
    }

    SetTimerEx("ShowResultMessage", 1500, false, "i", tableid);
    return true;
}

public ShowResultMessage(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;
    SetTimerEx("RaiseAllShells", 2000, false, "i", tableid);
    return true;
}

public RaiseAllShells(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    // Play NPC dealer animation
    ApplyActorAnimation(g_TableData[tableid][ACTOR_OBJECT], "GANGS", "DEALER_DEAL", 4.1, false, false, false, false, 0);

    new
        Float:x1, Float:y1, Float:z1,
        Float:x2, Float:y2, Float:z2,
        Float:x3, Float:y3, Float:z3
    ;
    GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][0], x1, y1, z1);
    GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][1], x2, y2, z2);
    GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][2], x3, y3, z3);

    SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][0], x1, y1, z1);
    SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][1], x2, y2, z2);
    SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][2], x3, y3, z3);

    new
        Float:raiseZ = g_TableData[tableid][TABLE_Z] + 0.5855
    ;

    if (g_TableData[tableid][TABLE_SELECTED_SHELL] != 1) {
        SetDynamicObjectRot(g_TableData[tableid][SHELL_OBJECTS][0], 180.0, -50.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
        new
            Float:shell1X, Float:shell1Y, Float:shell1Z
        ;
        GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][0], shell1X, shell1Y, shell1Z);
        MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][0], shell1X + (0.1025 * floatcos(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), shell1Y + (0.1025 * floatsin(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), raiseZ, 2.0);
    }
    if (g_TableData[tableid][TABLE_SELECTED_SHELL] != 2) {
        SetDynamicObjectRot(g_TableData[tableid][SHELL_OBJECTS][1], 180.0, -50.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
        new
            Float:shell2X, Float:shell2Y, Float:shell2Z
        ;
        GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][1], shell2X, shell2Y, shell2Z);
        MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][1], shell2X + (0.1025 * floatcos(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), shell2Y + (0.1025 * floatsin(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), raiseZ, 2.0);
    }
    if (g_TableData[tableid][TABLE_SELECTED_SHELL] != 3) {
        SetDynamicObjectRot(g_TableData[tableid][SHELL_OBJECTS][2], 180.0, -50.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
        new
            Float:shell3X, Float:shell3Y, Float:shell3Z
        ;
        GetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][2], shell3X, shell3Y, shell3Z);
        MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][2], shell3X + (0.1025 * floatcos(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), shell3Y + (0.1025 * floatsin(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), raiseZ, 2.0);
    }

    ShowBall(tableid);

    if (g_TableData[tableid][TABLE_SELECTED_SHELL] == g_TableData[tableid][TABLE_BALL_POSITION]) {
        SetTimerEx("StartNextLevel", 3000, false, "i", tableid);
    }
    else {
        SetTimerEx("EndGameSequence", 2000, false, "i", tableid);
    }
    return true;
}

public UpdateLevelSettings(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    g_TableData[tableid][TABLE_BET_AMOUNT] = ShellGame_GetBasePrice() * g_TableData[tableid][TABLE_LEVEL];
    g_TableData[tableid][TABLE_MAX_SHUFFLES] = 3 + g_TableData[tableid][TABLE_LEVEL];
    g_TableData[tableid][TABLE_CURRENT_SPEED] = 1.0 + (float(g_TableData[tableid][TABLE_LEVEL] - 1) * 0.5 / 10.0);
    return true;
}

public CheckInitialMovementComplete(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    if (!IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][0]) &&
        !IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][1]) &&
        !IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][2])) {

        g_TableData[tableid][TABLE_SHUFFLE_COUNT]++;
        SetTimerEx("ContinueShuffling", 500, false, "i", tableid);
    }
    else {
        SetTimerEx("CheckInitialMovementComplete", 100, false, "i", tableid);
    }
    return true;
}

public CheckMovementComplete(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    if (!IsDynamicObjectMoving(g_TableData[tableid][TABLE_MOVING_OBJECT1]) &&
        !IsDynamicObjectMoving(g_TableData[tableid][TABLE_MOVING_OBJECT2])) {

        // Update shell positions after movement completes
        if (g_TableData[tableid][TABLE_SWAP_TYPE] == 0) {
            new
                temp = g_TableData[tableid][TABLE_SHELL_AT_CENTER]
            ;
            g_TableData[tableid][TABLE_SHELL_AT_CENTER] = g_TableData[tableid][TABLE_SHELL_AT_LEFT];
            g_TableData[tableid][TABLE_SHELL_AT_LEFT] = temp;
        }
        else if (g_TableData[tableid][TABLE_SWAP_TYPE] == 1) {
            new
                temp = g_TableData[tableid][TABLE_SHELL_AT_LEFT]
            ;
            g_TableData[tableid][TABLE_SHELL_AT_LEFT] = g_TableData[tableid][TABLE_SHELL_AT_RIGHT];
            g_TableData[tableid][TABLE_SHELL_AT_RIGHT] = temp;
        }
        else if (g_TableData[tableid][TABLE_SWAP_TYPE] == 2) {
            new
                temp = g_TableData[tableid][TABLE_SHELL_AT_CENTER]
            ;
            g_TableData[tableid][TABLE_SHELL_AT_CENTER] = g_TableData[tableid][TABLE_SHELL_AT_RIGHT];
            g_TableData[tableid][TABLE_SHELL_AT_RIGHT] = temp;
        }


        g_TableData[tableid][TABLE_MOVING_OBJECT1] = INVALID_OBJECT_ID;
        g_TableData[tableid][TABLE_MOVING_OBJECT2] = INVALID_OBJECT_ID;
        g_TableData[tableid][TABLE_CIRCULAR_SHELL1] = INVALID_OBJECT_ID;
        g_TableData[tableid][TABLE_CIRCULAR_SHELL2] = INVALID_OBJECT_ID;

        g_TableData[tableid][TABLE_SHUFFLE_COUNT]++;
        SetTimerEx("ContinueShuffling", 100, false, "i", tableid);
    }
    else {
        SetTimerEx("CheckMovementComplete", 100, false, "i", tableid);
    }
    return true;
}

// Create elliptical shell movement for realistic shuffling
public MoveShellElliptically(tableid, shell1, shell2, Float:pos1X, Float:pos1Y, Float:pos2X, Float:pos2Y) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    // Calculate elliptical arc points for smooth movement
    new
        Float:midX = (pos1X + pos2X) / 2.0,
        Float:midY = (pos1Y + pos2Y) / 2.0,
        Float:deltaX = pos2X - pos1X,
        Float:deltaY = pos2Y - pos1Y,
        Float:arc1X = midX - deltaY * 0.3,
        Float:arc1Y = midY + deltaX * 0.3,
        Float:arc2X = midX + deltaY * 0.3,
        Float:arc2Y = midY - deltaX * 0.3
    ;


    g_TableData[tableid][TABLE_MOVING_OBJECT1] = shell1;
    g_TableData[tableid][TABLE_MOVING_OBJECT2] = shell2;
    g_TableData[tableid][TABLE_CIRCULAR_SHELL1] = shell1;
    g_TableData[tableid][TABLE_CIRCULAR_SHELL2] = shell2;
    g_TableData[tableid][TABLE_CIRCULAR_CENTER_X] = arc1X;
    g_TableData[tableid][TABLE_CIRCULAR_CENTER_Y] = arc1Y;
    g_TableData[tableid][TABLE_CIRCULAR_POS1_X] = arc2X;
    g_TableData[tableid][TABLE_CIRCULAR_POS1_Y] = arc2Y;
    g_TableData[tableid][TABLE_CIRCULAR_POS2_X] = pos2X;
    g_TableData[tableid][TABLE_CIRCULAR_POS2_Y] = pos2Y;
    g_TableData[tableid][TABLE_CIRCULAR_ANGLE] = pos1X;
    g_TableData[tableid][TABLE_CIRCULAR_FINAL_Y] = pos1Y;
    g_TableData[tableid][TABLE_CIRCULAR_STEP] = 0;
    g_TableData[tableid][TABLE_REVERSE_MOVEMENT] = (random(100) < 5);

    SetTimerEx("UpdateCircularMovement", 25, false, "i", tableid);
    return true;
}

public UpdateCircularMovement(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    if (g_TableData[tableid][TABLE_CIRCULAR_STEP] == 0) {
        g_TableData[tableid][TABLE_CIRCULAR_STEP] = 1;
        MoveDynamicObject(g_TableData[tableid][TABLE_CIRCULAR_SHELL1], g_TableData[tableid][TABLE_CIRCULAR_CENTER_X], g_TableData[tableid][TABLE_CIRCULAR_CENTER_Y], g_TableData[tableid][TABLE_Z] + 0.5295, g_TableData[tableid][TABLE_CURRENT_SPEED]);
        MoveDynamicObject(g_TableData[tableid][TABLE_CIRCULAR_SHELL2], g_TableData[tableid][TABLE_CIRCULAR_POS1_X], g_TableData[tableid][TABLE_CIRCULAR_POS1_Y], g_TableData[tableid][TABLE_Z] + 0.5295, g_TableData[tableid][TABLE_CURRENT_SPEED]);
        SetTimerEx("UpdateCircularMovement", 25, false, "i", tableid);
    }
    else if (g_TableData[tableid][TABLE_CIRCULAR_STEP] == 1) {
        new
            Float:shell1X, Float:shell1Y, Float:shell1Z,
            Float:shell2X, Float:shell2Y, Float:shell2Z
        ;

        GetDynamicObjectPos(g_TableData[tableid][TABLE_CIRCULAR_SHELL1], shell1X, shell1Y, shell1Z);
        GetDynamicObjectPos(g_TableData[tableid][TABLE_CIRCULAR_SHELL2], shell2X, shell2Y, shell2Z);

        new
            Float:dist1 = floatsqroot(floatpower(shell1X - g_TableData[tableid][TABLE_CIRCULAR_CENTER_X], 2.0) + floatpower(shell1Y - g_TableData[tableid][TABLE_CIRCULAR_CENTER_Y], 2.0)),
            Float:dist2 = floatsqroot(floatpower(shell2X - g_TableData[tableid][TABLE_CIRCULAR_POS1_X], 2.0) + floatpower(shell2Y - g_TableData[tableid][TABLE_CIRCULAR_POS1_Y], 2.0))
        ;

        if (dist1 < 0.05 && dist2 < 0.05) {
            g_TableData[tableid][TABLE_CIRCULAR_STEP] = 2;

            if (g_TableData[tableid][TABLE_REVERSE_MOVEMENT]) {
                MoveDynamicObject(g_TableData[tableid][TABLE_CIRCULAR_SHELL1], g_TableData[tableid][TABLE_CIRCULAR_CENTER_X], g_TableData[tableid][TABLE_CIRCULAR_CENTER_Y], g_TableData[tableid][TABLE_Z] + 0.5295, g_TableData[tableid][TABLE_CURRENT_SPEED]);
                MoveDynamicObject(g_TableData[tableid][TABLE_CIRCULAR_SHELL2], g_TableData[tableid][TABLE_CIRCULAR_POS1_X], g_TableData[tableid][TABLE_CIRCULAR_POS1_Y], g_TableData[tableid][TABLE_Z] + 0.5295, g_TableData[tableid][TABLE_CURRENT_SPEED]);
            }
            else {
                MoveDynamicObject(g_TableData[tableid][TABLE_CIRCULAR_SHELL1], g_TableData[tableid][TABLE_CIRCULAR_POS2_X], g_TableData[tableid][TABLE_CIRCULAR_POS2_Y], g_TableData[tableid][TABLE_Z] + 0.5295, g_TableData[tableid][TABLE_CURRENT_SPEED]);
                MoveDynamicObject(g_TableData[tableid][TABLE_CIRCULAR_SHELL2], g_TableData[tableid][TABLE_CIRCULAR_ANGLE], g_TableData[tableid][TABLE_CIRCULAR_FINAL_Y], g_TableData[tableid][TABLE_Z] + 0.5295, g_TableData[tableid][TABLE_CURRENT_SPEED]);
            }
            SetTimerEx("UpdateCircularMovement", 25, false, "i", tableid);
        }
        else {
            SetTimerEx("UpdateCircularMovement", 25, false, "i", tableid);
        }
    }
    else if (g_TableData[tableid][TABLE_CIRCULAR_STEP] == 2) {
        if (g_TableData[tableid][TABLE_REVERSE_MOVEMENT]) {
            if (!IsDynamicObjectMoving(g_TableData[tableid][TABLE_CIRCULAR_SHELL1]) && !IsDynamicObjectMoving(g_TableData[tableid][TABLE_CIRCULAR_SHELL2])) {
                SetTimerEx("UpdateCircularMovement", 25, false, "i", tableid);
                g_TableData[tableid][TABLE_CIRCULAR_STEP] = 3;
                return false;
            }
            else {
                SetTimerEx("UpdateCircularMovement", 25, false, "i", tableid);
            }
        }
        else {
            if (!IsDynamicObjectMoving(g_TableData[tableid][TABLE_CIRCULAR_SHELL1]) && !IsDynamicObjectMoving(g_TableData[tableid][TABLE_CIRCULAR_SHELL2])) {
                SetTimerEx("CheckMovementComplete", 25, false, "i", tableid);
            }
            else {
                SetTimerEx("UpdateCircularMovement", 25, false, "i", tableid);
            }
        }
    }
    else if (g_TableData[tableid][TABLE_CIRCULAR_STEP] == 3) {
        if (g_TableData[tableid][TABLE_REVERSE_MOVEMENT]) {
            MoveDynamicObject(g_TableData[tableid][TABLE_CIRCULAR_SHELL1], g_TableData[tableid][TABLE_CIRCULAR_ANGLE], g_TableData[tableid][TABLE_CIRCULAR_FINAL_Y], g_TableData[tableid][TABLE_Z] + 0.5295, g_TableData[tableid][TABLE_CURRENT_SPEED]);
            MoveDynamicObject(g_TableData[tableid][TABLE_CIRCULAR_SHELL2], g_TableData[tableid][TABLE_CIRCULAR_POS2_X], g_TableData[tableid][TABLE_CIRCULAR_POS2_Y], g_TableData[tableid][TABLE_Z] + 0.5295, g_TableData[tableid][TABLE_CURRENT_SPEED]);
            g_TableData[tableid][TABLE_CIRCULAR_STEP] = 4;
            SetTimerEx("UpdateCircularMovement", 25, false, "i", tableid);
        }
    }
    else if (g_TableData[tableid][TABLE_CIRCULAR_STEP] == 4) {
        if (!IsDynamicObjectMoving(g_TableData[tableid][TABLE_CIRCULAR_SHELL1]) && !IsDynamicObjectMoving(g_TableData[tableid][TABLE_CIRCULAR_SHELL2])) {
            SetTimerEx("CheckMovementComplete", 25, false, "i", tableid);
        }
        else {
            SetTimerEx("UpdateCircularMovement", 25, false, "i", tableid);
        }
    }
    return true;
}

public StartNextLevel(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    g_TableData[tableid][TABLE_SHUFFLE_COUNT] = 0;
    g_TableData[tableid][TABLE_BALL_POSITION] = random(3) + 1;
    g_TableData[tableid][TABLE_PLAYER_BETS][0] = 0;
    g_TableData[tableid][TABLE_PLAYER_BETS][1] = 0;
    g_TableData[tableid][TABLE_PLAYER_BETS][2] = 0;
    g_TableData[tableid][TABLE_TOTAL_BET_AMOUNT] = 0;
    g_TableData[tableid][TABLE_SELECTED_SHELL] = 0;

    g_TableData[tableid][TABLE_SHELL_AT_CENTER] = 1;
    g_TableData[tableid][TABLE_SHELL_AT_LEFT] = 2;
    g_TableData[tableid][TABLE_SHELL_AT_RIGHT] = 3;
    g_TableData[tableid][TABLE_CURRENT_SELECTION] = 1;

    UpdateLevelSettings(tableid);

    new
        playerid = g_TableData[tableid][TABLE_PLAYER]
    ;

    if (playerid != INVALID_PLAYER_ID) {
        if (!ShellGame_CheckMoney(playerid, tableid, g_TableData[tableid][TABLE_BET_AMOUNT])) {

            new
                string[128]
            ;

            format(string, sizeof(string), MSG_INSUFFICIENT_MONEY, g_TableData[tableid][TABLE_BET_AMOUNT], g_TableData[tableid][TABLE_LEVEL]);
            ShowShellGameMessage(playerid, string, 4000);
            SetTimerEx("EndGameSequence", 2000, false, "i", tableid);
            return false;
        }

        if (!ShellGame_ProcessPayment(playerid, tableid, g_TableData[tableid][TABLE_BET_AMOUNT])) {
            ShowShellGameMessage(playerid, MSG_PAYMENT_FAILED, 3000);
            SetTimerEx("EndGameSequence", 2000, false, "i", tableid);
            return false;
        }

        GameTextForPlayer(playerid, "~y~Level %d", 3000, 1, g_TableData[tableid][TABLE_LEVEL]);
    }

    if (IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][0]) ||
        IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][1]) ||
        IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][2])) {
        SetTimerEx("StartNextLevel", 100, false, "i", tableid);
        return false;
    }

    // Move shells to their shuffled positions (which should be default positions at this point)
    MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][0], g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_X], g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_Y], g_TableData[tableid][TABLE_Z] + 0.5295, 3.0, 180.0, 0.0, 0.0);
    MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][1], g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_X], g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_Y], g_TableData[tableid][TABLE_Z] + 0.5295, 3.0, 180.0, 0.0, 0.0);
    MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][2], g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_X], g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_Y], g_TableData[tableid][TABLE_Z] + 0.5295, 3.0, 180.0, 0.0, 0.0);

    SetDynamicObjectPos(g_TableData[tableid][RING_OBJECT], g_TableData[tableid][TABLE_X], g_TableData[tableid][TABLE_Y], g_TableData[tableid][TABLE_Z] - 50.0);

    SetTimerEx("StartNextLevelPhase2", 1500, false, "i", tableid);
    return true;
}

public StartNextLevelPhase2(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    if (IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][0]) ||
        IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][1]) ||
        IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][2])) {
        SetTimerEx("StartNextLevelPhase2", 100, false, "i", tableid);
        return false;
    }

    new 
        Float:centerX, 
        Float:centerY, 
        Float:centerZ,
        Float:leftX, 
        Float:leftY, 
        Float:leftZ, 
        Float:rightX, 
        Float:rightY, 
        Float:rightZ, 
        Float:ballX, 
        Float:ballY, 
        Float:ballZ, 
        Float:ringX, 
        Float:ringY, 
        Float:ringZ
    ;

    GetShellPositions(tableid, centerX, centerY, centerZ, leftX, leftY, leftZ, rightX, rightY, rightZ, ballX, ballY, ballZ, ringX, ringY, ringZ);

    SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][0], centerX, centerY, centerZ);
    SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][1], leftX, leftY, leftZ);
    SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][2], rightX, rightY, rightZ);

    g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_X] = centerX;
    g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_Y] = centerY;
    g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_X] = leftX;
    g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_Y] = leftY;
    g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_X] = rightX;
    g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_Y] = rightY;

    SetupBallAndShell(tableid, g_TableData[tableid][TABLE_BALL_POSITION]);

    SetTimerEx("ContinueShuffling", 1000, false, "i", tableid);
    return true;
}


public EndGameSequence(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    g_TableData[tableid][TABLE_ENDING_PLAYER] = g_TableData[tableid][TABLE_PLAYER];

    if (IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][0]) ||
        IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][1]) ||
        IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][2])) {
        SetTimerEx("EndGameSequence", 100, false, "i", tableid);
        return false;
    }

    MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][0], g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_X], g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_Y], g_TableData[tableid][TABLE_Z] + 0.5295, 3.0, 180.0, 0.0, 0.0);
    MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][1], g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_X], g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_Y], g_TableData[tableid][TABLE_Z] + 0.5295, 3.0, 180.0, 0.0, 0.0);
    MoveDynamicObject(g_TableData[tableid][SHELL_OBJECTS][2], g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_X], g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_Y], g_TableData[tableid][TABLE_Z] + 0.5295, 3.0, 180.0, 0.0, 0.0);

    SetDynamicObjectPos(g_TableData[tableid][RING_OBJECT], g_TableData[tableid][TABLE_X], g_TableData[tableid][TABLE_Y], g_TableData[tableid][TABLE_Z] - 50.0);

    if (g_TableData[tableid][TABLE_ENDING_PLAYER] != INVALID_PLAYER_ID) {
        HideShellGameMessage(g_TableData[tableid][TABLE_ENDING_PLAYER]);
    }

    g_TableData[tableid][TABLE_STATE] = TABLE_STATE_IDLE;
    g_TableData[tableid][TABLE_PLAYER] = INVALID_PLAYER_ID;

    SetTimerEx("EndGameSequencePhase2", 1500, false, "i", tableid);
    return true;
}

public EndGameSequencePhase2(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    if (IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][0]) ||
        IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][1]) ||
        IsDynamicObjectMoving(g_TableData[tableid][SHELL_OBJECTS][2])) {
        SetTimerEx("EndGameSequencePhase2", 100, false, "i", tableid);
        return false;
    }

    new 
        Float:centerX, 
        Float:centerY, 
        Float:centerZ,
        Float:leftX, 
        Float:leftY, 
        Float:leftZ, 
        Float:rightX, 
        Float:rightY, 
        Float:rightZ, 
        Float:ballX, 
        Float:ballY, 
        Float:ballZ, 
        Float:ringX, 
        Float:ringY, 
        Float:ringZ
    ;

    GetShellPositions(tableid, centerX, centerY, centerZ, leftX, leftY, leftZ, rightX, rightY, rightZ, ballX, ballY, ballZ, ringX, ringY, ringZ);
    
    SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][0], centerX, centerY, centerZ);
    SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][1], leftX, leftY, leftZ);
    SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][2], rightX, rightY, rightZ);

    SetTimerEx("RestorePlayerControl", 1500, false, "i", tableid);
    return true;
}

public RestorePlayerControl(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    new
        playerid = g_TableData[tableid][TABLE_ENDING_PLAYER]
    ;

    if (playerid != INVALID_PLAYER_ID) {
        new
            Float:playerX = g_TableData[tableid][TABLE_X] + (1.25 * floatcos(g_TableData[tableid][TABLE_ANGLE], degrees)),
            Float:playerY = g_TableData[tableid][TABLE_Y] + (1.25 * floatsin(g_TableData[tableid][TABLE_ANGLE], degrees)),
            Float:playerZ = g_TableData[tableid][TABLE_Z] + 0.5748
        ;

        SetPlayerPos(playerid, playerX, playerY, playerZ);
        SetPlayerFacingAngle(playerid, g_TableData[tableid][TABLE_ANGLE] + 90.0);

        ApplyAnimation(playerid, "CASINO", "Roulette_out", 4.1, false, false, false, false, 0);
        ApplyActorAnimation(g_TableData[tableid][ACTOR_OBJECT], "CASINO", "Roulette_out", 4.1, false, false, false, false, 0);

        TogglePlayerControllable(playerid, true);
        SetCameraBehindPlayer(playerid);
        g_PlayerCurrentTable[playerid] = -1;
        g_TableData[tableid][TABLE_ENDING_PLAYER] = INVALID_PLAYER_ID;
    }
    return true;
}

//==============================================================================================================================================================
//
//      ** HELPER FUNCTIONS **
//
//==============================================================================================================================================================

stock PositionAllShells(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    SetShellToSlot(tableid, g_TableData[tableid][SHELL_OBJECTS][0], GetShellSlot(tableid, 1));
    SetShellToSlot(tableid, g_TableData[tableid][SHELL_OBJECTS][1], GetShellSlot(tableid, 2));
    SetShellToSlot(tableid, g_TableData[tableid][SHELL_OBJECTS][2], GetShellSlot(tableid, 3));
    return true;
}

stock UpdateSelectionRing(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;
    if (g_TableData[tableid][TABLE_CURRENT_SELECTION] < 1 || g_TableData[tableid][TABLE_CURRENT_SELECTION] > 3) return false;

    new
        playerid = g_TableData[tableid][TABLE_PLAYER]
    ;

    if (playerid != INVALID_PLAYER_ID) {
        PlayerPlaySound(playerid, SOUND_RING_MOVE, 0.0, 0.0, 0.0);
    }

    new
        Float:ringX, Float:ringY, Float:ringZ
    ;

    GetPositionForSlot(tableid, g_TableData[tableid][TABLE_CURRENT_SELECTION], ringX, ringY, ringZ);
    ringZ = g_TableData[tableid][TABLE_Z] + 0.4384;

    SetDynamicObjectPos(g_TableData[tableid][RING_OBJECT], ringX, ringY, ringZ);
    return true;
}

stock GetBallSlot(tableid) {
    if (tableid < 0 || tableid >= MAX_TABLES) return 1;

    if (g_TableData[tableid][TABLE_BALL_POSITION] == g_TableData[tableid][TABLE_SHELL_AT_CENTER]) return 1;
    if (g_TableData[tableid][TABLE_BALL_POSITION] == g_TableData[tableid][TABLE_SHELL_AT_LEFT]) return 2;
    return 3;
}

stock GetShellObject(tableid, shellId) {
    if (tableid < 0 || tableid >= MAX_TABLES) return INVALID_OBJECT_ID;

    switch (shellId) {
        case 1: return g_TableData[tableid][SHELL_OBJECTS][0];
        case 2: return g_TableData[tableid][SHELL_OBJECTS][1];
        case 3: return g_TableData[tableid][SHELL_OBJECTS][2];
    }
    return INVALID_OBJECT_ID;
}

stock GetShellSlot(tableid, shellId) {
    if (tableid < 0 || tableid >= MAX_TABLES) return 1;

    if (shellId == g_TableData[tableid][TABLE_SHELL_AT_CENTER]) return 1;
    if (shellId == g_TableData[tableid][TABLE_SHELL_AT_LEFT]) return 2;
    return 3;
}

stock GetBallPositionForSlot(tableid, slot, &Float:x, &Float:y, &Float:z) {
    if (tableid < 0 || tableid >= MAX_TABLES) return 0;

    GetPositionForSlot(tableid, slot, x, y, z);
    z = g_TableData[tableid][TABLE_Z] + 0.4704; // Ball height
    return true;
}

stock GetPositionForSlot(tableid, slot, &Float:x, &Float:y, &Float:z) {
    if (tableid < 0 || tableid >= MAX_TABLES) return 0;

    switch (slot) {
        case 1: { // Center
            x = g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_X];
            y = g_TableData[tableid][TABLE_SHUFFLED_POS_CENTER_Y];
            z = g_TableData[tableid][TABLE_Z] + 0.5295;
        }
        case 2: { // Left
            x = g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_X];
            y = g_TableData[tableid][TABLE_SHUFFLED_POS_LEFT_Y];
            z = g_TableData[tableid][TABLE_Z] + 0.5295;
        }
        case 3: { // Right
            x = g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_X];
            y = g_TableData[tableid][TABLE_SHUFFLED_POS_RIGHT_Y];
            z = g_TableData[tableid][TABLE_Z] + 0.5295;
        }
    }
    return true;
}

// Determine left/right shell mapping based on table rotation
stock GetSelectionMapping(tableid, &leftTarget, &rightTarget) {
    if (tableid < 0 || tableid >= MAX_TABLES) {
        leftTarget = 2;
        rightTarget = 3;
        return false;
    }

    new
        Float:tableAngle = g_TableData[tableid][TABLE_ANGLE]
    ;

    // Get actual world positions of left and right shells
    new
        Float:centerX,
        Float:centerY,
        Float:centerZ,
        Float:leftShellX,
        Float:leftShellY,
        Float:leftShellZ,
        Float:rightShellX,
        Float:rightShellY,
        Float:rightShellZ,
        Float:ballX,
        Float:ballY,
        Float:ballZ,
        Float:ringX,
        Float:ringY,
        Float:ringZ
    ;
    GetShellPositions(tableid, centerX, centerY, centerZ, leftShellX, leftShellY, leftShellZ, rightShellX, rightShellY, rightShellZ, ballX, ballY, ballZ, ringX, ringY, ringZ);

    // Player position and facing
    new
        Float:playerX = g_TableData[tableid][TABLE_X] + (1.25 * floatcos(tableAngle, degrees)),
        Float:playerY = g_TableData[tableid][TABLE_Y] + (1.25 * floatsin(tableAngle, degrees))
    ;

    // Calculate relative positions from player's perspective
    new
        Float:leftRelativeX = leftShellX - playerX,
        Float:leftRelativeY = leftShellY - playerY,
        Float:rightRelativeX = rightShellX - playerX,
        Float:rightRelativeY = rightShellY - playerY
    ;

    // Player faces tableAngle + 90, so calculate cross product to determine left/right
    new
        Float:playerForwardX = floatcos(tableAngle + 90.0, degrees),
        Float:playerForwardY = floatsin(tableAngle + 90.0, degrees)
    ;

    // Cross product: positive = left, negative = right
    new 
        Float:leftCross = (leftRelativeX * playerForwardY) - (leftRelativeY * playerForwardX),
        Float:rightCross = (rightRelativeX * playerForwardY) - (rightRelativeY * playerForwardX)
    ;

    if (leftCross > 0.0 && rightCross < 0.0) {
        // Left shell appears left, right shell appears right
        leftTarget = 2;
        rightTarget = 3;
    } else {
        // Left shell appears right, right shell appears left
        leftTarget = 3;
        rightTarget = 2;
    }

    return true;
}

stock SetShellToSlot(tableid, shellObject, slot) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    new 
        Float:x, 
        Float:y, 
        Float:z
    ;

    GetPositionForSlot(tableid, slot, x, y, z);
    SetDynamicObjectPos(shellObject, x, y, z);
    SetDynamicObjectRot(shellObject, 180.0, 0.0, g_TableData[tableid][TABLE_ANGLE]);
    return true;
}

stock SetupBallAndShell(tableid, ballPosition) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;

    // ballPosition is the shell ID that contains the ball (1, 2, or 3)
    new
        ballSlot = GetBallSlot(tableid),
        Float:ballX, 
        Float:ballY, 
        Float:ballZ
    ;

    GetBallPositionForSlot(tableid, ballSlot, ballX, ballY, ballZ);
    SetDynamicObjectPos(g_TableData[tableid][BALL_OBJECT], ballX, ballY, ballZ);

    new
        Float:raiseZ = g_TableData[tableid][TABLE_Z] + 0.5855
    ;

    // Play lifting animations
    new
        playerid = g_TableData[tableid][TABLE_PLAYER]
    ;

    if (playerid != INVALID_PLAYER_ID) {
        ApplyAnimation(playerid, "GANGS", "DEALER_DEAL", 4.1, false, false, false, false, 0);
    }
    ApplyActorAnimation(g_TableData[tableid][ACTOR_OBJECT], "GANGS", "DEALER_DEAL", 4.1, false, false, false, false, 0);

    // Raise the shell with the specified shell ID
    switch (ballPosition) {
        case 1:
        {
            SetDynamicObjectRot(GetShellObject(tableid, 1), 180.0, -50.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
            new
                Float:shell1X, 
                Float:shell1Y, 
                Float:shell1Z
            ;

            GetDynamicObjectPos(GetShellObject(tableid, 1), shell1X, shell1Y, shell1Z);
            MoveDynamicObject(GetShellObject(tableid, 1), shell1X + (0.1025 * floatcos(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), shell1Y + (0.1025 * floatsin(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), raiseZ, 2.0);
        }
        case 2:
        {
            SetDynamicObjectRot(GetShellObject(tableid, 2), 180.0, -50.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
            new
                Float:shell2X, 
                Float:shell2Y, 
                Float:shell2Z
            ;

            GetDynamicObjectPos(GetShellObject(tableid, 2), shell2X, shell2Y, shell2Z);
            MoveDynamicObject(GetShellObject(tableid, 2), shell2X + (0.1025 * floatcos(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), shell2Y + (0.1025 * floatsin(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), raiseZ, 2.0);
        }
        case 3:
        {
            SetDynamicObjectRot(GetShellObject(tableid, 3), 180.0, -50.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
            new
                Float:shell3X, 
                Float:shell3Y, 
                Float:shell3Z
            ;

            GetDynamicObjectPos(GetShellObject(tableid, 3), shell3X, shell3Y, shell3Z);
            MoveDynamicObject(GetShellObject(tableid, 3), shell3X + (0.1025 * floatcos(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), shell3Y + (0.1025 * floatsin(g_TableData[tableid][TABLE_ANGLE] + 180.0, degrees)), raiseZ, 2.0);
        }
    }
    return true;
}

stock SelectShell(playerid, tableid, shell) {
    if (tableid < 0 || tableid >= MAX_TABLES) return false;
    if (shell < 1 || shell > 3) return false;
    if (g_TableData[tableid][TABLE_PLAYER] != playerid) return false;


    g_TableData[tableid][TABLE_SELECTION_ALLOWED] = false;
    PlayerPlaySound(playerid, SOUND_SELECT, 0.0, 0.0, 0.0);
    SetDynamicObjectPos(g_TableData[tableid][RING_OBJECT], g_TableData[tableid][TABLE_X], g_TableData[tableid][TABLE_Y], g_TableData[tableid][TABLE_Z] - 50.0);

    g_TableData[tableid][TABLE_PLAYER_BETS][shell-1] = g_TableData[tableid][TABLE_BET_AMOUNT];
    g_TableData[tableid][TABLE_TOTAL_BET_AMOUNT] = g_TableData[tableid][TABLE_BET_AMOUNT];
    g_TableData[tableid][TABLE_SELECTED_SHELL] = shell;
    g_TableData[tableid][TABLE_STATE] = TABLE_STATE_REVEALING;

    SetTimerEx("RaiseSelectedShell", 500, false, "i", tableid);
    return true;
}

//==============================================================================================================================================================
//
//      ** CALLBACK FUNCTIONS **
//
//==============================================================================================================================================================

public OnFilterScriptInit() {
    printf("  ----------------------------------------");
    printf("  |   Multi-Table Shell Game Loading     |");
    printf("  |          Made by: itsneufox          |");
    printf("  ----------------------------------------");

    // Initialize player data
    for (new i = 0; i < MAX_PLAYERS; i++) {
        g_PlayerCurrentTable[i] = -1;
        g_ShellGameTextDraw[i] = PlayerText:INVALID_TEXT_DRAW;
        g_TextDrawTimer[i] = -1;
        g_LastSelectionTime[i] = 0;
    }

    // Wait for gamemode to be ready, then create tables
    SetTimer("WaitForGamemode", 2000, false);

    // Start proximity detection timer (checks every 100ms)
    g_ProximityTimer = SetTimer("CheckPlayerProximity", 100, true);

    // Start selection timer (only runs when needed - 50ms for responsive controls)
    g_SelectionTimer = SetTimer("CheckPlayerSelection", 50, true);

    return true;
}

public WaitForGamemode() {
    if (g_HandshakeRetryCount == 0) {
        printf("[FILTERSCRIPT] Initiating handshake with gamemode...");
    }

    // Test if gamemode callback exists
    new 
        Float:testX,
        Float:testY, 
        Float:testZ,
        Float:testAngle
    ;

    if (!ShellGame_GetTablePosition(0, testX, testY, testZ, testAngle) ||
        (testX == 0.0 && testY == 0.0 && testZ == 0.0)) {
        g_HandshakeRetryCount++;
        if (g_HandshakeRetryCount >= 5) {
            printf("[FILTERSCRIPT] Handshake failed after 5 attempts. Gamemode not responding. Shell game disabled.");
            return false;
        }
        printf("[FILTERSCRIPT] Gamemode not responding, retrying handshake in 1 second... (Attempt %d/5)", g_HandshakeRetryCount);
        SetTimer("WaitForGamemode", 1000, false);
        return false;
    }

    printf("[FILTERSCRIPT] Handshake successful! Gamemode connection established. Creating tables...");
    CreateShellGameTables();
    return true;
}

public OnPlayerConnect(playerid) {
    g_PlayerCurrentTable[playerid] = -1;
    g_ShellGameTextDraw[playerid] = PlayerText:INVALID_TEXT_DRAW;
    g_TextDrawTimer[playerid] = -1;
    g_LastSelectionTime[playerid] = 0;

    // Preload animation libraries
    ApplyAnimation(playerid, "INT_SHOP", "null", 4.1, false, false, false, false, 0);
    ApplyAnimation(playerid, "CASINO", "null", 4.1, false, false, false, false, 0);
    ApplyAnimation(playerid, "GANGS", "null", 4.1, false, false, false, false, 0);
    return true;
}

public OnPlayerDisconnect(playerid, reason) {
    DestroyShellGameTextDraw(playerid);

    // If player was playing at a table, clean up that table
    new 
        tableid = g_PlayerCurrentTable[playerid]
    ;

    if (tableid != -1 && g_TableData[tableid][TABLE_PLAYER] == playerid) {
        // Reset table to idle state
        InitializeTable(tableid);
        g_TableData[tableid][TABLE_STATE] = TABLE_STATE_IDLE;

        // Reset objects to clean default positions with proper rotation
        new 
            Float:centerX, 
            Float:centerY, 
            Float:centerZ,
            Float:leftX, 
            Float:leftY, 
            Float:leftZ, 
            Float:rightX, 
            Float:rightY, 
            Float:rightZ, 
            Float:ballX, 
            Float:ballY, 
            Float:ballZ, 
            Float:ringX, 
            Float:ringY, 
            Float:ringZ
        ;
        GetShellPositions(tableid, centerX, centerY, centerZ, leftX, leftY, leftZ, rightX, rightY, rightZ, ballX, ballY, ballZ, ringX, ringY, ringZ);
        
        SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][0], centerX, centerY, centerZ);
        SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][1], leftX, leftY, leftZ);
        SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][2], rightX, rightY, rightZ);
        SetDynamicObjectPos(g_TableData[tableid][BALL_OBJECT], g_TableData[tableid][TABLE_X], g_TableData[tableid][TABLE_Y], g_TableData[tableid][TABLE_Z] - 1000.0);
        SetDynamicObjectPos(g_TableData[tableid][RING_OBJECT], g_TableData[tableid][TABLE_X], g_TableData[tableid][TABLE_Y], g_TableData[tableid][TABLE_Z] - 50.0);
        ClearActorAnimations(g_TableData[tableid][ACTOR_OBJECT]);
    }

    g_PlayerCurrentTable[playerid] = -1;
    return true;
}

// Handle player input for game controls
public OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys) {
    new 
        tableid = GetPlayerNearTable(playerid)
    ;

    if (tableid == -1) return true; // Not near any table

    g_PlayerCurrentTable[playerid] = tableid;

    // Handle game controls for players currently playing at this table
    if (g_TableData[tableid][TABLE_PLAYER] == playerid && g_TableData[tableid][TABLE_STATE] == TABLE_STATE_PLAYING) {

        // Exit game
        if ((newkeys & KEY_SECONDARY_ATTACK) && !(oldkeys & KEY_SECONDARY_ATTACK)) {
            if (!g_TableData[tableid][TABLE_SELECTION_ALLOWED]) {
                ShowShellGameMessage(playerid, MSG_CANNOT_EXIT, 2000);
                return true;
            }

            // Exit the game
            g_TableData[tableid][TABLE_STATE] = TABLE_STATE_IDLE;
            g_TableData[tableid][TABLE_SELECTION_ALLOWED] = false;
            g_TableData[tableid][TABLE_PLAYER] = INVALID_PLAYER_ID;

            // Reset objects to clean default positions with proper rotation
            new 
                Float:centerX, 
                Float:centerY, 
                Float:centerZ,
                Float:leftX, 
                Float:leftY, 
                Float:leftZ, 
                Float:rightX, 
                Float:rightY, 
                Float:rightZ, 
                Float:ballX, 
                Float:ballY, 
                Float:ballZ, 
                Float:ringX, 
                Float:ringY, 
                Float:ringZ
            ;

            GetShellPositions(tableid, centerX, centerY, centerZ, leftX, leftY, leftZ, rightX, rightY, rightZ, ballX, ballY, ballZ, ringX, ringY, ringZ);
            
            SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][0], centerX, centerY, centerZ);
            SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][1], leftX, leftY, leftZ);
            SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][2], rightX, rightY, rightZ);
            SetDynamicObjectPos(g_TableData[tableid][RING_OBJECT], g_TableData[tableid][TABLE_X], g_TableData[tableid][TABLE_Y], g_TableData[tableid][TABLE_Z] - 50.0);

            HideShellGameMessage(playerid);
            TogglePlayerControllable(playerid, true);
            SetCameraBehindPlayer(playerid);
            g_PlayerCurrentTable[playerid] = -1;
            return true;
        }
    }

    // Start new game
    if ((newkeys & KEY_JUMP) && !(oldkeys & KEY_JUMP)) {

        // Check if currently playing and can select shell
        if (g_TableData[tableid][TABLE_PLAYER] == playerid &&
            g_TableData[tableid][TABLE_STATE] == TABLE_STATE_PLAYING &&
            !g_TableData[tableid][TABLE_IS_ROTATING] &&
            g_TableData[tableid][TABLE_SELECTION_ALLOWED]) {

            new
                shell = 0
            ;

            if (g_TableData[tableid][TABLE_CURRENT_SELECTION] == 1) {
                shell = g_TableData[tableid][TABLE_SHELL_AT_CENTER];
            }
            else if (g_TableData[tableid][TABLE_CURRENT_SELECTION] == 2) {
                shell = g_TableData[tableid][TABLE_SHELL_AT_LEFT];
            }
            else if (g_TableData[tableid][TABLE_CURRENT_SELECTION] == 3) {
                shell = g_TableData[tableid][TABLE_SHELL_AT_RIGHT];
            }

            if (shell > 0) {
                SelectShell(playerid, tableid, shell);
            }
            return true;
        }

        // Check if table is busy
        if (g_TableData[tableid][TABLE_STATE] != TABLE_STATE_IDLE) {
            if (g_TableData[tableid][TABLE_PLAYER] != playerid) {
                ShowShellGameMessage(playerid, MSG_GAME_IN_PROGRESS, 3000);
            } else {
                ShowShellGameMessage(playerid, MSG_SHUFFLING_WAIT, 3000);
            }
            return true;
        }

        // Start new game at this table
        g_TableData[tableid][TABLE_BET_AMOUNT] = ShellGame_GetBasePrice() * g_TableData[tableid][TABLE_LEVEL];

        if (!ShellGame_CheckMoney(playerid, tableid, g_TableData[tableid][TABLE_BET_AMOUNT])) {
            new
                string[128]
            ;

            format(string, sizeof(string), MSG_INSUFFICIENT_MONEY, g_TableData[tableid][TABLE_BET_AMOUNT], g_TableData[tableid][TABLE_LEVEL]);
            ShowShellGameMessage(playerid, string, 4000);
            return true;
        }

        if (!ShellGame_ProcessPayment(playerid, tableid, g_TableData[tableid][TABLE_BET_AMOUNT])) {
            ShowShellGameMessage(playerid, MSG_PAYMENT_FAILED, 3000);
            return true;
        }

        // Initialize game for this table
        g_TableData[tableid][TABLE_PLAYER] = playerid;
        g_TableData[tableid][TABLE_STATE] = TABLE_STATE_SHUFFLING;
        UpdateLevelSettings(tableid);
        g_TableData[tableid][TABLE_SHUFFLE_COUNT] = 0;
        g_TableData[tableid][TABLE_BALL_POSITION] = random(3) + 1;

        GameTextForPlayer(playerid, "~y~Level %d", 3000, 1, g_TableData[tableid][TABLE_LEVEL]);

        CallGamemodeShellGameStart(playerid, tableid, g_TableData[tableid][TABLE_LEVEL], g_TableData[tableid][TABLE_BET_AMOUNT]);

        g_TableData[tableid][TABLE_PLAYER_BETS][0] = 0;
        g_TableData[tableid][TABLE_PLAYER_BETS][1] = 0;
        g_TableData[tableid][TABLE_PLAYER_BETS][2] = 0;
        g_TableData[tableid][TABLE_TOTAL_BET_AMOUNT] = 0;

        g_TableData[tableid][TABLE_SHELL_AT_CENTER] = 1;
        g_TableData[tableid][TABLE_SHELL_AT_LEFT] = 2;
        g_TableData[tableid][TABLE_SHELL_AT_RIGHT] = 3;
        g_TableData[tableid][TABLE_CURRENT_SELECTION] = 1;

        // Reset shells to clean default positions with proper rotation
        new 
            Float:centerX, 
            Float:centerY, 
            Float:centerZ,
            Float:leftX, 
            Float:leftY, 
            Float:leftZ, 
            Float:rightX, 
            Float:rightY, 
            Float:rightZ, 
            Float:ballX, 
            Float:ballY, 
            Float:ballZ, 
            Float:ringX, 
            Float:ringY, 
            Float:ringZ
        ;

        GetShellPositions(tableid, centerX, centerY, centerZ, leftX, leftY, leftZ, rightX, rightY, rightZ, ballX, ballY, ballZ, ringX, ringY, ringZ);
        
        SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][0], centerX, centerY, centerZ);
        SetDynamicObjectRot(g_TableData[tableid][SHELL_OBJECTS][0], 180.0, 0.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
        SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][1], leftX, leftY, leftZ);
        SetDynamicObjectRot(g_TableData[tableid][SHELL_OBJECTS][1], 180.0, 0.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);
        SetDynamicObjectPos(g_TableData[tableid][SHELL_OBJECTS][2], rightX, rightY, rightZ);
        SetDynamicObjectRot(g_TableData[tableid][SHELL_OBJECTS][2], 180.0, 0.0, g_TableData[tableid][TABLE_ANGLE] + 180.0);

        // Setup ball and show it briefly
        SetupBallAndShell(tableid, g_TableData[tableid][TABLE_BALL_POSITION]);

        // Position player on opposite side from actor (where camera is)
        new
            Float:playerX = g_TableData[tableid][TABLE_X] + (1.25 * floatcos(g_TableData[tableid][TABLE_ANGLE], degrees)),
            Float:playerY = g_TableData[tableid][TABLE_Y] + (1.25 * floatsin(g_TableData[tableid][TABLE_ANGLE], degrees)),
            Float:playerZ = g_TableData[tableid][TABLE_Z] + 0.5748
        ;

        SetPlayerPos(playerid, playerX, playerY, playerZ);
        SetPlayerFacingAngle(playerid, g_TableData[tableid][TABLE_ANGLE] + 90.0);

        // Set camera on opposite side from actor
        new
            Float:cameraX = g_TableData[tableid][TABLE_X] + (0.65 * floatcos(g_TableData[tableid][TABLE_ANGLE], degrees)),
            Float:cameraY = g_TableData[tableid][TABLE_Y] + (0.65 * floatsin(g_TableData[tableid][TABLE_ANGLE], degrees)),
            Float:cameraZ = g_TableData[tableid][TABLE_Z] + 1.1488
        ;

        SetPlayerCameraPos(playerid, cameraX, cameraY, cameraZ);
        SetPlayerCameraLookAt(playerid, g_TableData[tableid][TABLE_X], g_TableData[tableid][TABLE_Y], g_TableData[tableid][TABLE_Z] + 0.4488);
        TogglePlayerControllable(playerid, false);

        // Position selection ring
        UpdateSelectionRing(tableid);

        SetTimerEx("ContinueShuffling", 1000, false, "i", tableid);
    }

    return true;
}

forward CheckPlayerProximity();
forward CheckPlayerSelection();

// Check if players are near tables and show/hide messages
public CheckPlayerProximity() {
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;

        new
            tableid = GetPlayerNearTable(playerid),
            bool:nearTable = (tableid != -1),
            bool:wasNearTable = (g_PlayerCurrentTable[playerid] != -1)
        ;

        if (nearTable && !wasNearTable) {
            g_PlayerCurrentTable[playerid] = tableid;
            if (g_TableData[tableid][TABLE_STATE] == TABLE_STATE_IDLE) {
                ShowShellGameMessage(playerid, MSG_WELCOME, 0);
            }
        }
        else if (!nearTable && wasNearTable) {
            g_PlayerCurrentTable[playerid] = -1;
            HideShellGameMessage(playerid);
        }

    }
}

// Handle arrow key input for shell selection
public CheckPlayerSelection() {
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;

        new
            tableid = g_PlayerCurrentTable[playerid]
        ;

        if (tableid == -1) continue;

        if (g_TableData[tableid][TABLE_PLAYER] == playerid &&
            g_TableData[tableid][TABLE_STATE] == TABLE_STATE_PLAYING &&
            !g_TableData[tableid][TABLE_IS_ROTATING] &&
            g_TableData[tableid][TABLE_SELECTION_ALLOWED]) {

            new
                KEY:keys, updown, leftright
            ;
            GetPlayerKeys(playerid, keys, updown, leftright);

            new
                currentTime = GetTickCount()
            ;

            if (currentTime - g_LastSelectionTime[playerid] < 200) continue;

            if (leftright == 128) { // LEFT
                // Determine left/right mapping based on table angle
                new
                    leftTarget, rightTarget
                ;

                GetSelectionMapping(tableid, leftTarget, rightTarget);

                if (g_TableData[tableid][TABLE_CURRENT_SELECTION] == 1) {
                    g_TableData[tableid][TABLE_CURRENT_SELECTION] = leftTarget;
                }
                else if (g_TableData[tableid][TABLE_CURRENT_SELECTION] == leftTarget) {
                    g_TableData[tableid][TABLE_CURRENT_SELECTION] = rightTarget;
                }
                else if (g_TableData[tableid][TABLE_CURRENT_SELECTION] == rightTarget) {
                    g_TableData[tableid][TABLE_CURRENT_SELECTION] = 1;
                }
                UpdateSelectionRing(tableid);
                g_LastSelectionTime[playerid] = currentTime;
            }
            else if (leftright == -128) { // RIGHT
                // Determine left/right mapping based on table angle
                new
                    leftTarget, rightTarget
                ;
                
                GetSelectionMapping(tableid, leftTarget, rightTarget);

                if (g_TableData[tableid][TABLE_CURRENT_SELECTION] == 1) {
                    g_TableData[tableid][TABLE_CURRENT_SELECTION] = rightTarget;
                }
                else if (g_TableData[tableid][TABLE_CURRENT_SELECTION] == rightTarget) {
                    g_TableData[tableid][TABLE_CURRENT_SELECTION] = leftTarget;
                }
                else if (g_TableData[tableid][TABLE_CURRENT_SELECTION] == leftTarget) {
                    g_TableData[tableid][TABLE_CURRENT_SELECTION] = 1;
                }
                UpdateSelectionRing(tableid);
                g_LastSelectionTime[playerid] = currentTime;
            }
        }
    }
}

public OnFilterScriptExit() {
    printf("  ----------------------------------------");
    printf("  |  Multi-Table Shell Game Unloaded     |");
    printf("  |         Made by: itsneufox           |");
    printf("  ----------------------------------------");

    // Clean up timers
    if (g_ProximityTimer != -1) {
        KillTimer(g_ProximityTimer);
        g_ProximityTimer = -1;
    }
    if (g_SelectionTimer != -1) {
        KillTimer(g_SelectionTimer);
        g_SelectionTimer = -1;
    }

    for (new i = 0; i < MAX_PLAYERS; i++) {
        if (IsPlayerConnected(i)) {
            DestroyShellGameTextDraw(i);
        }
    }

    // Cleanup all table objects
    for (new tableid = 0; tableid < MAX_TABLES; tableid++) {
        if (g_TableData[tableid][TABLE_OBJECT] != 0) {
            DestroyDynamicObject(g_TableData[tableid][TABLE_OBJECT]);
            DestroyDynamicObject(g_TableData[tableid][SHELL_OBJECTS][0]);
            DestroyDynamicObject(g_TableData[tableid][SHELL_OBJECTS][1]);
            DestroyDynamicObject(g_TableData[tableid][SHELL_OBJECTS][2]);
            DestroyDynamicObject(g_TableData[tableid][BALL_OBJECT]);
            DestroyDynamicObject(g_TableData[tableid][RING_OBJECT]);
            if (g_TableData[tableid][ACTOR_OBJECT] != 0) {
                DestroyActor(g_TableData[tableid][ACTOR_OBJECT]);
            }
        }
    }

    return true;
}

