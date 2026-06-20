

		local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local AdminFolder = ReplicatedStorage:WaitForChild("AdminRemotes", 10)
if not AdminFolder then return end

local RE_Command = AdminFolder:WaitForChild("AdminCommand")
local RE_Update  = AdminFolder:WaitForChild("AdminUpdate")
local RF_GetData = AdminFolder:WaitForChild("GetAdminData")

-- ─────────────────────────────────────────────
--  SHARED STATE & CONSTANTS
-- ─────────────────────────────────────────────
local State = {
	open    = false,
	page    = "Players",
	players = {},
}

local function px(x, y) return UDim2.new(0, x, 0, y) end
local PANEL_W, PANEL_H = 960, 600

local C = {
	BgOuter   = Color3.fromRGB(10, 10, 15),
	BgInner   = Color3.fromRGB(18, 18, 24),
	Card      = Color3.fromRGB(30, 30, 40),
	CardHover = Color3.fromRGB(40, 40, 54),
	Accent    = Color3.fromRGB(150, 70, 255),
	AccentDim = Color3.fromRGB(100, 40, 180),
	Green     = Color3.fromRGB(50, 255, 130),
	Yellow    = Color3.fromRGB(255, 200, 50),
	Red       = Color3.fromRGB(255, 60, 80),
	TextHi    = Color3.fromRGB(255, 255, 255),
	TextMid   = Color3.fromRGB(180, 180, 200),
	TextLo    = Color3.fromRGB(110, 110, 130),
	Border    = Color3.fromRGB(60, 60, 80),
}

local TWEEN_FAST   = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SMOOTH = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- ─────────────────────────────────────────────
--  ⚙ GLASS / TRANSPARENCY SETTINGS — tune the look here, and ONLY here.
--  Every value below is a BackgroundTransparency: 0 = fully solid, 1 = fully
--  invisible. Valid range is 0 to 1 — never negative, never above 1. Nothing
--  else in this script secretly adds extra transparency on top of these.
-- ─────────────────────────────────────────────
local GLASS = {
	Panel     = 0.10, -- the main panel's own background (mostly hidden behind the panes below)
	TitleBar  = 0.08, -- top bar with "TACTICAL OPS"
	Sidebar   = 0.12, -- left nav column
	CmdBar    = 0.10, -- bottom command bar on the Players page
	Card      = 0.06, -- player / ban / log list rows
	CardHover = 0.0,  -- player row when you mouse over it (fully solid for emphasis)
	Input     = 0.12, -- text boxes (target/reason/duration) and the device-block toggle
	Button    = 0.08, -- KICK/BAN/KILL/etc and nav buttons (idle state)
	Toast     = 0.05, -- success/error notification popups, top-right
	Banner    = 0.05, -- the centered server broadcast banner
	Modal     = 0.03, -- the full-screen "WARNING" popup
	Hint      = 0.15, -- the small "F4 - OPS COM" pill shown when the panel is closed
	BlurSize  = 12,   -- how strong the background blur gets while the panel is open (0-56ish)
}

-- ─────────────────────────────────────────────
--  GUI BUILDER HELPERS
-- ─────────────────────────────────────────────
local function AddCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

local function AddStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or C.Border
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function AddPadding(parent, all)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all); p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, all); p.PaddingRight = UDim.new(0, all)
	p.Parent = parent
	return p
end

-- Subtle white sheen — implemented as a SEPARATE overlay Frame sitting on top
-- of `parent`, with its own UIGradient.Transparency. This is deliberate: a
-- UIGradient.Transparency on `parent` itself would REPLACE parent's own
-- BackgroundTransparency rather than blend with it (that was the bug). By
-- putting the gradient on a dedicated overlay instead, the surface underneath
-- keeps exactly the transparency you gave it in the GLASS table above.
local function AddGlassSheen(parent, rotation)
	local overlay = Instance.new("Frame")
	overlay.Name = "GlassSheen"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	overlay.BorderSizePixel = 0
	overlay.Parent = parent

	local parentCorner = parent:FindFirstChildOfClass("UICorner")
	if parentCorner then
		local c = Instance.new("UICorner")
		c.CornerRadius = parentCorner.CornerRadius
		c.Parent = overlay
	end

	local g = Instance.new("UIGradient")
	g.Rotation = rotation or 100
	-- These numbers ARE the overlay's final rendered transparency (since a
	-- UIGradient.Transparency sequence overrides whatever BackgroundTransparency
	-- the overlay starts with) — kept high so the highlight stays faint, and
	-- always within 0-1.
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.90),
		NumberSequenceKeypoint.new(0.5, 0.97),
		NumberSequenceKeypoint.new(1, 0.92),
	})
	g.Parent = overlay
	return overlay
end

-- A gradient riding along a UIStroke so the panel's edge catches light like
-- a glass rim instead of being a flat single-color outline. This only ever
-- touches the stroke's Color, never any Transparency property, so it can't
-- cause the override bug described above.
local function AddEdgeLight(stroke, accentColor)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, accentColor or C.Accent),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	g.Parent = stroke
	return g
end

local function GetPingColor(ping)
	if ping < 100 then return C.Green end
	if ping < 200 then return C.Yellow end
	return C.Red
end

local function FormatExpiry(expiresAt)
	if not expiresAt or expiresAt == -1 then return "Permanent" end
	local remaining = expiresAt - os.time()
	if remaining <= 0 then return "Expired" end
	local days = math.floor(remaining / 86400)
	if days >= 1 then return days .. "d remaining" end
	local hours = math.floor(remaining / 3600)
	if hours >= 1 then return hours .. "h remaining" end
	return math.max(1, math.floor(remaining / 60)) .. "m remaining"
