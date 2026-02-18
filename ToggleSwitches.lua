-- ToggleSwitches.lua (REMOTE MODULE, LUA-SAFE, SHARED STATE)
-- Must return a table.

local ToggleSwitches = {}

local function getGlobal()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local G = getGlobal()

G.__HIGGI_TOGGLES = G.__HIGGI_TOGGLES or {
	states = {},
	listeners = {}, -- [key] = {fn, fn, ...}
	colors = {}, -- NEW
	colorListeners = {}, -- NEW
}

local Store = G.__HIGGI_TOGGLES

local function make(instanceType, props)
	local inst = Instance.new(instanceType)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
	return inst
end

local function addCorner(parent, radius)
	make("UICorner", {
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	})
end

local function addStroke(parent, thickness, color, transparency)
	make("UIStroke", {
		Thickness = thickness,
		Color = color,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function isTouchDevice(userInputService)
	return userInputService.TouchEnabled and not userInputService.KeyboardEnabled
end

------------------------------------------------------------------
-- TOGGLE SYSTEM (UNCHANGED)
------------------------------------------------------------------

local function notify(key, state)
	local list = Store.listeners[key]
	if not list then
		return
	end
	for i = 1, #list do
		local fn = list[i]
		if type(fn) == "function" then
			pcall(fn, state)
		end
	end
end

function ToggleSwitches.Subscribe(key, fn)
	if type(fn) ~= "function" then
		return function() end
	end

	Store.listeners[key] = Store.listeners[key] or {}
	local list = Store.listeners[key]
	table.insert(list, fn)

	local alive = true
	return function()
		if not alive then
			return
		end
		alive = false
		for i = #list, 1, -1 do
			if list[i] == fn then
				table.remove(list, i)
				break
			end
		end
	end
end

function ToggleSwitches.GetState(key, defaultState)
	local v = Store.states[key]
	if v == nil then
		v = defaultState or false
		Store.states[key] = v
	end
	return v
end

function ToggleSwitches.SetState(key, value)
	local nextState = value and true or false
	if Store.states[key] == nextState then
		return
	end
	Store.states[key] = nextState
	notify(key, nextState)
end

function ToggleSwitches.FlipState(key, defaultState)
	local cur = ToggleSwitches.GetState(key, defaultState)
	local nextState = not cur
	ToggleSwitches.SetState(key, nextState)
	return nextState
end

------------------------------------------------------------------
-- COLOR SYSTEM (NEW)
------------------------------------------------------------------

local function notifyColor(key, color)
	local list = Store.colorListeners[key]
	if not list then
		return
	end
	for i = 1, #list do
		local fn = list[i]
		if type(fn) == "function" then
			pcall(fn, color)
		end
	end
end

function ToggleSwitches.SetColor(key, color)
	Store.colors[key] = color
	notifyColor(key, color)
end

function ToggleSwitches.GetColor(key, defaultColor)
	if not Store.colors[key] then
		Store.colors[key] = defaultColor
	end
	return Store.colors[key]
end

function ToggleSwitches.SubscribeColor(key, fn)
	if type(fn) ~= "function" then
		return function() end
	end

	Store.colorListeners[key] = Store.colorListeners[key] or {}
	local list = Store.colorListeners[key]
	table.insert(list, fn)

	local alive = true
	return function()
		if not alive then
			return
		end
		alive = false
		for i = #list, 1, -1 do
			if list[i] == fn then
				table.remove(list, i)
				break
			end
		end
	end
end

------------------------------------------------------------------
-- EXISTING TOGGLE CARD (UNCHANGED)
------------------------------------------------------------------

function ToggleSwitches.AddToggleCard(parent, key, title, desc, order, defaultState, config, services, onChanged)

	if Store.states[key] == nil then
		Store.states[key] = defaultState and true or false
	end

	local TweenService = services.TweenService
	local UserInputService = services.UserInputService

	local card = make("Frame", {
		Name = "ToggleCard_" .. tostring(key),
		BackgroundColor3 = config.Bg2,
		Size = UDim2.new(1, 0, 0, 64),
		ZIndex = 43,
		LayoutOrder = order,
		Parent = parent,
	})
	addCorner(card, 12)
	addStroke(card, 1, config.Stroke, 0.35)

	local titleLbl = make("TextLabel", {
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = config.Text,
		TextSize = 15,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -118, 0, 22),
		Position = UDim2.new(0, 10, 0, 8),
		ZIndex = 44,
		Parent = card,
	})

	local descLbl = make("TextLabel", {
		BackgroundTransparency = 1,
		Text = desc,
		TextColor3 = config.SubText,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -118, 0, 28),
		Position = UDim2.new(0, 10, 0, 30),
		ZIndex = 44,
		Parent = card,
	})

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
	})

	local track = make("Frame", {
		Name = "Track",
		BackgroundColor3 = config.Bg3,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 46,
		Parent = switchBtn,
	})
	addCorner(track, math.floor(SWITCH_H / 2))
	addStroke(track, 1, config.Stroke, 0.25)

	local knob = make("Frame", {
		Name = "Knob",
		BackgroundColor3 = Color3.fromRGB(245, 245, 248),
		Size = UDim2.fromOffset(SWITCH_H - 6, SWITCH_H - 6),
		Position = UDim2.new(0, 3, 0, 3),
		ZIndex = 47,
		Parent = switchBtn,
	})
	addCorner(knob, 999)
	addStroke(knob, 1, Color3.fromRGB(0, 0, 0), 0.75)

	local function applyVisual(state, instant)
		local knobXOn = SWITCH_W - (SWITCH_H - 6) - 3
		local knobXOff = 3

		local goalTrackColor = state and config.Accent or config.Bg3
		local goalStrokeColor = state and config.Accent or config.Stroke
		local goalStrokeTrans = state and 0.05 or 0.25
		local goalKnobPos = state and UDim2.new(0, knobXOn, 0, 3) or UDim2.new(0, knobXOff, 0, 3)

		local trackStroke = track:FindFirstChildOfClass("UIStroke")
		if not trackStroke then
			return
		end

		if instant then
			track.BackgroundColor3 = goalTrackColor
			trackStroke.Color = goalStrokeColor
			trackStroke.Transparency = goalStrokeTrans
			knob.Position = goalKnobPos
			return
		end

		local ti = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(track, ti, {BackgroundColor3 = goalTrackColor}):Play()
		TweenService:Create(trackStroke, ti, {Color = goalStrokeColor, Transparency = goalStrokeTrans}):Play()
		TweenService:Create(knob, ti, {Position = goalKnobPos}):Play()
	end

	local function setState(nextState)
		nextState = nextState and true or false
		if Store.states[key] == nextState then
			return
		end

		Store.states[key] = nextState
		applyVisual(nextState, false)
		notify(key, nextState)

		if onChanged then
			onChanged(nextState)
		end
	end

	applyVisual(Store.states[key], true)

	switchBtn.MouseButton1Click:Connect(function()
		setState(not Store.states[key])
	end)

	return {
		Get = function()
			return Store.states[key] and true or false
		end,
		Set = function(v)
			setState(v)
		end,
		Flip = function()
			setState(not Store.states[key])
		end,
	}
