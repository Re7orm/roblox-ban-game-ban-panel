# NoVa Panel — Moderation System v5

A sleek, high-performance administration panel for Roblox experiences. Built for serious developers who need clean, reliable, and powerful moderation tools. READ UPDATES BELOW!

![NoVa Panel](https://github.com/user-attachments/assets/b3da9225-7515-493a-8203-4b027d482303)

---

## Core Features

- **Native Platform Bans** — Leverages Roblox's `BanAsync()` for true cross-server and offline bans using UserIds.
- **Device-Level Protection** — Optional `ApplyDeviceBlock` to block hardware alts for 24 hours.
- **Flexible Ban Durations** — Temporary bans in days or permanent.
- **Persistent Logging** — Stores up to 200 recent moderation actions in a DataStore. Viewable in the Log tab across server restarts.
- **Live Server Monitoring** — Real-time player ping and status updates every 5 seconds.
- **Essential Commands** — Kick, Kill, Respawn, Warn, and controlled WalkSpeed modification (with safety cap).
- **Announcements** — Global server broadcasts or targeted modal warnings.
- **Instant Feedback** — Clean on-screen toasts for every action.

### Screenshots

**In-Game Ban Example**  
![Join Error](https://github.com/user-attachments/assets/d2c41f7f-2f8e-44ca-a526-45c070fc23a2)

---

## Installation

This system is extremely lightweight — only **two scripts** required.

### 1. Server Script
- Create a **Script** in `ServerScriptService`
- Name it exactly: `admin panel`
- Paste the server-side code

### 2. Client Script
- Create a **LocalScript** in `StarterPlayer > StarterPlayerScripts`
- Name it exactly: `admin panel`
- Paste the client-side code

---

## Configuration

1. Open the server script (`admin panel` in ServerScriptService)
2. Edit the `CONFIG` table at the top:

```lua
local CONFIG = {
    Admins = {
        977183429, -- ← Add your UserId here
        -- 123456789, -- Additional admins
    },
    BanStoreName = "AdminPanel_BanRecords_v3",
    LogStoreName = "AdminPanel_Logs_v3",
    MaxLogEntries = 200,
    PingInterval = 5,
    MaxSpeed = 300,
}
```

# 🚀 v5 Release: "Tactical Ops: Network"

> **A complete network overhaul and visual refresh.** 
> This update transitions NoVa Panel to a sleek, agency-style interface while bringing true global synchronization to your moderation tools.

---

## ⚠️ Critical Setup Instructions

To ensure v5 functions correctly, you **must** complete the following steps in Roblox Studio:

1. **Admin Configuration:** Add your `UserId`(s) to `CONFIG.Admins` in the server script.
2. **Enable Banning API:** 
   * Select the **Players** service in the Explorer.
   * In the Properties panel, set `BanningEnabled` to `true`. 
   * *(Failure to do this will cause `BanAsync()` and `UnbanAsync()` to error).*
3. **Testing `MessagingService`:** Cross-server sync only relays messages once the game is published and running on **live Roblox servers**. In Studio's local "Play" test, it only loops messages back to itself. This is normal and expected.

---

## ✨ What's New

* 🌑 **"Agency" Theme Redesign:** The panel has shed its purple look for a sleek, high-contrast black/white/grey aesthetic. Want to customize it? You can tune the `GLASS` and `C` tables directly in the LocalScript.
* 🌍 **Global Server Synchronization:** Moderation actions are no longer isolated! **Announcements, Bans, Unbans, and the Audit Log** now utilize `MessagingService` to broadcast to *every* active server simultaneously.
* 📊 **Live Player Stats (FPS & Region):** You can now monitor player performance and origin natively.
  * Clients self-report their **FPS** every few seconds.
  * The server automatically resolves the player's **Country** via `LocalizationService` upon joining.
  * *Both metrics are displayed on the Players page and refresh dynamically every 5 seconds alongside Ping.*

---

## 🐛 Bug Fixes & Patches

* **[FIXED] DataStore Race Conditions:** Switched `saveBans()` from `SetAsync` to `UpdateAsync`. This prevents concurrent server saves from overwriting or erasing each other's UI/fallback ban records.
* **[FIXED] Broken Unban Button:** The command-bar "UNBAN" button sent a target name, but the handler expected a numeric `UserId`. It now intelligently accepts **either** a raw `UserId` or a typed name (verifying it against current ban records).
* **[FIXED] Memory Leaks:** Per-player FPS and country lookup tables previously grew indefinitely. They are now properly garbage-collected upon `PlayerRemoving`.
* **[UI TWEAK] Device Ban Visibility:** Replaced the tiny, easy-to-miss lock icon (🔒) in the Bans list with a highly visible, bold red **DEVICE BANNED** badge.

---
*All previous QOL features (drag-to-move, confirmation dialogues, toast notifications, ban durations, and glass-transparency patches) remain fully intact.*