end

-- ─────────────────────────────────────────────
--  SHARED SCREENGUI  (built for EVERY player, admin or not)
-- ─────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NoVa Panel"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Background blur used for the panel's glass effect. Created once, shared.
local Blur = Lighting:FindFirstChild("TacticalAdminBlur")
if not Blur then
	Blur = Instance.new("BlurEffect")
	Blur.Name = "TacticalAdminBlur"
	Blur.Size = 0
	Blur.Parent = Lighting
end

-- ── Server broadcast banner (everyone can receive this) ──
local function ShowAnnouncement(data)
	local annFrame = Instance.new("Frame", ScreenGui)
	annFrame.Size = px(440, 110)
	annFrame.Position = UDim2.new(0.5, -220, 0, -120)
	annFrame.BackgroundColor3 = C.BgInner
	annFrame.BackgroundTransparency = GLASS.Banner
	AddCorner(annFrame, 14)
	local stroke = AddStroke(annFrame, C.Accent, 2)
	AddGlassSheen(annFrame)

	local icon = Instance.new("TextLabel", annFrame)
	icon.Size = px(40, 40)
	icon.Position = px(16, 16)
	icon.BackgroundTransparency = 1
	icon.Text = "📢"
	icon.TextSize = 24

	local title = Instance.new("TextLabel", annFrame)
	title.Size = px(300, 20)
	title.Position = px(66, 16)
	title.BackgroundTransparency = 1
	title.TextColor3 = C.Accent
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBlack
	title.Text = "SYSTEM BROADCAST - " .. string.upper(data.admin)
	title.TextSize = 12

	local txt = Instance.new("TextLabel", annFrame)
	txt.Size = UDim2.new(1, -82, 1, -46)
	txt.Position = px(66, 36)
	txt.BackgroundTransparency = 1
	txt.TextColor3 = C.TextHi
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextYAlignment = Enum.TextYAlignment.Top
	txt.Font = Enum.Font.GothamMedium
	txt.TextSize = 15
	txt.Text = data.message
	txt.TextWrapped = true

	TweenService:Create(annFrame, TWEEN_SMOOTH, { Position = UDim2.new(0.5, -220, 0, 40) }):Play()

	task.delay(6, function()
		local fade = TweenService:Create(annFrame, TWEEN_FAST, { BackgroundTransparency = 1 })
		TweenService:Create(icon, TWEEN_FAST, { TextTransparency = 1 }):Play()
		TweenService:Create(title, TWEEN_FAST, { TextTransparency = 1 }):Play()
		TweenService:Create(txt, TWEEN_FAST, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TWEEN_FAST, { Transparency = 1 }):Play()
		fade:Play()
		fade.Completed:Wait()
		annFrame:Destroy()
	end)
end

-- ── Personal warning modal (sent to a specific player, admin or not) ──
local function ShowWarnModal(data)
	local Dim = Instance.new("Frame", ScreenGui)
	Dim.Size = UDim2.new(1, 0, 1, 0)
	Dim.BackgroundColor3 = Color3.new(0, 0, 0)
	Dim.BackgroundTransparency = 1
	Dim.ZIndex = 90
	Dim.BorderSizePixel = 0

	local Modal = Instance.new("Frame", ScreenGui)
	Modal.Size = px(420, 220)
	Modal.AnchorPoint = Vector2.new(0.5, 0.5)
	Modal.Position = UDim2.new(0.5, 0, 0.5, 0)
	Modal.BackgroundColor3 = C.BgInner
	Modal.BackgroundTransparency = GLASS.Modal
	Modal.ZIndex = 91
	AddCorner(Modal, 16)
	AddStroke(Modal, C.Red, 2)
	AddGlassSheen(Modal)

	local icon = Instance.new("TextLabel", Modal)
	icon.Size = px(60, 50)
	icon.Position = UDim2.new(0.5, -30, 0, 18)
	icon.BackgroundTransparency = 1
	icon.Text = "⚠️"
	icon.TextSize = 34
	icon.ZIndex = 92

	local title = Instance.new("TextLabel", Modal)
	title.Size = UDim2.new(1, -40, 0, 24)
	title.Position = px(20, 76)
	title.BackgroundTransparency = 1
	title.TextColor3 = C.Red
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 17
	title.Text = "WARNING FROM " .. string.upper(data.admin)
	title.ZIndex = 92

	local body = Instance.new("TextLabel", Modal)
	body.Size = UDim2.new(1, -40, 0, 50)
	body.Position = px(20, 104)
	body.BackgroundTransparency = 1
	body.TextColor3 = C.TextMid
	body.Font = Enum.Font.GothamMedium
	body.TextSize = 14
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = data.reason
	body.ZIndex = 92

	local okBtn = Instance.new("TextButton", Modal)
	okBtn.Size = px(140, 38)
	okBtn.AnchorPoint = Vector2.new(0.5, 0)
	okBtn.Position = UDim2.new(0.5, 0, 1, -54)
	okBtn.BackgroundColor3 = C.Red
	okBtn.TextColor3 = C.TextHi
	okBtn.Text = "I UNDERSTAND"
	okBtn.Font = Enum.Font.GothamBold
	okBtn.TextSize = 13
	okBtn.ZIndex = 92
	okBtn.AutoButtonColor = false
	AddCorner(okBtn, 8)

	TweenService:Create(Dim, TWEEN_SMOOTH, { BackgroundTransparency = 0.55 }):Play()

	local dismissed = false
	local function dismiss()
		if dismissed then return end
		dismissed = true
		TweenService:Create(Dim, TWEEN_FAST, { BackgroundTransparency = 1 }):Play()
		Modal:Destroy()
		task.delay(0.2, function() Dim:Destroy() end)
	end
	okBtn.MouseButton1Click:Connect(dismiss)
	task.delay(15, dismiss)
