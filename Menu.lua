--!strict
-- Menu.lua
-- PopupMenu client UI + 5 left tabs + toggle switch cards (REMOTE MODULE)
-- Load in Roblox with:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/Menu.lua"))()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local SKY_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/ClientSky.lua"
local TOGGLES_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/ToggleSwitches.lua"
local FULLBRIGHT_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/Fullbright.lua"
local NOFOG_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/NoFog.lua"
local ADMINESP_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/AdminESP.lua"
local FLIGHT_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/Flight.lua"
local TWEEN_NPC_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/TweenToNPC.lua"
local FASTMODE_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/FastMode.lua"
local SPEED_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/PlayerSpeed.lua"
local RAGE_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/Rage.lua"



local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// Config
local CONFIG = {
	GuiName = "PopupMenuGui",
	ToggleButtonName = "MenuToggleButton",
	PopupName = "PopupPanel",

	AnchorCorner = "BottomLeft",
	Margin = 16,

	ToggleSize = 42,
	PopupSize = Vector2.new(520, 330),

	OpenTweenTime = 0.18,
	CloseTweenTime = 0.14,

	Accent = Color3.fromRGB(255, 0, 0),
	Bg = Color3.fromRGB(14, 14, 16),
	Bg2 = Color3.fromRGB(20, 20, 24),
	Bg3 = Color3.fromRGB(26, 26, 32),
	Text = Color3.fromRGB(240, 240, 244),
	SubText = Color3.fromRGB(170, 170, 180),
	Stroke = Color3.fromRGB(55, 55, 65),
}

local SIDEBAR_WIDTH = 140

--// Global shared toggle access (so other remote scripts can read/subscribe)
local function getGlobal(): any
	local gg = (typeof(getgenv) == "function") and getgenv() or nil
	if gg then
		return gg
	end
	return _G
end

local G = getGlobal()

--// Utilities
local function make(instanceType: string, props: {[string]: any}?): Instance
	local inst = Instance.new(instanceType)
	if props then
		for k, v in pairs(props) do
			(inst :: any)[k] = v
		end
	end
	return inst
end

local function addCorner(parent: Instance, radius: number)
	make("UICorner", {
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	})
end

