# Shell Game API Documentation

This document provides instructions for integrating the Shell Game filterscript with your open.mp gamemode.

## Overview

The Shell Game is a casino-style mini-game where players bet money to guess which shell contains the ball. The game features progressive difficulty with increasing bet amounts per level and supports multiple tables simultaneously.

## Features

- **🎮 Multi-table support** - Up to 10 tables with independent game states
- **💰 Flexible payment system** - Integrate with any economy system
- **🎯 Easy table creation** - Simple API functions for table management
- **⚡ Performance optimized** - Timer-based proximity detection
- **🎪 Rich callbacks** - Complete game event tracking
- **🎨 Visual feedback** - Dynamic textdraws and game messages

## Required Files

- `shellgame_multi.pwn` - Main filterscript (place in filterscripts folder)
- `shellgame_api.inc` - API definitions (place in includes folder)

## Setup Instructions

### 1. Include the API

Add this line to the top of your gamemode file:

```pawn
#include <shellgame_api>
```

### 2. Create Tables in OnGameModeInit

Add table creation to your gamemode initialization:

```pawn
public OnGameModeInit() {
    // Your existing gamemode initialization...

    // Create shell game tables
    CreateShellGameTable(0, 1465.75, -1661.73, 13.45, 90.0);   // Casino entrance
    CreateShellGameTable(1, 1466.11, -1654.05, 13.45, 180.0); // VIP area
    CreateShellGameTable(2, 1459.59, -1657.60, 13.45, 270.0); // Side room

    return 1;
}
```

### 3. Implement Required Callbacks

Add these functions to your gamemode:

```pawn
// Payment handling
public OnShellGamePayment(playerid, tableid, amount)
{
    if (GetPlayerMoney(playerid) < amount)
        return 0;

    GivePlayerMoney(playerid, -amount);
    return 1;
}

public OnShellGamePayout(playerid, tableid, amount)
{
    GivePlayerMoney(playerid, amount);
    return 1;
}

public OnShellGameCheckMoney(playerid, tableid, amount)
{
    return (GetPlayerMoney(playerid) >= amount) ? 1 : 0;
}

// Pricing configuration
public OnShellGameGetBasePrice()
{
    return 100; // $100 base price for level 1
}

public OnShellGameGetWinMultiplier()
{
    return 2; // 2x multiplier
}
```

### 4. Optional Event Callbacks

```pawn
public OnShellGameStart(playerid, tableid, level, betAmount)
{
    new message[128];
    format(message, sizeof(message), "Game started at table %d - Level %d, Bet: $%d", tableid, level, betAmount);
    SendClientMessage(playerid, 0x00FF00FF, message);
    return 1;
}

public OnShellGameEnd(playerid, tableid, level, totalWinnings)
{
    new message[128];
    if (totalWinnings > 0) {
        format(message, sizeof(message), "Game ended! Total winnings: $%d", totalWinnings);
        SendClientMessage(playerid, 0x00FF00FF, message);
    } else {
        SendClientMessage(playerid, 0xFF0000FF, "Game over - Better luck next time!");
    }
    return 1;
}

public OnShellGameLevelUp(playerid, tableid, newLevel)
{
    new message[128];
    format(message, sizeof(message), "Level up! Now on level %d", newLevel);
    SendClientMessage(playerid, 0xFFFF00FF, message);
    return 1;
}
```

### 5. Cleanup on Exit

Add cleanup to your gamemode exit:

```pawn
public OnGameModeExit()
{
    CleanupShellGameTables();
    return 1;
}
```

## Installation

1. Place `shellgame_multi.pwn` in your `filterscripts/` folder
2. Place `shellgame_api.inc` in your `includes/` folder
3. Add `shellgame_multi` to your `server.cfg` filterscripts line
4. Compile and restart your server

## Game Mechanics

### Basic Operation
- Players approach any shell game table to start
- Bet money to guess which shell contains the ball
- Winning advances to the next level with higher stakes
- Losing ends the game

### Pricing System
- Level 1: $100 bet → $200 winnings
- Level 2: $200 bet → $400 winnings
- Level 3: $300 bet → $600 winnings
- Formula: Bet = Base Price × Level, Winnings = Bet × Multiplier

### Controls
- **SPACE** - Start game / Select shell
- **LEFT ARROW** - Move selection counter-clockwise
- **RIGHT ARROW** - Move selection clockwise
- **F/ENTER** - Exit current game

## API Reference

### Table Management Functions

#### `CreateShellGameTable(tableid, Float:x, Float:y, Float:z, Float:angle = 0.0)`
```pawn
CreateShellGameTable(tableid, Float:x, Float:y, Float:z, Float:angle = 0.0)
```
Creates a new shell game table at the specified coordinates.