end

-- ─────────────────────────────────────────────
--  ADMIN CHECK
-- ─────────────────────────────────────────────
local initialData = RF_GetData:InvokeServer()
local isAdminClient = initialData ~= nil

-- Forward-declared so the universal listener below can reach it once the full
-- admin panel (further down this script) assigns it a real function.
local AdminEventRouter = nil

RE_Update.OnClientEvent:Connect(function(eventType, data)
	if eventType == "Announce" then
		ShowAnnouncement(data)
	elseif eventType == "ReceiveWarn" then
		ShowWarnModal(data)
	elseif isAdminClient and AdminEventRouter then
		AdminEventRouter(eventType, data)
	end
end)

if not isAdminClient then
	return -- Non-admins stop here, but they keep receiving broadcasts/warnings above.
end

State.players = initialData.players or {}

-- ─────────────────────────────────────────────
--  ADMIN PANEL — MAIN UI CONSTRUCTION
-- ─────────────────────────────────────────────

-- Hint Frame
local HintFrame = Instance.new("Frame")
HintFrame.Size = px(130, 36)
HintFrame.Position = UDim2.new(0, 24, 0, 24)
HintFrame.BackgroundColor3 = C.BgOuter
HintFrame.BackgroundTransparency = GLASS.Hint
AddCorner(HintFrame, 18)
AddStroke(HintFrame, C.Accent, 1.5)
HintFrame.Parent = ScreenGui

local HintText = Instance.new("TextLabel", HintFrame)
HintText.Size = UDim2.new(1, 0, 1, 0)
HintText.BackgroundTransparency = 1
HintText.TextColor3 = C.TextHi
HintText.Text = "F4 - OPS COM"
HintText.Font = Enum.Font.GothamBold
HintText.TextSize = 13

-- Toast container (top-right) — this is the "output" feedback for every command.
local ToastContainer = Instance.new("Frame")
ToastContainer.Size = UDim2.new(0, 320, 1, -40)
ToastContainer.Position = UDim2.new(1, -340, 0, 20)
ToastContainer.BackgroundTransparency = 1
ToastContainer.Parent = ScreenGui
ToastContainer.ZIndex = 80
local ToastLayout = Instance.new("UIListLayout", ToastContainer)
ToastLayout.Padding = UDim.new(0, 8)
ToastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ToastLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function ShowToast(message, kind)
	local color = C.Accent
	if kind == "success" then color = C.Green
	elseif kind == "error" then color = C.Red
	elseif kind == "warning" then color = C.Yellow end

	local toast = Instance.new("Frame", ToastContainer)
	toast.Size = UDim2.new(0, 300, 0, 0)
	toast.AutomaticSize = Enum.AutomaticSize.Y
	toast.BackgroundColor3 = C.BgInner
	toast.BackgroundTransparency = GLASS.Toast
	toast.ClipsDescendants = true
	toast.ZIndex = 80
	AddCorner(toast, 10)
	local stroke = AddStroke(toast, color, 1.5)

	local bar = Instance.new("Frame", toast)
	bar.Size = UDim2.new(0, 3, 1, 0)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.ZIndex = 81

	local txt = Instance.new("TextLabel", toast)
	txt.Size = UDim2.new(1, -28, 0, 0)
	txt.AutomaticSize = Enum.AutomaticSize.Y
	txt.Position = px(16, 8)
	txt.BackgroundTransparency = 1
	txt.TextColor3 = C.TextHi
	txt.TextWrapped = true
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.Font = Enum.Font.GothamMedium
	txt.TextSize = 13
	txt.Text = message
	txt.ZIndex = 81
	local pad = Instance.new("UIPadding", txt)
	pad.PaddingBottom = UDim.new(0, 8)

	task.delay(4, function()
		if toast and toast.Parent then
			local fade = TweenService:Create(toast, TWEEN_FAST, { BackgroundTransparency = 1 })
			TweenService:Create(stroke, TWEEN_FAST, { Transparency = 1 }):Play()
			TweenService:Create(txt, TWEEN_FAST, { TextTransparency = 1 }):Play()
			fade:Play()
			fade.Completed:Wait()
			toast:Destroy()
		end
	end)
end

-- Main Panel — AnchorPoint centers it regardless of size, which both fixes the
-- old open/close scale animation and makes drag math simple.
local Panel = Instance.new("CanvasGroup")
Panel.Size = px(PANEL_W, PANEL_H)
Panel.AnchorPoint = Vector2.new(0.5, 0.5)
Panel.Position = UDim2.new(0.5, 0, 0.5, 0)
Panel.BackgroundColor3 = C.BgOuter
Panel.BackgroundTransparency = GLASS.Panel
Panel.GroupTransparency = 1
Panel.ClipsDescendants = true -- keeps square-cornered children from poking past the rounded corner
Panel.Visible = false
AddCorner(Panel, 14)
local PanelStroke = AddStroke(Panel, C.Border, 2)
AddEdgeLight(PanelStroke, C.Accent)
AddGlassSheen(Panel)
Panel.Parent = ScreenGui

local TopGlow = Instance.new("Frame", Panel)
TopGlow.Size = UDim2.new(1, 0, 0, 2)
TopGlow.BackgroundColor3 = C.Accent
TopGlow.BorderSizePixel = 0

-- Title Bar (also the drag handle)
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 56)
TitleBar.BackgroundColor3 = C.BgInner
TitleBar.BackgroundTransparency = GLASS.TitleBar
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Panel
local TitleLine = Instance.new("Frame", TitleBar)
TitleLine.Size = UDim2.new(1, 0, 0, 1)
TitleLine.Position = UDim2.new(0, 0, 1, -1)
TitleLine.BackgroundColor3 = C.Border
TitleLine.BorderSizePixel = 0