local function addStroke(parent: Instance, thickness: number, color: Color3, transparency: number?)
	make("UIStroke", {
		Thickness = thickness,
		Color = color,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function isTouchDevice(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function getViewportSize(): Vector2
	local cam = workspace.CurrentCamera
	if cam then
		return cam.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

local function clampPopupPos(pos: Vector2, popupSize: Vector2, anchor: Vector2, viewport: Vector2): Vector2
	local w, h = popupSize.X, popupSize.Y

	local topLeftX = pos.X - (anchor.X * w)
	local topLeftY = pos.Y - (anchor.Y * h)

	topLeftX = math.clamp(topLeftX, 0, viewport.X - w)
	topLeftY = math.clamp(topLeftY, 0, viewport.Y - h)

	return Vector2.new(
		topLeftX + (anchor.X * w),
		topLeftY + (anchor.Y * h)
	)
end

local function runRemote(url: string)
	local ok, code = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok then
		warn("HttpGet failed:", code)
		return
	end

	local fn, compileErr = loadstring(code)
	if not fn then
		warn("loadstring failed:", compileErr)
		return
	end

	local ok2, runErr = pcall(fn)
	if not ok2 then
		warn("remote runtime error:", runErr)
	end
end

local function loadRemoteModule(url: string): any
	local ok, code = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok then
		warn("Remote module HttpGet failed:", code)
		return nil
	end

	local chunk, compileErr = loadstring(code)
	if not chunk then
		warn("Remote module compile failed:", compileErr)
		warn("Remote module first 200 chars:\n" .. string.sub(code, 1, 200))
		return nil
	end

	local ok2, result = pcall(chunk)
	if not ok2 then
		warn("Remote module runtime failed:", result)
		return nil
	end

	if type(result) ~= "table" then
		warn("Remote module did not return a table. Got:", typeof(result))
		return nil
	end

	return result
end

local Toggles = loadRemoteModule(TOGGLES_URL)
if not Toggles then
	error("Failed to load ToggleSwitches module from GitHub")
end

-- expose module API globally so feature scripts can Subscribe without re-fetching
G.__HIGGI_TOGGLES_API = Toggles

local TOGGLE_SERVICES = {
	TweenService = TweenService,
	UserInputService = UserInputService,
}


--================================================================================
-- Toggle-driven lazy feature loading (MOVED HERE)
--================================================================================
local featureLoaded: {[string]: boolean} = {}

local function ensureFeatureLoaded(key: string, url: string)
	if featureLoaded[key] then
		return
	end
	featureLoaded[key] = true
	runRemote(url)
end


--================================================================================
-- NPC Registry (reliable list + last-known positions)
--================================================================================

G.__HIGGI_NPC_REGISTRY = G.__HIGGI_NPC_REGISTRY or {
	byName = {},      -- [name] = {model: Model?, lastCFrame: CFrame?}
	namesSeen = {},   -- [name] = true (never removed from dropdown)
}

local Registry = G.__HIGGI_NPC_REGISTRY

local function registryUpsertModel(m: Model)
	local name = m.Name

	-- permanently track name
	Registry.namesSeen[name] = true

	local entry = Registry.byName[name]
	if not entry then
		entry = {
			model = nil,
			lastCFrame = nil,
		}
		Registry.byName[name] = entry
	end

	entry.model = m

	local pp =
		m.PrimaryPart
		or m:FindFirstChild("HumanoidRootPart")
		or m:FindFirstChildWhichIsA("BasePart")

	if pp and pp:IsA("BasePart") then
		entry.lastCFrame = pp.CFrame
	end
end

local function registryMarkRemoved(name: string)
	local entry = Registry.byName[name]
	if entry then
		entry.model = nil
	end
	-- DO NOT remove from namesSeen
	-- DO NOT delete entry
end

local function startNpcWatcher()

	task.spawn(function()

		local folder = ReplicatedSto:WaitForChild("NPCs")

		local function register(inst: Instance)
			if inst:IsA("Model") then
				registryUpsertModel(inst)
			end
		end

		-- seed existing
		for _, inst in ipairs(folder:GetDescendants()) do
			register(inst)
		end

		-- future NPCs
		folder.DescendantAdded:Connect(register)

	end)
end



startNpcWatcher()

local function getNpcNames(): {string}
	local names: {string} = {}

	-- IMPORTANT: use namesSeen so names never disappear
	for name, _ in pairs(Registry.namesSeen) do
		table.insert(names, name)
	end

	table.sort(names, function(a, b)
		return a:lower() < b:lower()
	end)

	return names
end


--================================================================================
-- Pin toggle under Roblox top-left UI (Roblox button row)
--================================================================================
local TOPLEFT_X = 16
local GAP_UNDER_ROW = 8

local lastInset: Vector2? = nil
local lastViewport: Vector2? = nil
local pinnedConn: RBXScriptConnection? = nil

local function placeToggleUnderRobloxUI(btn: GuiObject)
	local insetTL, _ = GuiService:GetGuiInset()

	btn.AnchorPoint = Vector2.new(0, 0)

	-- keep size synced to config (so changing CONFIG.ToggleSize works everywhere)
	btn.Size = UDim2.fromOffset(CONFIG.ToggleSize, CONFIG.ToggleSize)

	-- place directly under the Roblox topbar area (no guessed row height)
	btn.Position = UDim2.new(
		0,
		TOPLEFT_X,
		0,
		insetTL.Y + GAP_UNDER_ROW
	)
end

local function startPinnedToggle(btn: GuiObject)
	placeToggleUnderRobloxUI(btn)

	if pinnedConn then
		pinnedConn:Disconnect()
		pinnedConn = nil
	end

	pinnedConn = RunService.RenderStepped:Connect(function()
		local insetTL, _ = GuiService:GetGuiInset()
		local vp = getViewportSize()

		if (not lastInset) or (not lastViewport) or insetTL ~= lastInset or vp ~= lastViewport then
			lastInset = insetTL
			lastViewport = vp
			placeToggleUnderRobloxUI(btn)
		end
	end)
end

--================================================================================
-- Drag helper (RenderStepped, sync-safe)
--================================================================================
type DragSync = {
	Target: GuiObject,
	StartPos: UDim2,
}

local function enableDrag(dragHandle: GuiObject, mainTarget: GuiObject, onDragStart: (() -> ())?, getSyncTargets: (() -> {DragSync})?)
	dragHandle.Active = true

	local dragging = false
	local dragStart: Vector2? = nil
	local mainStartPos: UDim2? = nil
	local sync: {DragSync} = {}
	local dragConn: RBXScriptConnection? = nil

	local function stopDrag()
		dragging = false
		dragStart = nil
		mainStartPos = nil
		sync = {}
		if dragConn then
			dragConn:Disconnect()
			dragConn = nil
		end
	end

	dragHandle.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if onDragStart then
			onDragStart()
		end

		dragging = true
		mainStartPos = mainTarget.Position

		if getSyncTargets then
			sync = getSyncTargets()
		else
			sync = {}
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = UserInputService:GetMouseLocation()
		else
			dragStart = input.Position
		end

		dragConn = RunService.RenderStepped:Connect(function()
			if not dragging or not dragStart or not mainStartPos then
				return
			end

			local currentPos = (input.UserInputType == Enum.UserInputType.MouseButton1) and UserInputService:GetMouseLocation() or input.Position
			local delta = currentPos - dragStart

			mainTarget.Position = UDim2.new(
				mainStartPos.X.Scale,
				mainStartPos.X.Offset + delta.X,
				mainStartPos.Y.Scale,
				mainStartPos.Y.Offset + delta.Y
			)

			for _, s in ipairs(sync) do
				s.Target.Position = UDim2.new(
					s.StartPos.X.Scale,
					s.StartPos.X.Offset + delta.X,
					s.StartPos.Y.Scale,
					s.StartPos.Y.Offset + delta.Y
				)
			end
		end)

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				stopDrag()
			end
		end)
	end)

	dragHandle.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stopDrag()
		end
	end)