**Parameters:**
- `tableid`: Table ID (0 to MAX_TABLES-1)
- `x`: X coordinate
- `y`: Y coordinate
- `z`: Z coordinate
- `angle`: Rotation angle in degrees (optional, default: 0.0)

**Returns:** 1 if successful, 0 if failed

#### `RemoveShellGameTable(tableid)`
```pawn
RemoveShellGameTable(tableid)
```
Removes a specific shell game table.

**Parameters:**
- `tableid`: Table ID to remove

**Returns:** 1 if successful, 0 if failed

#### `CleanupShellGameTables()`
```pawn
CleanupShellGameTables()
```
Removes all shell game tables (typically called in OnGameModeExit).

**Returns:** Number of tables cleaned up

### Required Callbacks

#### `OnShellGamePayment(playerid, tableid, amount)`
- **Purpose:** Deduct money from player for bet
- **Parameters:** `playerid` - Player ID, `tableid` - Table ID, `amount` - Amount to deduct
- **Returns:** 1 on success, 0 on failure

#### `OnShellGamePayout(playerid, tableid, amount)`
- **Purpose:** Give winnings to player
- **Parameters:** `playerid` - Player ID, `tableid` - Table ID, `amount` - Amount to give
- **Returns:** 1 on success, 0 on failure

#### `OnShellGameCheckMoney(playerid, tableid, amount)`
- **Purpose:** Verify player has sufficient funds
- **Parameters:** `playerid` - Player ID, `tableid` - Table ID, `amount` - Amount to check
- **Returns:** 1 if sufficient, 0 if insufficient

### Optional Event Callbacks

#### `OnShellGameStart(playerid, tableid, level, betAmount)`
- **Purpose:** Called when game starts
- **Parameters:** `playerid` - Player ID, `tableid` - Table ID, `level` - Current level, `betAmount` - Bet amount

#### `OnShellGameEnd(playerid, tableid, level, totalWinnings)`
- **Purpose:** Called when game ends
- **Parameters:** `playerid` - Player ID, `tableid` - Table ID, `level` - Final level, `totalWinnings` - Total accumulated

#### `OnShellGameLevelUp(playerid, tableid, newLevel)`
- **Purpose:** Called when player advances level
- **Parameters:** `playerid` - Player ID, `tableid` - Table ID, `newLevel` - New level reached

### Configuration Callbacks

#### `OnShellGameGetBasePrice()`
- **Purpose:** Returns base price for level 1
- **Returns:** Integer - Base price amount

#### `OnShellGameGetWinMultiplier()`
- **Purpose:** Returns win multiplier
- **Returns:** Integer - Multiplier value

## Advanced Usage

### Custom Economy Integration

For custom money systems:

```pawn
public OnShellGamePayment(playerid, tableid, amount)
{
    return YourEconomy_TakeMoney(playerid, amount);
}

public OnShellGamePayout(playerid, tableid, amount)
{
    return YourEconomy_GiveMoney(playerid, amount);
}

public OnShellGameCheckMoney(playerid, tableid, amount)
{
    return YourEconomy_HasMoney(playerid, amount);
}
```

### VIP Table System

```pawn
// Restrict certain tables to VIP players
public OnShellGameCheckMoney(playerid, tableid, amount) {
    // Table 3 is VIP only
    if(tableid == 3 && !IsPlayerVIP(playerid)) {
        SendClientMessage(playerid, COLOR_RED, "This table is for VIP members only!");
        return 0;
    }
    return GetPlayerMoney(playerid) >= amount;
}
```

## Troubleshooting

**Tables not appearing:**
- Verify `CreateShellGameTable()` calls in OnGameModeInit
- Check table coordinates are valid
- Ensure filterscript is loaded

**Players cannot start game:**
- Verify `OnShellGameCheckMoney()` implementation
- Check include statement is present
- Make sure player is within 3 units of table

**Money transactions not working:**
- Ensure `OnShellGamePayment()` and `OnShellGamePayout()` are implemented
- Verify return values (1 for success, 0 for failure)
- Check if player has sufficient funds

**Compilation errors:**
- Confirm `shellgame_api.inc` is in includes folder
- Check for missing semicolons or syntax errors
- Verify MAX_TABLES is defined

**Incorrect pricing:**
- Verify `OnShellGameGetBasePrice()` return value
- Check `OnShellGameGetWinMultiplier()` implementation

## Constants

```pawn
#define MAX_TABLES 10  // Maximum number of tables supported
```

## Examples

See the included `test.pwn` gamemode for a complete implementation example with basic economy integration.

---

**Created by itsneufox @2025** | [GitHub](https://github.com/itsneufox) | [Website](https://itsneufox.xyz)
