local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local DataStoreService    = game:GetService("DataStoreService")
local MessagingService    = game:GetService("MessagingService")
local LocalizationService = game:GetService("LocalizationService")

-- ─────────────────────────────────────────────
--  CONFIGURATION
-- ─────────────────────────────────────────────
local CONFIG = {
	Admins = {
		977183429, -- Add your UserID here
	},
	BanStoreName  = "AdminPanel_BanRecords_v3",
	LogStoreName  = "AdminPanel_Logs_v3",
	BusTopic      = "TacticalAdminBus_v1", -- cross-server channel (Announce/Ban/Unban/Log)
	MaxLogEntries = 200,
	StatsInterval = 5,    -- seconds between ping/FPS/country broadcasts to admins
	MaxSpeed      = 300,  -- sanity clamp for the Speed command
}

local BanStore = DataStoreService:GetDataStore(CONFIG.BanStoreName)
local LogStore = DataStoreService:GetDataStore(CONFIG.LogStoreName)

local BanCache = {} -- [tostring(userId)] = { name, reason, bannedBy, timestamp, expiresAt, deviceBlock }
local LogCache = {} -- array of log entries, oldest first

pcall(function()
	local saved = BanStore:GetAsync("Records")
	if saved then BanCache = saved end
end)
pcall(function()
	local saved = LogStore:GetAsync("Entries")
	if saved then LogCache = saved end
end)