end

--================================================================================
-- Build GUI
--================================================================================
local existing = playerGui:FindFirstChild(CONFIG.GuiName)
if existing then
	existing:Destroy()
end

local screenGui = make("ScreenGui", {
	Name = CONFIG.GuiName,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	Parent = playerGui,
})

local overlay = make("Frame", {
	Name = "OverlayLayer",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.fromScale(0, 0),
	ZIndex = 999,
	ClipsDescendants = false,
	Parent = screenGui,
})


make("UIScale", {
	Scale = isTouchDevice() and 1.05 or 1,
	Parent = screenGui,
})

TOGGLE_SERVICES = {
	TweenService = TweenService,
	UserInputService = UserInputService,
	Overlay = overlay,
}


-- Toggle button (background circle)
local toggleButton = make("ImageButton", {
	Name = CONFIG.ToggleButtonName,
	AutoButtonColor = false,
	BackgroundColor3 = CONFIG.Bg2,
	Size = UDim2.fromOffset(CONFIG.ToggleSize, CONFIG.ToggleSize),
	ZIndex = 50,
	Parent = screenGui,
})
addCorner(toggleButton, math.floor(CONFIG.ToggleSize / 2))
addStroke(toggleButton, 1, CONFIG.Stroke, 0.15)

toggleButton.Image = "" -- make sure button itself has no image

local CLOSED_ICON = "rbxassetid://70596288325600"
local OPEN_ICON = "rbxassetid://70596288325600"

local toggleIcon = make("ImageLabel", {
	Name = "Icon",
	BackgroundTransparency = 1,
	Image = CLOSED_ICON,
	ImageTransparency = 0,
	ScaleType = Enum.ScaleType.Fit,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(1, 1, 1, 1),
	ZIndex = 51,
	Parent = toggleButton,
})

-- pin it under Roblox top-left UI
startPinnedToggle(toggleButton)

-- Popup panel
local popup = make("Frame", {
	Name = CONFIG.PopupName,
	BackgroundColor3 = CONFIG.Bg,
	Size = UDim2.fromOffset(CONFIG.PopupSize.X, CONFIG.PopupSize.Y),
	Visible = true,
	ZIndex = 40,
	Parent = screenGui,
})
popup.ClipsDescendants = true
popup.AnchorPoint = Vector2.new(0, 0)
addCorner(popup, 14)
addStroke(popup, 1, CONFIG.Stroke, 0.15)

