# NoVa Panel — Roblox Admin & Moderation System

A sleek, high-performance administration panel for Roblox experiences. Built for serious developers who need clean, reliable, and powerful moderation tools.

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