-- Merge-only writes: each server only ever modifies the one key it actually
-- changed, against whatever is currently in the DataStore — never overwrites
-- the whole table with a possibly-stale local snapshot (see bug #3 above).
local function persistBanRecord(userId, record)
	pcall(function()
		BanStore:UpdateAsync("Records", function(old)
			old = old or {}
			old[tostring(userId)] = record
			return old
		end)
	end)
end

local function persistBanRemoval(userId)
	pcall(function()
		BanStore:UpdateAsync("Records", function(old)
			old = old or {}
			old[tostring(userId)] = nil
			return old
		end)
	end)
end

-- ─────────────────────────────────────────────
--  SETUP REMOTE EVENTS
-- ─────────────────────────────────────────────
local AdminFolder = Instance.new("Folder")
AdminFolder.Name = "AdminRemotes"
AdminFolder.Parent = ReplicatedStorage

local function makeRemote(name, class)
	local r = Instance.new(class)
	r.Name = name
	r.Parent = AdminFolder
	return r
end

local RE_Command = makeRemote("AdminCommand", "RemoteEvent")
local RE_Update  = makeRemote("AdminUpdate", "RemoteEvent")
local RF_GetData = makeRemote("GetAdminData", "RemoteFunction")
local RE_Stats   = makeRemote("ReportStats", "RemoteEvent") -- client -> server, self-reported FPS

-- ─────────────────────────────────────────────
--  UTILITY
-- ─────────────────────────────────────────────
local function isAdmin(player)
	for _, id in ipairs(CONFIG.Admins) do
		if player.UserId == id then return true end
	end
	return false
end

local function getPlayerByName(name)
	name = string.lower(name)
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == name or string.lower(p.DisplayName) == name then
			return p
		end
	end
	return nil
end

-- Resolves a Ban target that might be: an online player, a raw UserId, or an
-- offline username. Returns (onlinePlayerOrNil, userId, displayName).
local function resolveBanTarget(input)
	local target = getPlayerByName(input)
	if target then
		return target, target.UserId, target.Name
	end

	local asNumber = tonumber(input)
	if asNumber then
		return nil, asNumber, ("UserId %d"):format(asNumber)
	end

	local ok, id = pcall(function()
		return Players:GetUserIdFromNameAsync(input)
	end)
	if ok and id then
		return nil, id, input
	end

	return nil, nil, nil
end

-- Resolves an Unban target (bug #1): accepts a raw UserId, OR a name that's
-- matched (case-insensitively) against the name stored on an existing ban
-- record, since the command-bar UNBAN button only has a name to go on.
local function resolveUnbanTarget(input)
	local uid = tonumber(input)
	if uid then return uid end

	if type(input) == "string" and input ~= "" then
		local lowered = string.lower(input)
		for key, rec in pairs(BanCache) do
			if rec.name and string.lower(rec.name) == lowered then
				return tonumber(key)
			end
		end
	end

	return nil
end

local function notify(player, message, kind)
	RE_Update:FireClient(player, "Notify", { message = message, kind = kind or "info" })
end

-- ─────────────────────────────────────────────
--  CROSS-SERVER BUS
--  Announce / Ban / Unban / Log all go out over MessagingService so every
--  live server (this one included) ends up in the same state. Each server
--  only ever WRITES to the DataStore once, from the server the command was
--  actually run on — every server (including that one) then reacts to its
--  own copy of the published message to update its local cache + UI. This
--  keeps the "who mutates the cache" logic in exactly one place.
-- ─────────────────────────────────────────────
local function publishBus(kind, payload)
	pcall(function()
		MessagingService:PublishAsync(CONFIG.BusTopic, { kind = kind, payload = payload })
	end)
end

local function broadcastLog(action, adminName, targetName, extra)
	local entry = {
		action   = action,
		admin    = adminName,
		target   = targetName,
		extra    = extra or "",
		time_str = os.date("%H:%M:%S"),
	}
	pcall(function()
		LogStore:UpdateAsync("Entries", function(old)
			old = old or {}
			table.insert(old, entry)
			while #old > CONFIG.MaxLogEntries do
				table.remove(old, 1)
			end
			return old
		end)
	end)
	publishBus("Log", entry)
end

pcall(function()
	MessagingService:SubscribeAsync(CONFIG.BusTopic, function(message)
		local data = message.Data
		if type(data) ~= "table" or type(data.kind) ~= "string" then return end
		local payload = data.payload

		if data.kind == "Announce" then
			for _, p in ipairs(Players:GetPlayers()) do
				RE_Update:FireClient(p, "Announce", payload)
			end

		elseif data.kind == "Log" then
			table.insert(LogCache, payload)
			while #LogCache > CONFIG.MaxLogEntries do
				table.remove(LogCache, 1)
			end
			for _, p in ipairs(Players:GetPlayers()) do
				if isAdmin(p) then RE_Update:FireClient(p, "Log", payload) end
			end

		elseif data.kind == "BanAdded" then
			BanCache[tostring(payload.userId)] = {
				name = payload.name, reason = payload.reason, bannedBy = payload.bannedBy,
				timestamp = payload.timestamp, expiresAt = payload.expiresAt, deviceBlock = payload.deviceBlock,
			}
			for _, p in ipairs(Players:GetPlayers()) do
				if isAdmin(p) then RE_Update:FireClient(p, "BanAdded", payload) end
			end

		elseif data.kind == "BanRemoved" then
			BanCache[tostring(payload.userId)] = nil
			for _, p in ipairs(Players:GetPlayers()) do
				if isAdmin(p) then RE_Update:FireClient(p, "BanRemoved", payload) end
			end
		end
	end)
end)

-- ─────────────────────────────────────────────
--  PER-PLAYER LIVE STATS (ping / fps / country)
-- ─────────────────────────────────────────────
local ClientFPS     = {} -- [userId] = number
local PlayerCountry = {} -- [userId] = "US" etc, or "??" until resolved/on failure

local function resolveCountry(player)
	task.spawn(function()
		local ok, code = pcall(function()
			return LocalizationService:GetCountryRegionForPlayerAsync(player)
		end)
		PlayerCountry[player.UserId] = (ok and code) or "??"
	end)
end

RE_Stats.OnServerEvent:Connect(function(player, fps)
	if type(fps) == "number" then
		ClientFPS[player.UserId] = math.clamp(math.floor(fps), 0, 999)
	end
end)

-- ─────────────────────────────────────────────
--  PLAYER CONNECTIONS
-- ─────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player)
	-- DataStore fallback ban check (BanAsync should already keep them out, but this
	-- covers the case where BanningEnabled hasn't been turned on in Studio yet).
	local uidStr = tostring(player.UserId)
	local rec = BanCache[uidStr]
	if rec then
		if rec.expiresAt ~= -1 and rec.expiresAt < os.time() then
			-- Expired — clean it up instead of kicking.
			BanCache[uidStr] = nil
			persistBanRemoval(player.UserId)
		else
			player:Kick("🚫 BANNED\nReason: " .. tostring(rec.reason))
			return
		end
	end

	resolveCountry(player)

	for _, p in ipairs(Players:GetPlayers()) do
		if isAdmin(p) then
			RE_Update:FireClient(p, "PlayerJoined", { name = player.Name, userId = player.UserId, isAdmin = isAdmin(player) })
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	ClientFPS[player.UserId] = nil
	PlayerCountry[player.UserId] = nil

	for _, p in ipairs(Players:GetPlayers()) do
		if isAdmin(p) then
			RE_Update:FireClient(p, "PlayerLeft", { userId = player.UserId })
		end
	end
end)

-- Live ping/fps/country updates so the Players page doesn't go stale.
task.spawn(function()
	while true do
		task.wait(CONFIG.StatsInterval)
		local admins, snapshot = {}, {}
		for _, p in ipairs(Players:GetPlayers()) do
			table.insert(snapshot, {
				userId  = p.UserId,
				ping    = math.floor(p:GetNetworkPing() * 1000),
				fps     = ClientFPS[p.UserId] or 0,
				country = PlayerCountry[p.UserId] or "??",
			})
			if isAdmin(p) then table.insert(admins, p) end
		end
		for _, a in ipairs(admins) do
			RE_Update:FireClient(a, "StatsUpdate", snapshot)
		end
	end
end)

-- ─────────────────────────────────────────────
--  DATA FETCHING (Initial UI Load)
-- ─────────────────────────────────────────────
RF_GetData.OnServerInvoke = function(player)
	if not isAdmin(player) then return nil end
	local data = { players = {}, bans = {}, log = LogCache }

	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(data.players, {
			name        = p.Name,
			displayName = p.DisplayName,
			userId      = p.UserId,
			ping        = math.floor(p:GetNetworkPing() * 1000),
			fps         = ClientFPS[p.UserId] or 0,
			country     = PlayerCountry[p.UserId] or "??",
			isAdmin     = isAdmin(p),
		})
	end

	for uid, rec in pairs(BanCache) do
		table.insert(data.bans, {
			userId      = tonumber(uid),
			name        = rec.name,
			reason      = rec.reason,
			bannedBy    = rec.bannedBy,
			timestamp   = rec.timestamp,
			expiresAt   = rec.expiresAt,
			deviceBlock = rec.deviceBlock,
		})
	end

	return data
end

-- ─────────────────────────────────────────────
--  COMMAND PROCESSING
-- ─────────────────────────────────────────────
RE_Command.OnServerEvent:Connect(function(sender, cmd, data)
	if not isAdmin(sender) then return end

	local targetName = data.target or ""
	local reason = (data.reason ~= nil and data.reason ~= "") and data.reason or "No reason provided"

	if cmd == "Ban" then
		local target, targetId, displayName = resolveBanTarget(targetName)

		if not targetId then
			notify(sender, "Could not find a player or valid username: " .. targetName, "error")
			return
		end
		if target and isAdmin(target) then
			notify(sender, "Cannot ban another admin.", "error")
			return
		end

		local days = tonumber(data.duration) or 0
		local durationSeconds = (days <= 0) and -1 or math.floor(days * 86400)
		local deviceBlock = data.deviceBlock == true

		-- Native platform ban. Requires Players.BanningEnabled to be on (see header).
		local banOk = pcall(function()
			Players:BanAsync({
				UserIds            = { targetId },
				ApplyToUniverse    = true,
				Duration           = durationSeconds,
				DisplayReason      = reason,
				PrivateReason      = reason .. " (banned by " .. sender.Name .. ")",
				ExcludeAltAccounts = false, -- always propagate to known alt accounts
				ApplyDeviceBlock   = deviceBlock,
			})
		end)

		local expiresAt = (durationSeconds == -1) and -1 or (os.time() + durationSeconds)
		local timestamp = os.time()
		persistBanRecord(targetId, {
			name = displayName, reason = reason, bannedBy = sender.Name,
			timestamp = timestamp, expiresAt = expiresAt, deviceBlock = deviceBlock,
		})

		if target then
			target:Kick("🚫 Banned by " .. sender.Name .. "\nReason: " .. reason)
		end

		publishBus("BanAdded", {
			userId = targetId, name = displayName, reason = reason, bannedBy = sender.Name,
			timestamp = timestamp, expiresAt = expiresAt, deviceBlock = deviceBlock,
		})

		local durText = (days > 0) and (days .. "d") or "permanent"
		broadcastLog("BAN", sender.Name, displayName, reason .. " [" .. durText .. (deviceBlock and ", device-blocked" or "") .. "]")

		if banOk then
			notify(sender, "Banned " .. displayName .. " (" .. durText .. ")", "success")
		else
			notify(sender, "Banned " .. displayName .. " locally, but the native ban API failed — check that Players.BanningEnabled is on in Studio.", "warning")
		end

	elseif cmd == "Unban" then
		-- Accepts either data.userId (raw id, used by the per-row Unban button)
		-- or data.target (a name, used by the command-bar UNBAN button) — see
		-- bug #1 in the header.
		local uid = resolveUnbanTarget(data.userId or data.target)
		if not uid then
			notify(sender, "No ban record found for: " .. tostring(data.userId or data.target), "error")
			return
		end

		pcall(function()
			Players:UnbanAsync({ UserIds = { uid }, ApplyToUniverse = true })
		end)

		local rec = BanCache[tostring(uid)]
		persistBanRemoval(uid)
		publishBus("BanRemoved", { userId = uid })

		local name = rec and rec.name or tostring(uid)
		broadcastLog("UNBAN", sender.Name, name, "")
		notify(sender, "Unbanned " .. name, "success")

	elseif cmd == "Kick" then
		local target = getPlayerByName(targetName)
		if not target then
			notify(sender, "Player not found: " .. targetName, "error")
			return
		end
		if isAdmin(target) then
			notify(sender, "Cannot kick another admin.", "error")
			return
		end
		target:Kick("Kicked by " .. sender.Name .. "\nReason: " .. reason)
		broadcastLog("KICK", sender.Name, target.Name, reason)
		notify(sender, "Kicked " .. target.Name, "success")

	elseif cmd == "Kill" then
		local target = getPlayerByName(targetName)
		if not target then
			notify(sender, "Player not found: " .. targetName, "error")
			return
		end
		if isAdmin(target) then
			notify(sender, "Cannot kill another admin.", "error")
			return
		end
		local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if not hum then
			notify(sender, target.Name .. " has no character to kill right now.", "error")
			return
		end
		hum.Health = 0
		broadcastLog("KILL", sender.Name, target.Name, reason)
		notify(sender, "Killed " .. target.Name, "success")

	elseif cmd == "Speed" then
		local target = getPlayerByName(targetName)
		if not target then
			notify(sender, "Player not found: " .. targetName, "error")
			return
		end
		local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if not hum then
			notify(sender, target.Name .. " has no character right now.", "error")
			return
		end
		local speed = tonumber(data.value) or tonumber(data.reason) or 16
		speed = math.clamp(speed, 0, CONFIG.MaxSpeed)
		hum.WalkSpeed = speed
		broadcastLog("SPEED", sender.Name, target.Name, "Speed: " .. tostring(speed))
		notify(sender, "Set " .. target.Name .. "'s speed to " .. speed, "success")

	elseif cmd == "Respawn" then
		local target = getPlayerByName(targetName)
		if not target then
			notify(sender, "Player not found: " .. targetName, "error")
			return
		end
		target:LoadCharacter()
		broadcastLog("RESPAWN", sender.Name, target.Name, "")
		notify(sender, "Respawned " .. target.Name, "success")

	elseif cmd == "Warn" then
		local target = getPlayerByName(targetName)
		if not target then
			notify(sender, "Player not found: " .. targetName, "error")
			return
		end
		RE_Update:FireClient(target, "ReceiveWarn", { admin = sender.Name, reason = reason })
		broadcastLog("WARN", sender.Name, target.Name, reason)
		notify(sender, "Warned " .. target.Name, "success")

	elseif cmd == "Announce" then
		local msg = data.message or ""
		if msg == "" then return end
		publishBus("Announce", { message = msg, admin = sender.Name })
		broadcastLog("ANNOUNCE", sender.Name, "ALL", msg)
		notify(sender, "Broadcast sent to all servers", "success")
	end
end)