local popupGradient = make("UIGradient", {
	Rotation = 90,
	Parent = popup,
})
popupGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, CONFIG.Bg2),
	ColorSequenceKeypoint.new(1, CONFIG.Bg),
})

-- Header (ONLY drag handle for menu)
local header = make("Frame", {
	Name = "Header",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 44),
	ZIndex = 41,
	Parent = popup,
})

make("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Text = "Higgi's EBT Menu",
	TextColor3 = CONFIG.Text,
	TextSize = 18,
	Font = Enum.Font.GothamSemibold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, -88, 1, 0),
	Position = UDim2.new(0, 20, 0, 0),
	ZIndex = 42,
	Parent = header,
})

local closeBtn = make("TextButton", {
	Name = "Close",
	AutoButtonColor = false,
	BackgroundColor3 = CONFIG.Bg2,
	Text = "X",
	TextColor3 = CONFIG.Text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	Size = UDim2.fromOffset(34, 28),
	Position = UDim2.new(1, -14 - 34, 0, 8),
	ZIndex = 42,
	Parent = header,
})
addCorner(closeBtn, 10)
addStroke(closeBtn, 1, CONFIG.Stroke, 0.25)

-- Divider under header
make("Frame", {
	Name = "Divider",
	BackgroundColor3 = CONFIG.Stroke,
	BackgroundTransparency = 0.65,
	Size = UDim2.new(1, -20, 0, 1),
	Position = UDim2.new(0, 10, 0, 44),
	ZIndex = 41,
	Parent = popup,
})

-- Body area (sidebar + pages)
local body = make("Frame", {
	Name = "Body",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -20, 1, -56),
	Position = UDim2.new(0, 10, 0, 52),
	ZIndex = 41,
	Parent = popup,
})
-- Clicking anywhere inside the menu closes dropdowns
body.Active = true
body.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		Toggles.CloseAllDropdowns()
	end
end)


-- Sidebar
local sidebar = make("Frame", {
	Name = "Sidebar",
	BackgroundColor3 = CONFIG.Bg2,
	Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -16),
	Position = UDim2.new(0, 0, 0, 8),
	ZIndex = 42,
	Parent = body,
})
addCorner(sidebar, 12)
addStroke(sidebar, 1, CONFIG.Stroke, 0.25)

-- Sidebar clicks close any open dropdown
sidebar.Active = true
sidebar.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		Toggles.CloseAllDropdowns()
	end
end)


make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CONFIG.Bg3),
		ColorSequenceKeypoint.new(1, CONFIG.Bg2),
	}),
	Parent = sidebar,
})

make("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = sidebar,
})

make("UIPadding", {
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10),
	Parent = sidebar,
})

-- Pages container
local pages = make("Frame", {
	Name = "Pages",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -(SIDEBAR_WIDTH + 10), 1, -20),
	Position = UDim2.new(0, SIDEBAR_WIDTH + 10, 0, 10),
	ZIndex = 42,
	Parent = body,
})

local function makePage(name: string): ScrollingFrame
	local page = make("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		ScrollBarThickness = 4,
		ScrollBarImageTransparency = 0.25,

		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,

		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		ZIndex = 42,
		Visible = false,
		Parent = pages,
	}) :: ScrollingFrame

	local layout = make("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	}) :: UIListLayout

	make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 6),
		Parent = page,
	})

	local function refreshCanvas()
		local contentY = layout.AbsoluteContentSize.Y
		page.CanvasSize = UDim2.new(0, 0, 0, contentY + 12)
	end

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshCanvas)
	task.defer(refreshCanvas)

	return page
end

