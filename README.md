# Roblox Admin Panel

A custom administration and moderation panel for Roblox experiences. It provides a clean interface and essential commands for game management.
IF YOU WANT TO HELP ME 
contact me contact.re7orm@gmail.com or add me on discord @Re7orm
## Features

## Features

* **Native Platform Banning:** Utilizes Roblox's native `BanAsync()` to ban users at the platform level, allowing for cross-server enforcement and offline banning via UserId.
* **Device Alt-Account Blocking:** Includes an option to apply a hardware/device block (`ApplyDeviceBlock`), preventing banned users from rejoining for 24 hours on alt accounts from the same device.
* **Temporary & Permanent Bans:** Supports setting custom ban durations in days or issuing permanent bans.
* **Persistent Action Logging:** Saves up to 200 of the most recent moderation actions to a DataStore, viewable directly in the panel's Log tab even after server restarts.
* **Live Server Monitoring:** Automatically updates player ping and connection status in real-time every 5 seconds.
* **Essential Moderation Tools:** Quickly Kick, Kill, Respawn, Warn, or modify a player's WalkSpeed with a safe maximum limit to prevent typing errors.
* **Server Announcements:** Broadcast global messages to the entire server or send dedicated modal warnings to specific players.
* **Admin Feedback Toasts:** Provides instant, on-screen success or error notifications to the admin whenever a command is executed or a target is not found.

## Installation

This panel is designed to be extremely lightweight and requires only two scripts to function perfectly. Follow these exact steps to install it in your game:

1. **Server Setup**
   * Create a `Script` inside `ServerScriptService`.
   * Name the script exactly: `admin panel`
   * Paste the server-side code into this script.

2. **Client Setup**
   * Create a `LocalScript` inside `StarterPlayerScripts`.
   * Name the script exactly: `admin panel`
   * Paste the client-side code into this script.
here a lil demo <img width="390" height="303" alt="grafik" src="https://github.com/user-attachments/assets/d2c41f7f-2f8e-44ca-a526-45c070fc23a2" />


## Configuration & Access

By default, the panel is restricted. To give yourself (or other moderators) access, you must configure your UserId in the server script:

1. Open the `admin panel` script located in `ServerScriptService`.
2. Locate the configuration section at the top of the code (lines 9 to 18).
3. Add your exact Roblox UserId to the admins list. 

**Example:**
```lua
local CONFIG = {
    Admins = {
        977183429, -- Add your UserID here
    },
    BanStoreName  = "AdminPanel_BanRecords_v3",
    LogStoreName  = "AdminPanel_Logs_v3",
    MaxLogEntries = 200,
    PingInterval  = 5,    
    MaxSpeed      = 300,  
}
