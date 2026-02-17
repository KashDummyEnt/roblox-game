--!strict
-- Menu.lua
-- PopupMenu client UI + GitHub action button
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
	PopupSize = Vector2.new(360, 260),

	OpenTweenTime = 0.18,
	CloseTweenTime = 0.14,

	Accent = Color3.fromRGB(120, 140, 255),
	Bg = Color3.fromRGB(20, 20, 24),
	Bg2 = Color3.fromRGB(26, 26, 32),
	Text = Color3.fromRGB(235, 235, 240),
	SubText = Color3.fromRGB(180, 180, 190),
	Stroke = Color3.fromRGB(60, 60, 70),
}

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

local function addShadow(parent: Instance)
	local shadow = make("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = "rbxassetid://1316045217",
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(10, 10, 118, 118),
		Size = UDim2.new(1, 30, 1, 30),
		Position = UDim2.new(0, -15, 0, -15),
		ZIndex = (parent :: any).ZIndex - 1,
		Parent = parent,
	})
	return shadow
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

-- Popup panel
local popup = make("Frame", {
	Name = CONFIG.PopupName,
	BackgroundColor3 = CONFIG.Bg,
	Size = UDim2.fromOffset(CONFIG.PopupSize.X, CONFIG.PopupSize.Y),
	Visible = true,
	ZIndex = 40,
	Parent = screenGui,
})
addCorner(popup, 14)
addStroke(popup, 1, CONFIG.Stroke, 0.2)
addShadow(popup)

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
	Text = "Menu",
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
	Text = "client-side UI (script-built)",
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

-- Divider
make("Frame", {
	Name = "Divider",
	BackgroundColor3 = CONFIG.Stroke,
	BackgroundTransparency = 0.6,
	Size = UDim2.new(1, -20, 0, 1),
	Position = UDim2.new(0, 10, 0, 44),
	ZIndex = 41,
	Parent = popup,
})

-- Content area
local content = make("ScrollingFrame", {
	Name = "Content",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageTransparency = 0.25,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Size = UDim2.new(1, -20, 1, -56),
	Position = UDim2.new(0, 10, 0, 52),
	ZIndex = 41,
	Parent = popup,
})

make("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = content,
})

make("UIPadding", {
	PaddingTop = UDim.new(0, 4),
	PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 4),
	PaddingRight = UDim.new(0, 6),
	Parent = content,
})

local function addCard(textTop: string, textBottom: string, order: number, onClick: (() -> ())?)
	local card = make("TextButton", {
		Name = "Card",
		AutoButtonColor = false,
		BackgroundColor3 = CONFIG.Bg2,
		Size = UDim2.new(1, 0, 0, 64),
		ZIndex = 42,
		LayoutOrder = order,
		Text = "",
		Parent = content,
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
		ZIndex = 43,
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
		ZIndex = 43,
		Parent = card,
	})

	if onClick then
		card.MouseButton1Click:Connect(onClick)

		card.MouseEnter:Connect(function()
			card.BackgroundColor3 = CONFIG.Bg
		end)
		card.MouseLeave:Connect(function()
			card.BackgroundColor3 = CONFIG.Bg2
		end)
		card.MouseButton1Down:Connect(function()
			card.BackgroundTransparency = 0.05
		end)
		card.MouseButton1Up:Connect(function()
			card.BackgroundTransparency = 0
		end)
	end
end

addCard("Apply Skybox", "Runs ClientSky.lua from GitHub.", 1, function()
	runRemote(SKY_URL)
end)

addCard("Button 2", "This is just UI structure. Hook logic later.", 2, function()
	print("Button 2 clicked")
end)

addCard("Info", "Everything you see was created by this LocalScript.", 3, nil)

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
		(ringStroke :: UIStroke).Transparency = isOpen and 0.1 or 0.35
	end

	tweenPopup(isOpen)
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

setOpen(false)