-- Optional: simple action card
local function addCard(parent: Instance, textTop: string, textBottom: string, order: number, onClick: (() -> ())?)
	local card = make("TextButton", {
		Name = "Card",
		AutoButtonColor = false,
		BackgroundColor3 = CONFIG.Bg2,
		Size = UDim2.new(1, 0, 0, 64),
		ZIndex = 43,
		LayoutOrder = order,
		Text = "",
		Parent = parent,
	}) :: TextButton
	addCorner(card, 12)
	addStroke(card, 1, CONFIG.Stroke, 0.35)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Text = textTop,
		TextColor3 = CONFIG.Text,
		TextSize = 15,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 10, 0, 8),
		ZIndex = 44,
		Parent = card,
	})

	make("TextLabel", {
		BackgroundTransparency = 1,
		Text = textBottom,
		TextColor3 = CONFIG.SubText,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.new(0, 10, 0, 30),
		ZIndex = 44,
		Parent = card,
	})

	if onClick then
		card.MouseButton1Click:Connect(onClick)

		card.MouseEnter:Connect(function()
			card.BackgroundColor3 = CONFIG.Bg3
		end)
		card.MouseLeave:Connect(function()
			card.BackgroundColor3 = CONFIG.Bg2
		end)
	end
end

local function addPlaceholders(page: ScrollingFrame, tabName: string, startOrder: number)
	for i = 1, 5 do
		addCard(page,
			tabName .. " Placeholder " .. tostring(i),
			"Add an action/toggle here later.",
			startOrder + i - 1,
			function()
				print(tabName .. " placeholder " .. tostring(i))
			end
		)
	end
end

-- Create pages
local pageMain = makePage("Main")
local pageVisuals = makePage("Visuals")
local pageWorld = makePage("World")
local pageMisc = makePage("Misc")
local pageSettings = makePage("Settings")

-- Main tab (keep placeholders for now)

Toggles.AddToggleCard(
	pageMain,
	"combat_rage",
	"Rage Aimbot",
	"Auto-aim at nearest enemy inside FOV.",
	1,
	false,
	CONFIG,
	TOGGLE_SERVICES,
	function(state: boolean)
		if state then
			ensureFeatureLoaded("combat_rage", RAGE_URL)
		end
	end
)


Toggles.AddSliderCard(
	pageMain,
	"combat_rage_fov",
	"FOV",
	nil,
	2,
	20,
	400,
	120,
	5,
	CONFIG,
	TOGGLE_SERVICES,
	20
)

Toggles.AddSliderCard(
	pageMain,
	"combat_rage_smooth",
	"SMOOTH",
	nil,
	3,
	0,
	1,
	0.18,
	0.01,
	CONFIG,
	TOGGLE_SERVICES,
	5
)

Toggles.AddToggleCard(
	pageMain,
	"combat_rage_teamcheck",
	"Team Check",
	"Ignore teammates when targeting.",
	4,
	true,
	CONFIG,
	TOGGLE_SERVICES,
	nil
)

-- Visuals tab (EXAMPLE TOGGLES)
Toggles.AddToggleCard(pageVisuals, "visuals_player", "Chams", "Highlight players.", 3, false, CONFIG, TOGGLE_SERVICES, function(state)
	if state then ensureFeatureLoaded("adminesp", ADMINESP_URL) end
end)

Toggles.AddToggleCard(pageVisuals, "visuals_name", "Name ESP", "Show player names.", 1, false, CONFIG, TOGGLE_SERVICES, function(state)
	if state then ensureFeatureLoaded("adminesp", ADMINESP_URL) end
end)

Toggles.AddToggleCard(pageVisuals, "visuals_health", "Health ESP", "Show player health bars.", 2, false, CONFIG, TOGGLE_SERVICES, function(state)
	if state then ensureFeatureLoaded("adminesp", ADMINESP_URL) end
end)

Toggles.AddToggleCard(pageVisuals, "visuals_snaplines", "Snaplines", "Lines to players.", 4, false, CONFIG, TOGGLE_SERVICES, function(state)
	if state then ensureFeatureLoaded("adminesp", ADMINESP_URL) end
end)

Toggles.AddToggleCard(pageVisuals, "visuals_box3d", "Boxes", "3D wireframe player boxes.", 5, false, CONFIG, TOGGLE_SERVICES, function(state)
	if state then ensureFeatureLoaded("adminesp", ADMINESP_URL) end
end)

