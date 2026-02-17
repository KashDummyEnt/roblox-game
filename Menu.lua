--!strict
-- Menu.lua
-- PopupMenu client UI + 5 left tabs + toggle switch cards
-- Load in Roblox with:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/Menu.lua"))()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local SKY_URL = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/ClientSky.lua"

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// Config
local CONFIG = {
	GuiName = "PopupMenuGui",
	ToggleButtonName = "MenuToggleButton",
	PopupName = "PopupPanel",

	AnchorCorner = "BottomLeft", -- "BottomLeft" | "BottomRight" | "TopLeft" | "TopRight"
	Margin = 16,

	ToggleSize = 56,
	PopupSize = Vector2.new(520, 330),

	OpenTweenTime = 0.18,
	CloseTweenTime = 0.14,

	Accent = Color3.fromRGB(0, 45, 235),
	Bg = Color3.fromRGB(14, 14, 16),
	Bg2 = Color3.fromRGB(20, 20, 24),
	Bg3 = Color3.fromRGB(26, 26, 32),
	Text = Color3.fromRGB(240, 240, 244),
	SubText = Color3.fromRGB(170, 170, 180),
	Stroke = Color3.fromRGB(55, 55, 65),
}

local SIDEBAR_WIDTH = 140

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

local function getCornerPositions(toggleSize: number, popupSize: Vector2, margin: number)
	local ts = toggleSize
	local psX, psY = popupSize.X, popupSize.Y

	local function u2(xScale: number, xOffset: number, yScale: number, yOffset: number): UDim2
		return UDim2.new(xScale, xOffset, yScale, yOffset)
	end

	if CONFIG.AnchorCorner == "BottomLeft" then
		local togglePos = u2(0, margin, 1, -(margin + ts))
		local popupPos = u2(0, margin, 1, -(margin + ts + 12))
		return togglePos, popupPos
	end

	if CONFIG.AnchorCorner == "BottomRight" then
		local togglePos = u2(1, -(margin + ts), 1, -(margin + ts))
		local popupPos = u2(1, -(margin + psX), 1, -(margin + ts + 12))
		return togglePos, popupPos
	end

	if CONFIG.AnchorCorner == "TopLeft" then
		local togglePos = u2(0, margin, 0, margin)
		local popupPos = u2(0, margin, 0, margin + ts + 12)
		return togglePos, popupPos
	end

	local togglePos = u2(1, -(margin + ts), 0, margin)
	local popupPos = u2(1, -(margin + psX), 0, margin + ts + 12)
	return togglePos, popupPos
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

type FeatureController = {
	Enable: (() -> ())?,
	Disable: (() -> ())?,
	Destroy: (() -> ())?,
	IsEnabled: boolean?,
}

local FEATURES_BASE = "https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/"
local featureControllers: {[string]: FeatureController} = {}

local function loadFeature(featureName: string): FeatureController?
	if featureControllers[featureName] then
		return featureControllers[featureName]
	end

	local url = FEATURES_BASE .. featureName .. ".lua"
	local ok, code = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok then
		warn("Feature HttpGet failed:", featureName, code)
		return nil
	end

	local fn, compileErr = loadstring(code)
	if not fn then
		warn("Feature loadstring failed:", featureName, compileErr)
		return nil
	end

	local ok2, result = pcall(fn)
	if not ok2 then
		warn("Feature runtime error:", featureName, result)
		return nil
	end

	if type(result) ~= "table" then
		warn("Feature did not return a controller table:", featureName)
		return nil
	end

	local ctrl = result :: FeatureController
	ctrl.IsEnabled = ctrl.IsEnabled or false
	featureControllers[featureName] = ctrl
	return ctrl
end