local TitleText = Instance.new("TextLabel")
TitleText.Size = px(220, 56)
TitleText.Position = px(24, 0)
TitleText.BackgroundTransparency = 1
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.TextColor3 = C.Accent
TitleText.Text = "NoVa Panel"
TitleText.Font = Enum.Font.GothamBlack
TitleText.TextSize = 20
TitleText.Parent = TitleBar

local DragHint = Instance.new("TextLabel", TitleBar)
DragHint.Size = px(160, 16)
DragHint.Position = px(24, 36)
DragHint.BackgroundTransparency = 1
DragHint.TextXAlignment = Enum.TextXAlignment.Left
DragHint.TextColor3 = C.TextLo
DragHint.Text = "⠿ drag to move"
DragHint.Font = Enum.Font.Gotham
DragHint.TextSize = 11

local UserBadge = Instance.new("TextLabel", TitleBar)
UserBadge.Size = px(150, 56)
UserBadge.Position = UDim2.new(1, -174, 0, 0)
UserBadge.BackgroundTransparency = 1
UserBadge.TextXAlignment = Enum.TextXAlignment.Right
UserBadge.TextColor3 = C.TextMid
UserBadge.Text = "⚡ " .. LocalPlayer.Name
UserBadge.Font = Enum.Font.GothamMedium
UserBadge.TextSize = 14

-- ── Drag-to-move ──
do
	local dragging = false
	local dragInput, dragStart, startPos

	local function clampToScreen(pos)
		local camera = workspace.CurrentCamera
		local vp = (camera and camera.ViewportSize) or Vector2.new(1280, 720)
		local halfW, halfH = Panel.AbsoluteSize.X / 2, Panel.AbsoluteSize.Y / 2
		local maxX = math.max(0, vp.X / 2 - halfW + 60)
		local maxY = math.max(0, vp.Y / 2 - halfH + 60)
		local x = math.clamp(pos.X.Offset, -maxX, maxX)
		local y = math.clamp(pos.Y.Offset, -maxY, maxY)
		return UDim2.new(pos.X.Scale, x, pos.Y.Scale, y)
	end

	TitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Panel.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	TitleBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local delta = input.Position - dragStart
			Panel.Position = clampToScreen(UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
				))
		end
	end)
end

-- Navigation Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 180, 1, -56)
Sidebar.Position = UDim2.new(0, 0, 0, 56)
Sidebar.BackgroundColor3 = C.BgInner
Sidebar.BackgroundTransparency = GLASS.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Panel

local SideLine = Instance.new("Frame", Panel)
SideLine.Size = UDim2.new(0, 1, 1, -56)
SideLine.Position = UDim2.new(0, 179, 0, 56)
SideLine.BackgroundColor3 = C.Border
SideLine.BorderSizePixel = 0

local NavList = Instance.new("UIListLayout", Sidebar)
NavList.Padding = UDim.new(0, 8)
NavList.HorizontalAlignment = Enum.HorizontalAlignment.Center
AddPadding(Sidebar, 12)

local Pages = {}
local NavButtons = {}
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -180, 1, -56)
ContentArea.Position = UDim2.new(0, 180, 0, 56)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = Panel

local function MakePage(name)
	local p = Instance.new("Frame")
	p.Size = UDim2.new(1, 0, 1, 0)
	p.BackgroundTransparency = 1
	p.Visible = false
	p.Parent = ContentArea
	Pages[name] = p
	return p
end

local PagePlayers  = MakePage("Players")
local PageBans     = MakePage("Bans")
local PageLog      = MakePage("Log")
local PageAnnounce = MakePage("Announce")

local function SetPage(pageName)
	State.page = pageName
	for k, v in pairs(Pages) do
		v.Visible = (k == pageName)
	end
	for k, btn in pairs(NavButtons) do
		local active = (k == pageName)
		TweenService:Create(btn, TWEEN_FAST, {
			BackgroundColor3 = active and C.AccentDim or C.Card,
			TextColor3 = active and C.TextHi or C.TextMid,
		}):Play()
	end
end

local function MakeNavBtn(name, icon)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 44)
	b.BackgroundColor3 = C.Card
	b.BackgroundTransparency = GLASS.Button
	b.TextColor3 = C.TextMid
	b.Text = "   " .. icon .. "  " .. name
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.AutoButtonColor = false
	AddCorner(b, 10)
	b.Parent = Sidebar

	b.MouseEnter:Connect(function()
		if State.page ~= name then
			TweenService:Create(b, TWEEN_FAST, { BackgroundColor3 = C.CardHover, TextColor3 = C.TextHi }):Play()
		end
	end)
	b.MouseLeave:Connect(function()
		if State.page ~= name then
			TweenService:Create(b, TWEEN_FAST, { BackgroundColor3 = C.Card, TextColor3 = C.TextMid }):Play()
		end
	end)

	b.MouseButton1Click:Connect(function() SetPage(name) end)
	NavButtons[name] = b
end

MakeNavBtn("Players", "👥")
MakeNavBtn("Bans", "🚫")
MakeNavBtn("Log", "📋")
MakeNavBtn("Announce", "📢")