Toggles.AddToggleCard(
	pageVisuals,
	"visuals_team",
	"Team ESP",
	"Apply active ESP features to teammates (blue).",
	6,
	false,
	CONFIG,
	TOGGLE_SERVICES,
	function(state)
		if state then
			ensureFeatureLoaded("adminesp", ADMINESP_URL)
		end
	end
)

-- World tab: action + toggles + placeholders
-- World tab: Skybox toggle + dropdown (REPLACES the old "Apply Skybox" card)

local function getSkyboxNames(): {string}
	return {
		"Aurora",
		"Battlerock",
		"Chromatic Horizon",
		"Corrupted",
		"Crimson Despair",
		"Cyan Planet",
		"Cyan Space",
		"Cyberpunk",
		"Dark Matter",
		"Dreamy",
		"Emerald Borealis",
		"Emerald Oblivion",
		"Error",
		"Eyes",
		"Ghost",
		"Grid",
		"Minecraft",
		"Molten",
		"Neon Borealis",
		"Nuke",
		"Purple Space",
		"Red Moon",
		"Red Planet",
		"Space Rocks",
		"Stellar",
		"Storm",
		"Sunset",
		"Toon Moon",
		"Violet Moon",
		"War",
	}
end



Toggles.AddToggleDropDownCard(
	pageWorld,
	"world_skybox",					-- toggle key
	"world_skybox_dropdown",		-- value key
	"Skybox Changer",				-- title
	"Toggle + pick a skybox preset",
	1,								-- layout order
	false,							-- default toggle state
	"Eyes",					-- default dropdown value
	getSkyboxNames,					-- options provider
	CONFIG,
	TOGGLE_SERVICES,
	function(state)
		if state then
			-- load the script once; it subscribes to toggle + dropdown changes
			ensureFeatureLoaded("world_skybox", SKY_URL)
		end
	end,
	function(selectedName)
		-- optional: mirror what you did for NPC selection
		-- ClientSky.lua will also read from Toggles.GetValue, so this is just convenience.
		G.__HIGGI_SELECTED_SKYBOX = selectedName
	end
)


Toggles.AddToggleCard(pageWorld, "world_fullbright", "Fullbright", "Force maximum brightness locally.", 2, false, CONFIG, TOGGLE_SERVICES, function(state: boolean)
	if state then
		ensureFeatureLoaded("world_fullbright", FULLBRIGHT_URL)
	end
end)

Toggles.AddToggleCard(pageWorld, "world_nofog", "No Fog", "Reduce fog for clearer view.", 3, false, CONFIG, TOGGLE_SERVICES, function(state: boolean)
	if state then
		ensureFeatureLoaded("world_nofog", NOFOG_URL)
	end
end)

Toggles.AddToggleCard(pageWorld, "world_fastmode", "Fast Mode", "Disable world textures & shadows for FPS boost.", 5, false, CONFIG, TOGGLE_SERVICES, function(state: boolean)
	if state then
		ensureFeatureLoaded("world_fastmode", FASTMODE_URL)
	end
end)


-- Settings tab (EXAMPLE TOGGLES)
Toggles.AddToggleCard(pageSettings, "settings_keybinds", "Keybind Hints", "Show keybind tips in UI.", 1, true, CONFIG, TOGGLE_SERVICES, function(state: boolean)
	print("Keybind Hints:", state)
end)

Toggles.AddToggleCard(pageSettings, "settings_sfx", "UI Sounds", "Toggle UI click sounds.", 2, false, CONFIG, TOGGLE_SERVICES, function(state: boolean)
	print("UI Sounds:", state)
end)

Toggles.AddToggleCard(pageMisc, "world_flight", "Flight / Noclip", "Free flight with noclip enabled.", 1, false, CONFIG, TOGGLE_SERVICES, function(state: boolean)
	if state then
		ensureFeatureLoaded("world_flight", FLIGHT_URL)
	end
end)

Toggles.AddToggleCard(
	pageMisc,
	"misc_speed",
	"Speed Boost",
	"Increase local WalkSpeed.",
	2,
	false,
	CONFIG,
	TOGGLE_SERVICES,
	function(state: boolean)
		if state then
			ensureFeatureLoaded("misc_speed", SPEED_URL)
		end
	end
)