local function setFeature(featureName: string, on: boolean)
	local ctrl = loadFeature(featureName)
	if not ctrl then
		return
	end

	if (ctrl.IsEnabled == true) == on then
		return
	end

	ctrl.IsEnabled = on

	if on then
		if ctrl.Enable then
			local ok, err = pcall(ctrl.Enable)
			if not ok then
				warn("Feature Enable failed:", featureName, err)
			end
		end
	else
		if ctrl.Disable then
			local ok, err = pcall(ctrl.Disable)
			if not ok then
				warn("Feature Disable failed:", featureName, err)
			end
		end
	end
end



-- Drag helper (RenderStepped, sync-safe)
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

--// Build GUI
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

make("UIScale", {
	Scale = isTouchDevice() and 1.05 or 1,
	Parent = screenGui,
})

-- Toggle button
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

local toggleIcon = make("TextLabel", {
	Name = "Icon",
	BackgroundTransparency = 1,
	Text = "≡",
	TextColor3 = CONFIG.Text,
	TextScaled = true,
	Font = Enum.Font.GothamBold,
	Size = UDim2.new(1, 0, 1, 0),
	ZIndex = 51,
	Parent = toggleButton,
})

local accentRing = make("Frame", {
	Name = "AccentRing",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 6, 1, 6),
	Position = UDim2.new(0, -3, 0, -3),
	ZIndex = 49,
	Parent = toggleButton,
})
addCorner(accentRing, math.floor(CONFIG.ToggleSize / 2) + 6)
addStroke(accentRing, 2, CONFIG.Accent, 0.35)

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
	Text = "Higgi's Menu",
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

--================================================================================
-- Toggle Switch System
--================================================================================

local toggleStates: {[string]: boolean} = {}

type ToggleHandle = {
	Get: () -> boolean,
	Set: (boolean) -> (),
	Flip: () -> (),
}

