--!strict
-- Menu.lua
-- PopupMenu client UI + 5 left tabs + GitHub action button
-- Load in Roblox with:
-- loadstring(game:HttpGet('https://raw.githubusercontent.com/KashDummyEnt/roblox-game/refs/heads/main/Menu.lua'))()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
	PopupSize = Vector2.new(520, 290),

	OpenTweenTime = 0.18,
	CloseTweenTime = 0.14,

	-- Dark grey + bright red scheme
	Accent = Color3.fromRGB(235, 45, 65),	-- bright red
	Bg = Color3.fromRGB(14, 14, 16),		-- deepest
	Bg2 = Color3.fromRGB(20, 20, 24),		-- panels
	Bg3 = Color3.fromRGB(26, 26, 32),		-- hover/alt
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

local function getCornerPositions(toggleSize: number, popupSize: Vector2, margin: number)
	local ts = toggleSize
	local psX, psY = popupSize.X, popupSize.Y

	local function u2(xScale: number, xOffset: number, yScale: number, yOffset: number): UDim2
		return UDim2.new(xScale, xOffset, yScale, yOffset)
	end

	if CONFIG.AnchorCorner == "BottomLeft" then
		local togglePos = u2(0, margin, 1, -(margin + ts))
		local popupOpen = u2(0, margin, 1, -(margin + ts + 12 + psY))
		local popupClosed = u2(0, margin, 1, -(margin + ts + 12))
		return togglePos, popupClosed, popupOpen
	end

	if CONFIG.AnchorCorner == "BottomRight" then
		local togglePos = u2(1, -(margin + ts), 1, -(margin + ts))
		local popupOpen = u2(1, -(margin + psX), 1, -(margin + ts + 12 + psY))
		local popupClosed = u2(1, -(margin + psX), 1, -(margin + ts + 12))
		return togglePos, popupClosed, popupOpen
	end

	if CONFIG.AnchorCorner == "TopLeft" then
		local togglePos = u2(0, margin, 0, margin)
		local popupOpen = u2(0, margin, 0, margin + ts + 12)
		local popupClosed = u2(0, margin, 0, margin + ts + 12 - psY)
		return togglePos, popupClosed, popupOpen
	end

	local togglePos = u2(1, -(margin + ts), 0, margin)
	local popupOpen = u2(1, -(margin + psX), 0, margin + ts + 12)
	local popupClosed = u2(1, -(margin + psX), 0, margin + ts + 12 - psY)
	return togglePos, popupClosed, popupOpen
end

local function isTouchDevice(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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

-- Popup panel (NO SHADOW)
local popup = make("Frame", {
	Name = CONFIG.PopupName,
	BackgroundColor3 = CONFIG.Bg,
	Size = UDim2.fromOffset(CONFIG.PopupSize.X, CONFIG.PopupSize.Y),
	Visible = true,
	ZIndex = 40,
	Parent = screenGui,
})
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

-- Header
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
	Position = UDim2.new(0, 14, 0, 0),
	ZIndex = 42,
	Parent = header,
})

make("TextLabel", {
	Name = "Subtitle",
	BackgroundTransparency = 1,
	Text = "tabs • client UI",
	TextColor3 = CONFIG.SubText,
	TextSize = 13,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	Size = UDim2.new(1, -88, 0, 18),
	Position = UDim2.new(0, 14, 0, 22),
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
	Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
	Position = UDim2.new(0, 0, 0, 0),
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

local sidebarList = make("UIListLayout", {
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
	Size = UDim2.new(1, -(SIDEBAR_WIDTH + 10), 1, 0),
	Position = UDim2.new(0, SIDEBAR_WIDTH + 10, 0, 0),
	ZIndex = 42,
	Parent = body,
})

local function makePage(name: string): ScrollingFrame
	local page = make("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
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

	make("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})

	make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 6),
		Parent = page,
	})

	return page
end

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
	})
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