Toggles.AddToggleDropDownCard(
	pageMisc,
	"world_tween_to_npc",
	"npc_dropdown",
	"NPC Teleport",
	"Moves Player to Selected NPC",
	3, -- adjust order if needed
	false,
	"Select NPC",
	getNpcNames,
	CONFIG,
	TOGGLE_SERVICES,
	function(state)
		if state then
			ensureFeatureLoaded("world_tween_to_npc", TWEEN_NPC_URL)
		end
	end,
	function(selectedName)
		G.__HIGGI_SELECTED_NPC = selectedName
	end
)

--================================================================================
-- Tab system
--================================================================================
type TabDef = {
	Name: string,
	Page: ScrollingFrame,
	Icon: string?,
}

local tabs: {TabDef} = {
	{Name = "Main", Page = pageMain, Icon = "■"},
	{Name = "Visuals", Page = pageVisuals, Icon = "◈"},
	{Name = "World", Page = pageWorld, Icon = "◉"},
	{Name = "Misc", Page = pageMisc, Icon = "✦"},
	{Name = "Settings", Page = pageSettings, Icon = "⚙"},
}

local currentTabName = ""

local function setActivePage(name: string)
	if currentTabName == name then
		return
	end
	currentTabName = name

	for _, t in ipairs(tabs) do
		t.Page.Visible = (t.Name == name)
	end
end

local tabButtons: {[string]: TextButton} = {}

local function setTabVisuals(activeName: string)
	for _, t in ipairs(tabs) do
		local btn = tabButtons[t.Name]
		if btn then
			local isActive = (t.Name == activeName)
			btn.BackgroundColor3 = isActive and CONFIG.Bg or CONFIG.Bg2
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			if stroke then
				(stroke :: UIStroke).Color = isActive and CONFIG.Accent or CONFIG.Stroke ;
				(stroke :: UIStroke).Transparency = isActive and 0.05 or 0.25
			end
			local accent = btn:FindFirstChild("AccentBar")
			if accent and accent:IsA("Frame") then
				accent.BackgroundTransparency = isActive and 0 or 1
			end
		end
	end
end

local function makeTabButton(tab: TabDef, order: number)
	local btn = make("TextButton", {
		Name = tab.Name,
		AutoButtonColor = false,
		BackgroundColor3 = CONFIG.Bg2,
		Size = UDim2.new(1, 0, 0, 40),
		Text = "",
		ZIndex = 43,
		LayoutOrder = order,
		Parent = sidebar,
	}) :: TextButton
	addCorner(btn, 10)
	addStroke(btn, 1, CONFIG.Stroke, 0.25)

	local accentBar = make("Frame", {
		Name = "AccentBar",
		BackgroundColor3 = CONFIG.Accent,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 3, 1, -14),
		Position = UDim2.new(0, 8, 0, 7),
		ZIndex = 44,
		Parent = btn,
	})
	addCorner(accentBar, 2)

	make("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Text = tab.Icon or "",
		TextColor3 = CONFIG.SubText,
		TextSize = 14,
		Font = Enum.Font.GothamSemibold,
		Size = UDim2.new(0, 18, 1, 0),
		Position = UDim2.new(0, 18, 0, 0),
		ZIndex = 44,
		Parent = btn,
	})

	make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Text = tab.Name,
		TextColor3 = CONFIG.Text,
		TextSize = 14,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -48, 1, 0),
		Position = UDim2.new(0, 42, 0, 0),
		ZIndex = 44,
		Parent = btn,
	})

	btn.MouseEnter:Connect(function()
		if currentTabName ~= tab.Name then
			btn.BackgroundColor3 = CONFIG.Bg3
		end
	end)

btn.MouseLeave:Connect(function()
	if currentTabName ~= tab.Name then
		btn.BackgroundColor3 = CONFIG.Bg2
	end
end)

btn.MouseButton1Click:Connect(function()
	-- switching pages closes dropdowns
	Toggles.CloseAllDropdowns()

	setActivePage(tab.Name)
	setTabVisuals(tab.Name)
end)

tabButtons[tab.Name] = btn

end