local function addToggleCard(
	parent: Instance,
	key: string,
	title: string,
	desc: string,
	order: number,
	defaultState: boolean,
	onChanged: ((boolean) -> ())?
): ToggleHandle
	if toggleStates[key] == nil then
		toggleStates[key] = defaultState
	end

	local card = make("Frame", {
		Name = "ToggleCard_" .. key,
		BackgroundColor3 = CONFIG.Bg2,
		Size = UDim2.new(1, 0, 0, 64),
		ZIndex = 43,
		LayoutOrder = order,
		Parent = parent,
	}) :: Frame
	addCorner(card, 12)
	addStroke(card, 1, CONFIG.Stroke, 0.35)

	local titleLbl = make("TextLabel", {
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = CONFIG.Text,
		TextSize = 15,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -118, 0, 22),
		Position = UDim2.new(0, 10, 0, 8),
		ZIndex = 44,
		Parent = card,
	}) :: TextLabel

	local descLbl = make("TextLabel", {
		BackgroundTransparency = 1,
		Text = desc,
		TextColor3 = CONFIG.SubText,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -118, 0, 28),
		Position = UDim2.new(0, 10, 0, 30),
		ZIndex = 44,
		Parent = card,
	}) :: TextLabel

	-- Switch (right side)
	local SWITCH_W = 64
	local SWITCH_H = 30
	local PADDING_R = 14

	local switchBtn = make("TextButton", {
		Name = "Switch",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(SWITCH_W, SWITCH_H),
		Position = UDim2.new(1, -(PADDING_R + SWITCH_W), 0.5, -(SWITCH_H / 2)),
		ZIndex = 46,
		Parent = card,
	}) :: TextButton

	-- Track
	local track = make("Frame", {
		Name = "Track",
		BackgroundColor3 = CONFIG.Bg3,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		ZIndex = 46,
		Parent = switchBtn,
	}) :: Frame
	addCorner(track, math.floor(SWITCH_H / 2))
	addStroke(track, 1, CONFIG.Stroke, 0.25)

	-- Knob
	local knob = make("Frame", {
		Name = "Knob",
		BackgroundColor3 = Color3.fromRGB(245, 245, 248),
		Size = UDim2.fromOffset(SWITCH_H - 6, SWITCH_H - 6),
		Position = UDim2.new(0, 3, 0, 3),
		ZIndex = 47,
		Parent = switchBtn,
	}) :: Frame
	addCorner(knob, 999)
	addStroke(knob, 1, Color3.fromRGB(0, 0, 0), 0.75)

	local function applyVisual(state: boolean, instant: boolean?)
		local knobXOn = SWITCH_W - (SWITCH_H - 6) - 3
		local knobXOff = 3

		local goalTrackColor = state and CONFIG.Accent or CONFIG.Bg3
		local goalStrokeColor = state and CONFIG.Accent or CONFIG.Stroke
		local goalStrokeTrans = state and 0.05 or 0.25
		local goalKnobPos = state and UDim2.new(0, knobXOn, 0, 3) or UDim2.new(0, knobXOff, 0, 3)

		local trackStroke = track:FindFirstChildOfClass("UIStroke")
		if not trackStroke then
			return
		end

		if instant then
			track.BackgroundColor3 = goalTrackColor ;
			(trackStroke :: UIStroke).Color = goalStrokeColor ;
			(trackStroke :: UIStroke).Transparency = goalStrokeTrans
			knob.Position = goalKnobPos
			return
		end

		local ti = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(track, ti, {BackgroundColor3 = goalTrackColor}):Play()
		TweenService:Create((trackStroke :: UIStroke), ti, {Color = goalStrokeColor, Transparency = goalStrokeTrans}):Play()
		TweenService:Create(knob, ti, {Position = goalKnobPos}):Play()
	end

	local function setState(nextState: boolean)
		if toggleStates[key] == nextState then
			return
		end
		toggleStates[key] = nextState
		applyVisual(nextState, false)
		if onChanged then
			onChanged(nextState)
		end
	end

	-- Initial render
	applyVisual(toggleStates[key], true)

	-- Hover polish (desktop only)
	if not isTouchDevice() then
		card.MouseEnter:Connect(function()
			card.BackgroundColor3 = CONFIG.Bg3
		end)
		card.MouseLeave:Connect(function()
			card.BackgroundColor3 = CONFIG.Bg2
		end)

		switchBtn.MouseEnter:Connect(function()
			track.BackgroundColor3 = (toggleStates[key] and CONFIG.Accent) or CONFIG.Bg2
		end)
		switchBtn.MouseLeave:Connect(function()
			applyVisual(toggleStates[key], true)
		end)
	end

	-- Click the switch
	switchBtn.MouseButton1Click:Connect(function()
		setState(not toggleStates[key])
	end)

	-- Optional: click the card anywhere EXCEPT labels will also toggle
	local clickCatcher = make("TextButton", {
		Name = "ClickCatcher",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		ZIndex = 45,
		Parent = card,
	}) :: TextButton
	clickCatcher.MouseButton1Click:Connect(function()
		setState(not toggleStates[key])
	end)

	-- Keep labels above clickcatcher so text selection/hover feels normal
	titleLbl.ZIndex = 46
	descLbl.ZIndex = 46
	switchBtn.ZIndex = 48
	track.ZIndex = 48
	knob.ZIndex = 49

	return {
		Get = function(): boolean
			return toggleStates[key]
		end,
		Set = function(v: boolean)
			setState(v)
		end,
		Flip = function()
			setState(not toggleStates[key])
		end,
	}
end

-- Optional: simple action card (kept from your original)
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
local pageSettings = makePage("Settings")
local pageAbout = makePage("About")

-- Main tab (keep placeholders for now)
addPlaceholders(pageMain, "Main", 1)

-- Visuals tab (EXAMPLE TOGGLES)
addToggleCard(pageVisuals, "visuals_boxes", "ESP Boxes", "Draw 2D boxes on players.", 1, true, function(state)
	print("ESP Boxes:", state)
end)
addToggleCard(pageVisuals, "visuals_names", "Name Tags", "Show player names above them.", 2, true, function(state)
	print("Name Tags:", state)
end)
addToggleCard(pageVisuals, "visuals_tracers", "Tracers", "Lines from you to targets.", 3, false, function(state)
	print("Tracers:", state)
end)
addPlaceholders(pageVisuals, "Visuals", 4)