-- ─────────────────────────────────────────────
--  SHARED INPUT/BUTTON HELPERS
-- ─────────────────────────────────────────────
local function MakeInput(parent, placeholder, width, numericOnly)
	local box = Instance.new("TextBox", parent)
	box.Size = px(width, 40)
	box.BackgroundColor3 = C.BgOuter
	box.BackgroundTransparency = GLASS.Input
	box.TextColor3 = C.TextHi
	box.PlaceholderColor3 = C.TextLo
	box.PlaceholderText = placeholder
	box.Text = ""
	box.Font = Enum.Font.Code
	box.TextSize = 14
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	AddCorner(box, 8)
	local stroke = AddStroke(box, C.Border, 1)

	local p = Instance.new("UIPadding", box)
	p.PaddingLeft = UDim.new(0, 12); p.PaddingRight = UDim.new(0, 12)

	box.Focused:Connect(function()
		TweenService:Create(stroke, TWEEN_FAST, { Color = C.Accent }):Play()
	end)
	box.FocusLost:Connect(function()
		TweenService:Create(stroke, TWEEN_FAST, { Color = C.Border }):Play()
	end)

	if numericOnly then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local filtered = box.Text:gsub("%D", "")
			if filtered ~= box.Text then box.Text = filtered end
		end)
	end

	return box
end

local function MakeToggle(parent, label, width)
	local b = Instance.new("TextButton", parent)
	b.Size = px(width, 40)
	b.BackgroundColor3 = C.BgOuter
	b.BackgroundTransparency = GLASS.Input
	b.TextColor3 = C.TextLo
	b.Text = "🔓 " .. label .. ": OFF"
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.AutoButtonColor = false
	AddCorner(b, 8)
	local stroke = AddStroke(b, C.Border, 1)

	local enabled = false
	b.MouseButton1Click:Connect(function()
		enabled = not enabled
		b.Text = (enabled and "🔒 " or "🔓 ") .. label .. ": " .. (enabled and "ON" or "OFF")
		TweenService:Create(b, TWEEN_FAST, { TextColor3 = enabled and C.Yellow or C.TextLo }):Play()
		TweenService:Create(stroke, TWEEN_FAST, { Color = enabled and C.Yellow or C.Border }):Play()
	end)

	return b, function() return enabled end
end

-- ─────────────────────────────────────────────
--  PLAYERS PAGE
-- ─────────────────────────────────────────────
local P_Scroll = Instance.new("ScrollingFrame", PagePlayers)
P_Scroll.Size = UDim2.new(1, -32, 1, -160)
P_Scroll.Position = px(16, 16)
P_Scroll.BackgroundTransparency = 1
P_Scroll.ScrollBarThickness = 4
P_Scroll.ScrollBarImageColor3 = C.TextLo
P_Scroll.BorderSizePixel = 0
local P_List = Instance.new("UIListLayout", P_Scroll)
P_List.Padding = UDim.new(0, 8)

-- Command Bar (two rows: inputs, then action buttons)
local CmdBar = Instance.new("Frame", PagePlayers)
CmdBar.Size = UDim2.new(1, -32, 0, 120)
CmdBar.Position = UDim2.new(0, 16, 1, -136)
CmdBar.BackgroundColor3 = C.BgInner
CmdBar.BackgroundTransparency = GLASS.CmdBar
AddCorner(CmdBar, 12)
AddStroke(CmdBar, C.Border, 1)
AddGlassSheen(CmdBar)

local CmdLayout = Instance.new("UIListLayout", CmdBar)
CmdLayout.Padding = UDim.new(0, 8)
AddPadding(CmdBar, 10)

local InputRow = Instance.new("Frame", CmdBar)
InputRow.Size = UDim2.new(1, 0, 0, 40)
InputRow.BackgroundTransparency = 1
local InputLayout = Instance.new("UIListLayout", InputRow)
InputLayout.FillDirection = Enum.FillDirection.Horizontal
InputLayout.Padding = UDim.new(0, 10)
InputLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local ButtonRow = Instance.new("Frame", CmdBar)
ButtonRow.Size = UDim2.new(1, 0, 0, 40)
ButtonRow.BackgroundTransparency = 1
local ButtonLayout = Instance.new("UIListLayout", ButtonRow)
ButtonLayout.FillDirection = Enum.FillDirection.Horizontal
ButtonLayout.Padding = UDim.new(0, 8)
ButtonLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local TgtBox = MakeInput(InputRow, "Target name or UserId...", 200)
local RsnBox = MakeInput(InputRow, "Reason...", 200)
local DurBox = MakeInput(InputRow, "Ban: days (0=perm)", 140, true)
local _, GetDeviceBlock = MakeToggle(InputRow, "Device Block", 140)

local function MakeCmdBtn(label, color, cmd, confirmNeeded)
	local b = Instance.new("TextButton", ButtonRow)
	b.Size = px(86, 40)
	b.BackgroundColor3 = C.Card
	b.BackgroundTransparency = GLASS.Button
	b.TextColor3 = color
	b.Text = label
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.AutoButtonColor = false
	AddCorner(b, 8)
	local stroke = AddStroke(b, C.Border, 1)

	b.MouseEnter:Connect(function()
		TweenService:Create(b, TWEEN_FAST, { BackgroundColor3 = color, TextColor3 = C.BgOuter }):Play()
		TweenService:Create(stroke, TWEEN_FAST, { Color = color }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TWEEN_FAST, { BackgroundColor3 = C.Card, TextColor3 = color }):Play()
		TweenService:Create(stroke, TWEEN_FAST, { Color = C.Border }):Play()
	end)

	local confirming = false
	b.MouseButton1Click:Connect(function()
		if TgtBox.Text == "" then
			ShowToast("Enter a target name or UserId first.", "error")
			return
		end

		if confirmNeeded and not confirming then
			confirming = true
			b.Text = "CONFIRM?"
			task.delay(3, function()
				if confirming then
					confirming = false
					b.Text = label
				end
			end)
			return
		end

		confirming = false
		b.Text = label

		RE_Command:FireServer(cmd, {
			target      = TgtBox.Text,
			reason      = RsnBox.Text,
			value       = RsnBox.Text,
			duration    = DurBox.Text,
			deviceBlock = GetDeviceBlock(),
		})
	end)

	return b