local function addHeader(parent: Instance, text: string, order: number)
	local h = make("Frame", {
		Name = "SectionHeader",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 43,
		LayoutOrder = order,
		Parent = parent,
	})

	local pill = make("Frame", {
		Name = "Pill",
		BackgroundColor3 = CONFIG.Bg2,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 43,
		Parent = h,
	})
	addCorner(pill, 10)
	addStroke(pill, 1, CONFIG.Stroke, 0.35)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = CONFIG.Text,
		TextSize = 13,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		ZIndex = 44,
		Parent = pill,
	})

	local accent = make("Frame", {
		Name = "Accent",
		BackgroundColor3 = CONFIG.Accent,
		Size = UDim2.new(0, 3, 1, -10),
		Position = UDim2.new(0, 8, 0, 5),
		ZIndex = 45,
		Parent = pill,
	})
	addCorner(accent, 2)
end

-- Create pages
local pageMain = makePage("Main")
local pageVisuals = makePage("Visuals")
local pageWorld = makePage("World")
local pageSettings = makePage("Settings")
local pageAbout = makePage("About")

-- Fill pages (examples)
addHeader(pageMain, "Quick Actions", 1)
addCard(pageMain, "Apply Skybox", "Runs ClientSky.lua from GitHub.", 2, function()
	runRemote(SKY_URL)
end)
addCard(pageMain, "Close Menu", "Hides the panel.", 3, function()
	-- will be wired after setOpen exists
end)

addHeader(pageVisuals, "Visuals", 1)
addCard(pageVisuals, "Apply Skybox", "Same action, different tab.", 2, function()
	runRemote(SKY_URL)
end)
addCard(pageVisuals, "Placeholder", "Add visuals toggles here.", 3, function()
	print("Visuals placeholder")
end)

addHeader(pageWorld, "World", 1)
addCard(pageWorld, "Placeholder", "World options go here.", 2, function()
	print("World placeholder")
end)

addHeader(pageSettings, "Settings", 1)
addCard(pageSettings, "Placeholder", "UI settings, keybinds, etc.", 2, function()
	print("Settings placeholder")
end)

addHeader(pageAbout, "About", 1)
addCard(pageAbout, "Info", "Higgi's Menu • GitHub-driven actions.", 2, nil)

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
	{Name = "About", Page = pageAbout, Icon = "?"}
}

local currentTabName = ""

local function setActivePage(name: string)
	if currentTabName == name then return end
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
				(stroke :: UIStroke).Color = isActive and CONFIG.Accent or CONFIG.Stroke
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
local togglePos, popupClosedPos, popupOpenPos = getCornerPositions(CONFIG.ToggleSize, CONFIG.PopupSize, CONFIG.Margin)
toggleButton.Position = togglePos

local isOpen = false
popup.Position = popupClosedPos
popup.Size = UDim2.fromOffset(CONFIG.PopupSize.X, 0)
popup.Visible = false

local openTween: Tween? = nil
local closeTween: Tween? = nil

local function tweenPopup(open: boolean)
	if openTween then openTween:Cancel() end
	if closeTween then closeTween:Cancel() end

	if open then
		popup.Visible = true
		popup.Position = popupOpenPos
		popup.Size = UDim2.fromOffset(CONFIG.PopupSize.X, 0)

		local tInfo = TweenInfo.new(CONFIG.OpenTweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		openTween = TweenService:Create(popup, tInfo, {
			Size = UDim2.fromOffset(CONFIG.PopupSize.X, CONFIG.PopupSize.Y),
		})
		openTween:Play()
	else
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
	if isOpen == nextOpen then return end
	isOpen = nextOpen

	toggleIcon.Text = isOpen and "×" or "≡"
	local ringStroke = accentRing:FindFirstChildOfClass("UIStroke")
	if ringStroke then
		(ringStroke :: UIStroke).Transparency = isOpen and 0.05 or 0.35
	end

	tweenPopup(isOpen)
end

-- Wire the "Close Menu" card now that setOpen exists
do
	for _, child in ipairs(pageMain:GetChildren()) do
		if child:IsA("TextButton") then
			local labels = child:GetChildren()
			for _, l in ipairs(labels) do
				if l:IsA("TextLabel") and l.Text == "Close Menu" then
					child.MouseButton1Click:Connect(function()
						setOpen(false)
					end)
				end
			end
		end
	end
end

toggleButton.MouseButton1Click:Connect(function()
	setOpen(not isOpen)
end)

closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		setOpen(false)
	end
end)

-- Default tab
setActivePage("Main")
setTabVisuals("Main")
setOpen(false)