-- World tab: action + toggles + placeholders
addCard(pageWorld, "Apply Skybox", "Runs ClientSky.lua from GitHub.", 1, function()
	runRemote(SKY_URL)
end)
addToggleCard(pageWorld, "world_fullbright", "Fullbright", "Brighten the world lighting.", 2, false, function(state)
	print("Fullbright:", state)
end)
addToggleCard(pageWorld, "world_nofog", "No Fog", "Reduce fog for clearer view.", 3, false, function(state)
	setFeature("NoFog", state)
end)

addPlaceholders(pageWorld, "World", 4)

-- Settings tab (EXAMPLE TOGGLES)
addToggleCard(pageSettings, "settings_keybinds", "Keybind Hints", "Show keybind tips in UI.", 1, true, function(state)
	print("Keybind Hints:", state)
end)
addToggleCard(pageSettings, "settings_sfx", "UI Sounds", "Toggle UI click sounds.", 2, false, function(state)
	print("UI Sounds:", state)
end)
addPlaceholders(pageSettings, "Settings", 3)

-- About tab (keep placeholders)
addPlaceholders(pageAbout, "About", 1)

-- Tab system
type TabDef = {
	Name: string,
	Page: ScrollingFrame,
	Icon: string?,
}

local tabs: {TabDef} = {
	{Name = "Main", Page = pageMain, Icon = "■"},
	{Name = "Visuals", Page = pageVisuals, Icon = "◈"},
	{Name = "World", Page = pageWorld, Icon = "◉"},
	{Name = "Settings", Page = pageSettings, Icon = "⚙"},
	{Name = "About", Page = pageAbout, Icon = "?"},
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
		setActivePage(tab.Name)
		setTabVisuals(tab.Name)
	end)

	tabButtons[tab.Name] = btn
end

for i, t in ipairs(tabs) do
	makeTabButton(t, i)
end

-- Positions / animation states
local togglePos = select(1, getCornerPositions(CONFIG.ToggleSize, CONFIG.PopupSize, CONFIG.Margin))
toggleButton.Position = togglePos

local isOpen = false
popup.Visible = false
popup.Size = UDim2.fromOffset(CONFIG.PopupSize.X, 0)
body.Visible = false

local openTween: Tween? = nil
local closeTween: Tween? = nil

local freeTogglePositioning = false
local freeMenuPositioning = false

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
	local absPos = popup.AbsolutePosition
	local desired = Vector2.new(absPos.X + (anchor.X * CONFIG.PopupSize.X), absPos.Y + (anchor.Y * CONFIG.PopupSize.Y))
	local clamped = clampPopupPos(desired, CONFIG.PopupSize, anchor, viewport)
	popup.Position = UDim2.fromOffset(clamped.X, clamped.Y)
end

local function tweenPopup(open: boolean)
	if openTween then
		openTween:Cancel()
	end
	if closeTween then
		closeTween:Cancel()
	end

	if open then
		popup.Visible = true

		if not freeMenuPositioning then
			placePopupCentered()
		else
			placePopupClampedToViewport()
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

	toggleIcon.Text = isOpen and "×" or "≡"
	local ringStroke = accentRing:FindFirstChildOfClass("UIStroke")
	if ringStroke then
		(ringStroke :: UIStroke).Transparency = isOpen and 0.05 or 0.35
	end

	tweenPopup(isOpen)
end

-- DRAGGING (SEPARATE)
enableDrag(toggleButton, toggleButton, function()
	freeTogglePositioning = true
end, nil)

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
-- print("ESP Boxes currently:", toggleStates["visuals_boxes"])