end

MakeCmdBtn("KICK",    C.Yellow, "Kick",    true)
MakeCmdBtn("BAN",     C.Red,    "Ban",     true)
MakeCmdBtn("KILL",    C.Red,    "Kill",    true)
MakeCmdBtn("UNBAN",   C.Green,  "Unban",   true) -- Added between Kill and Speed
MakeCmdBtn("SPEED",   C.Accent, "Speed",   false)
MakeCmdBtn("WARN",    C.Yellow, "Warn",    false)
MakeCmdBtn("RESPAWN", C.Accent, "Respawn", false)

local PlayerRows = {} -- [userId] = { frame, dot, pingLabel }

local function UpdatePlayersCanvas()
	local count = 0
	for _ in pairs(PlayerRows) do count = count + 1 end
	P_Scroll.CanvasSize = UDim2.new(0, 0, 0, count * 54)
end

local function CreatePlayerRow(p)
	if PlayerRows[p.userId] then return end

	local r = Instance.new("Frame", P_Scroll)
	r.Size = UDim2.new(1, 0, 0, 46)
	r.BackgroundColor3 = C.Card
	r.BackgroundTransparency = GLASS.Card
	AddCorner(r, 10)
	AddStroke(r, C.Border, 1)

	r.MouseEnter:Connect(function() TweenService:Create(r, TWEEN_FAST, { BackgroundTransparency = GLASS.CardHover }):Play() end)
	r.MouseLeave:Connect(function() TweenService:Create(r, TWEEN_FAST, { BackgroundTransparency = GLASS.Card }):Play() end)

	local pingColor = GetPingColor(p.ping or 0)

	local dot = Instance.new("Frame", r)
	dot.Size = px(10, 10)
	dot.Position = UDim2.new(0, 14, 0.5, -5)
	dot.BackgroundColor3 = pingColor
	AddCorner(dot, 10)

	local t = Instance.new("TextLabel", r)
	t.Size = UDim2.new(1, -150, 1, 0)
	t.Position = px(36, 0)
	t.BackgroundTransparency = 1
	t.TextColor3 = C.TextHi
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = p.name .. (p.isAdmin and "  ⚡" or "") .. "   |   ID: " .. p.userId
	t.Font = Enum.Font.GothamMedium
	t.TextSize = 14

	local pt = Instance.new("TextLabel", r)
	pt.Size = px(100, 46)
	pt.Position = UDim2.new(1, -116, 0, 0)
	pt.BackgroundTransparency = 1
	pt.TextXAlignment = Enum.TextXAlignment.Right
	pt.TextColor3 = pingColor
	pt.Text = (p.ping or 0) .. " ms"
	pt.Font = Enum.Font.Code
	pt.TextSize = 14

	PlayerRows[p.userId] = { frame = r, dot = dot, pingLabel = pt }
	UpdatePlayersCanvas()
end

local function RemovePlayerRow(userId)
	local row = PlayerRows[userId]
	if row then
		row.frame:Destroy()
		PlayerRows[userId] = nil
		UpdatePlayersCanvas()
	end
end

local function UpdatePlayerPing(userId, ping)
	local row = PlayerRows[userId]
	if row then
		local color = GetPingColor(ping)
		row.dot.BackgroundColor3 = color
		row.pingLabel.TextColor3 = color
		row.pingLabel.Text = ping .. " ms"
	end
end

-- ─────────────────────────────────────────────
--  BANS PAGE
-- ─────────────────────────────────────────────
local B_Scroll = Instance.new("ScrollingFrame", PageBans)
B_Scroll.Size = UDim2.new(1, -32, 1, -32)
B_Scroll.Position = px(16, 16)
B_Scroll.BackgroundTransparency = 1
B_Scroll.ScrollBarThickness = 4
B_Scroll.ScrollBarImageColor3 = C.TextLo
B_Scroll.BorderSizePixel = 0
local B_List = Instance.new("UIListLayout", B_Scroll)
B_List.Padding = UDim.new(0, 8)

local BanRows = {} -- [userId] = frame

local function UpdateBansCanvas()
	local count = 0
	for _ in pairs(BanRows) do count += 1 end
	B_Scroll.CanvasSize = UDim2.new(0, 0, 0, count * 70)
end