for i, t in ipairs(tabs) do
	makeTabButton(t, i)
end

--================================================================================
-- Positions / animation states (FIXED: no downward drift, remembers last pos)
--================================================================================
local isOpen = false
popup.Visible = false
popup.Size = UDim2.fromOffset(CONFIG.PopupSize.X, 0)
body.Visible = false

local openTween: Tween? = nil
local closeTween: Tween? = nil

local freeMenuPositioning = false
local lastPopupPos: UDim2? = nil
local lastPopupAnchor: Vector2? = nil

local function placePopupCentered()
	local viewport = getViewportSize()
	local pos = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)
	local anchor = Vector2.new(0.5, 0.5)
	local clamped = clampPopupPos(pos, CONFIG.PopupSize, anchor, viewport)

	popup.AnchorPoint = anchor
	popup.Position = UDim2.fromOffset(clamped.X, clamped.Y)
end

local function placePopupClampedToViewport()
	local viewport = getViewportSize()
	local anchor = popup.AnchorPoint

	-- IMPORTANT: use popup.Position offsets, NOT AbsolutePosition (prevents drift)
	local desired = Vector2.new(popup.Position.X.Offset, popup.Position.Y.Offset)
	local clamped = clampPopupPos(desired, CONFIG.PopupSize, anchor, viewport)

	popup.Position = UDim2.fromOffset(clamped.X, clamped.Y)
end

-- save position whenever user drags it
popup:GetPropertyChangedSignal("Position"):Connect(function()
	if freeMenuPositioning then
		lastPopupPos = popup.Position
		lastPopupAnchor = popup.AnchorPoint
	end
end)

local function tweenPopup(open: boolean)
	if openTween then
		openTween:Cancel()
	end
	if closeTween then
		closeTween:Cancel()
	end

	if open then
		popup.Visible = true

		-- reopen where it last was (or center once)
		if lastPopupPos and lastPopupAnchor then
			popup.AnchorPoint = lastPopupAnchor
			popup.Position = lastPopupPos
			placePopupClampedToViewport()
		else
			placePopupCentered()
			lastPopupPos = popup.Position
			lastPopupAnchor = popup.AnchorPoint
		end

		popup.Size = UDim2.fromOffset(CONFIG.PopupSize.X, 0)
		body.Visible = false

		local tInfo = TweenInfo.new(CONFIG.OpenTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		openTween = TweenService:Create(popup, tInfo, {
			Size = UDim2.fromOffset(CONFIG.PopupSize.X, CONFIG.PopupSize.Y),
		})
		openTween.Completed:Once(function()
			if isOpen then
				body.Visible = true
			end
		end)
		openTween:Play()
	else
		body.Visible = false

		local tInfo = TweenInfo.new(CONFIG.CloseTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		closeTween = TweenService:Create(popup, tInfo, {
			Size = UDim2.fromOffset(CONFIG.PopupSize.X, 0),
		})
		closeTween.Completed:Once(function()
			popup.Visible = false
		end)
		closeTween:Play()
	end
end

local function setOpen(nextOpen: boolean)
	if isOpen == nextOpen then
		return
	end
	isOpen = nextOpen

	-- save where it was when closing
	if not isOpen then
		lastPopupPos = popup.Position
		lastPopupAnchor = popup.AnchorPoint
		Toggles.CloseAllDropdowns()
	end

	toggleIcon.Image = isOpen and OPEN_ICON or CLOSED_ICON
	tweenPopup(isOpen)
end

-- DRAGGING (SEPARATE)
-- toggleButton drag removed so it stays pinned under Roblox UI
enableDrag(header, popup, function()
	freeMenuPositioning = true
end, nil)

toggleButton.MouseButton1Click:Connect(function()
	setOpen(not isOpen)
end)

closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		setOpen(false)
	end
end)

-- Default tab
setActivePage("Main")
setTabVisuals("Main")
setOpen(false)

-- If you ever need to read a toggle anywhere in this file:
-- print("ESP Boxes currently:", Toggles.GetState("visuals_boxes", false))
-- If you ever need to force-load a feature:
-- ensureFeatureLoaded("world_fullbright", FULLBRIGHT_URL)