end

------------------------------------------------------------------
-- COLOR PICKER CARD
------------------------------------------------------------------

function ToggleSwitches.AddColorPickerCard(parent, key, title, desc, order, defaultColor, config)

	local current = ToggleSwitches.GetColor(key, defaultColor)
	local h, s, v = current:ToHSV()

	local UIS = game:GetService("UserInputService")

	local card = make("Frame", {
		Name = "ColorCard_" .. key,
		BackgroundColor3 = config.Bg2,
		Size = UDim2.new(1, 0, 0, 70),
		ZIndex = 43,
		LayoutOrder = order,
		Parent = parent,
	})
	addCorner(card, 12)
	addStroke(card, 1, config.Stroke, 0.35)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = config.Text,
		TextSize = 15,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		ZIndex = 44,
		Parent = card,
	})

	local preview = make("TextButton", {
		Text = "",
		BackgroundColor3 = current,
		Size = UDim2.new(0, 40, 0, 40),
		Position = UDim2.new(1, -50, 0.5, -20),
		ZIndex = 45,
		Parent = card,
	})
	addCorner(preview, 10)
	addStroke(preview, 1, config.Stroke, 0.3)

	-- POPUP
	local popup = make("Frame", {
		BackgroundColor3 = config.Bg,
		Size = UDim2.fromOffset(220, 220),
		Visible = false,
		ZIndex = 100,
		Parent = card.Parent.Parent, -- attach to page container
	})
	addCorner(popup, 14)
	addStroke(popup, 1, config.Stroke, 0.3)

	local square = make("Frame", {
		Size = UDim2.fromOffset(160, 160),
		Position = UDim2.fromOffset(15, 15),
		ZIndex = 101,
		Parent = popup,
	})
	addCorner(square, 8)

	local hueBar = make("Frame", {
		Size = UDim2.fromOffset(18, 160),
		Position = UDim2.fromOffset(180, 15),
		ZIndex = 101,
		Parent = popup,
	})
	addCorner(hueBar, 8)

	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0,1,1)),
			ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17,1,1)),
			ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33,1,1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5,1,1)),
			ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67,1,1)),
			ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83,1,1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1,1,1)),
		}),
		Parent = hueBar,
	})

	local function updateSquareColor()
		square.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
	end

	updateSquareColor()

	local draggingSquare = false
	local draggingHue = false

	local function applyColor()
		local newColor = Color3.fromHSV(h, s, v)
		preview.BackgroundColor3 = newColor
		ToggleSwitches.SetColor(key, newColor)
	end

	square.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSquare = true
		end
	end)

	hueBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingHue = true
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSquare = false
			draggingHue = false
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end

		if draggingSquare then
			local relX = math.clamp((input.Position.X - square.AbsolutePosition.X) / square.AbsoluteSize.X, 0, 1)
			local relY = math.clamp((input.Position.Y - square.AbsolutePosition.Y) / square.AbsoluteSize.Y, 0, 1)
			s = relX
			v = 1 - relY
			applyColor()
		elseif draggingHue then
			local rel = math.clamp((input.Position.Y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
			h = rel
			updateSquareColor()
			applyColor()
		end
	end)

	preview.MouseButton1Click:Connect(function()
		popup.Visible = not popup.Visible
	end)

	UIS.InputBegan:Connect(function(input)
		if popup.Visible and input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not popup:IsAncestorOf(input.Target) then
				popup.Visible = false
			end
		end
	end)
end


return ToggleSwitches