local function CreateBanRow(rec)
	if BanRows[rec.userId] then BanRows[rec.userId]:Destroy() end

	local r = Instance.new("Frame", B_Scroll)
	r.Size = UDim2.new(1, 0, 0, 62)
	r.BackgroundColor3 = C.Card
	r.BackgroundTransparency = GLASS.Card
	AddCorner(r, 10)
	AddStroke(r, C.Border, 1)

	local name = Instance.new("TextLabel", r)
	name.Size = UDim2.new(1, -220, 0, 22)
	name.Position = px(14, 8)
	name.BackgroundTransparency = 1
	name.TextColor3 = C.TextHi
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamBold
	name.TextSize = 14
	name.Text = (rec.name or ("UserId " .. rec.userId)) .. (rec.deviceBlock and "  🔒" or "")

	local reason = Instance.new("TextLabel", r)
	reason.Size = UDim2.new(1, -220, 0, 18)
	reason.Position = px(14, 30)
	reason.BackgroundTransparency = 1
	reason.TextColor3 = C.TextMid
	reason.TextXAlignment = Enum.TextXAlignment.Left
	reason.Font = Enum.Font.Gotham
	reason.TextSize = 12
	reason.TextTruncate = Enum.TextTruncate.AtEnd
	reason.Text = (rec.reason or "No reason") .. "  •  by " .. (rec.bannedBy or "?")

	local expiry = Instance.new("TextLabel", r)
	expiry.Size = px(110, 18)
	expiry.Position = px(14, 46)
	expiry.BackgroundTransparency = 1
	expiry.TextColor3 = (rec.expiresAt == -1) and C.Red or C.Yellow
	expiry.TextXAlignment = Enum.TextXAlignment.Left
	expiry.Font = Enum.Font.Code
	expiry.TextSize = 11
	expiry.Text = FormatExpiry(rec.expiresAt)

	local unbanBtn = Instance.new("TextButton", r)
	unbanBtn.Size = px(90, 36)
	unbanBtn.Position = UDim2.new(1, -106, 0.5, -18)
	unbanBtn.BackgroundColor3 = C.Card
	unbanBtn.TextColor3 = C.Green
	unbanBtn.Text = "UNBAN"
	unbanBtn.Font = Enum.Font.GothamBold
	unbanBtn.TextSize = 12
	unbanBtn.AutoButtonColor = false
	AddCorner(unbanBtn, 8)
	AddStroke(unbanBtn, C.Green, 1)
	unbanBtn.MouseButton1Click:Connect(function()
		RE_Command:FireServer("Unban", { userId = rec.userId })
	end)

	BanRows[rec.userId] = r
	UpdateBansCanvas()
end

local function RemoveBanRow(userId)
	local row = BanRows[userId]
	if row then
		row:Destroy()
		BanRows[userId] = nil
		UpdateBansCanvas()
	end
end

-- ─────────────────────────────────────────────
--  LOG PAGE  (console-style, auto-scrolls to newest)
-- ─────────────────────────────────────────────
local L_Scroll = Instance.new("ScrollingFrame", PageLog)
L_Scroll.Size = UDim2.new(1, -32, 1, -32)
L_Scroll.Position = px(16, 16)
L_Scroll.BackgroundTransparency = 1
L_Scroll.ScrollBarThickness = 4
L_Scroll.ScrollBarImageColor3 = C.TextLo
L_Scroll.BorderSizePixel = 0
local L_List = Instance.new("UIListLayout", L_Scroll)
L_List.Padding = UDim.new(0, 6)

local LOG_ACTION_COLOR = {
	BAN = C.Red, KICK = C.Yellow, KILL = C.Red, SPEED = C.Accent,
	WARN = C.Yellow, UNBAN = C.Green, RESPAWN = C.Accent, ANNOUNCE = C.Accent,
}

local logRowCount = 0

local function CreateLogRow(entry)
	logRowCount += 1
	local r = Instance.new("Frame", L_Scroll)
	r.LayoutOrder = logRowCount
	r.Size = UDim2.new(1, 0, 0, 36)
	r.BackgroundColor3 = C.Card
	r.BackgroundTransparency = GLASS.Card
	AddCorner(r, 6)

	local tag = Instance.new("TextLabel", r)
	tag.Size = px(80, 36)
	tag.Position = px(12, 0)
	tag.BackgroundTransparency = 1
	tag.TextColor3 = LOG_ACTION_COLOR[entry.action] or C.TextMid
	tag.Font = Enum.Font.GothamBlack
	tag.TextSize = 12
	tag.TextXAlignment = Enum.TextXAlignment.Left
	tag.Text = entry.action

	local desc = Instance.new("TextLabel", r)
	desc.Size = UDim2.new(1, -260, 1, 0)
	desc.Position = px(96, 0)
	desc.BackgroundTransparency = 1
	desc.TextColor3 = C.TextHi
	desc.Font = Enum.Font.GothamMedium
	desc.TextSize = 13
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextTruncate = Enum.TextTruncate.AtEnd
	desc.Text = entry.admin .. " → " .. entry.target .. ((entry.extra and entry.extra ~= "") and ("  (" .. entry.extra .. ")") or "")

	local time = Instance.new("TextLabel", r)
	time.Size = px(90, 36)
	time.Position = UDim2.new(1, -100, 0, 0)
	time.BackgroundTransparency = 1
	time.TextColor3 = C.TextLo
	time.Font = Enum.Font.Code
	time.TextSize = 12
	time.TextXAlignment = Enum.TextXAlignment.Right
	time.Text = entry.time_str or ""

	L_Scroll.CanvasSize = UDim2.new(0, 0, 0, logRowCount * 42)
	task.defer(function()
		L_Scroll.CanvasPosition = Vector2.new(0, math.max(0, L_Scroll.CanvasSize.Y.Offset - L_Scroll.AbsoluteSize.Y))
	end)
end

-- ─────────────────────────────────────────────
--  ANNOUNCE PAGE
-- ─────────────────────────────────────────────
local AnnTitle = Instance.new("TextLabel", PageAnnounce)
AnnTitle.Size = px(300, 40)
AnnTitle.Position = px(24, 16)
AnnTitle.BackgroundTransparency = 1
AnnTitle.TextXAlignment = Enum.TextXAlignment.Left
AnnTitle.TextColor3 = C.TextHi
AnnTitle.Text = "SERVER BROADCAST"
AnnTitle.Font = Enum.Font.GothamBlack
AnnTitle.TextSize = 22

local AnnBox = Instance.new("TextBox", PageAnnounce)
AnnBox.Size = UDim2.new(1, -48, 0, 180)
AnnBox.Position = px(24, 66)
AnnBox.BackgroundColor3 = C.BgOuter
AnnBox.BackgroundTransparency = GLASS.Input
AnnBox.TextColor3 = C.TextHi
AnnBox.PlaceholderColor3 = C.TextLo
AnnBox.Text = ""
AnnBox.PlaceholderText = "Type your broadcast message here..."
AnnBox.MultiLine = true
AnnBox.TextXAlignment = Enum.TextXAlignment.Left
AnnBox.TextYAlignment = Enum.TextYAlignment.Top
AnnBox.Font = Enum.Font.GothamMedium
AnnBox.TextSize = 16
AddCorner(AnnBox, 10)
local AnnStroke = AddStroke(AnnBox, C.Border, 1)
local annPad = Instance.new("UIPadding", AnnBox)
annPad.PaddingTop = UDim.new(0, 16); annPad.PaddingLeft = UDim.new(0, 16); annPad.PaddingRight = UDim.new(0, 16)

AnnBox.Focused:Connect(function() TweenService:Create(AnnStroke, TWEEN_FAST, { Color = C.Accent }):Play() end)
AnnBox.FocusLost:Connect(function() TweenService:Create(AnnStroke, TWEEN_FAST, { Color = C.Border }):Play() end)

local AnnBtn = Instance.new("TextButton", PageAnnounce)
AnnBtn.Size = px(220, 48)
AnnBtn.Position = px(24, 266)
AnnBtn.BackgroundColor3 = C.Accent
AnnBtn.TextColor3 = C.BgOuter
AnnBtn.Text = "SEND BROADCAST"
AnnBtn.Font = Enum.Font.GothamBlack
AnnBtn.TextSize = 15
AnnBtn.AutoButtonColor = false
AddCorner(AnnBtn, 10)

AnnBtn.MouseEnter:Connect(function() TweenService:Create(AnnBtn, TWEEN_FAST, { BackgroundColor3 = C.AccentDim, TextColor3 = C.TextHi }):Play() end)
AnnBtn.MouseLeave:Connect(function() TweenService:Create(AnnBtn, TWEEN_FAST, { BackgroundColor3 = C.Accent, TextColor3 = C.BgOuter }):Play() end)

AnnBtn.MouseButton1Click:Connect(function()
	if AnnBox.Text ~= "" then
		RE_Command:FireServer("Announce", { message = AnnBox.Text })
		AnnBox.Text = ""
	else
		ShowToast("Type a message first.", "error")
	end
end)

-- ─────────────────────────────────────────────
--  ADMIN-ONLY EVENT ROUTING
--  (assigning the forward-declared local connects everything set up above to
--  the single RE_Update listener registered near the top of the script)
-- ─────────────────────────────────────────────
AdminEventRouter = function(eventType, data)
	if eventType == "PlayerJoined" then
		table.insert(State.players, { name = data.name, userId = data.userId, ping = 0, isAdmin = data.isAdmin })
		CreatePlayerRow({ name = data.name, userId = data.userId, ping = 0, isAdmin = data.isAdmin })

	elseif eventType == "PlayerLeft" then
		for i, p in ipairs(State.players) do
			if p.userId == data.userId then table.remove(State.players, i) break end
		end
		RemovePlayerRow(data.userId)

	elseif eventType == "PingUpdate" then
		for _, entry in ipairs(data) do
			UpdatePlayerPing(entry.userId, entry.ping)
		end

	elseif eventType == "Notify" then
		ShowToast(data.message, data.kind)

	elseif eventType == "Log" then
		CreateLogRow(data)

	elseif eventType == "BanAdded" then
		CreateBanRow(data)

	elseif eventType == "BanRemoved" then
		RemoveBanRow(data.userId)
	end
end

-- ─────────────────────────────────────────────
--  INITIAL POPULATION
-- ─────────────────────────────────────────────
for _, p in ipairs(State.players) do
	CreatePlayerRow(p)
end
for _, rec in ipairs(initialData.bans or {}) do
	CreateBanRow(rec)
end
for _, entry in ipairs(initialData.log or {}) do
	CreateLogRow(entry)
end

-- ─────────────────────────────────────────────
--  OPEN / CLOSE  (F4, or Escape to close)
-- ─────────────────────────────────────────────
local function TogglePanel()
	State.open = not State.open
	if State.open then
		Panel.Visible = true

		TweenService:Create(HintFrame, TWEEN_FAST, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(HintText, TWEEN_FAST, { TextTransparency = 1 }):Play()
		TweenService:Create(HintFrame.UIStroke, TWEEN_FAST, { Transparency = 1 }):Play()

		TweenService:Create(Blur, TWEEN_SMOOTH, { Size = GLASS.BlurSize }):Play()

		Panel.Size = px(PANEL_W * 0.95, PANEL_H * 0.95)
		TweenService:Create(Panel, TWEEN_SMOOTH, {
			GroupTransparency = 0, -- fully opaque group multiplier; GLASS.* values above are the only thing left controlling tr
			Size = px(PANEL_W, PANEL_H),
		}):Play()

		SetPage(State.page or "Players")
	else
		TweenService:Create(Panel, TWEEN_FAST, {
			GroupTransparency = 1,
			Size = px(PANEL_W * 0.95, PANEL_H * 0.95),
		}):Play()
		TweenService:Create(Blur, TWEEN_FAST, { Size = 0 }):Play()

		TweenService:Create(HintFrame, TWEEN_SMOOTH, { BackgroundTransparency = GLASS.Hint }):Play()
		TweenService:Create(HintText, TWEEN_SMOOTH, { TextTransparency = 0 }):Play()
		TweenService:Create(HintFrame.UIStroke, TWEEN_SMOOTH, { Transparency = 0 }):Play()

		task.delay(0.2, function() Panel.Visible = false end)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F4 then
		TogglePanel()
	elseif input.KeyCode == Enum.KeyCode.Escape and State.open then
		TogglePanel()
	end
end)

SetPage("Players")