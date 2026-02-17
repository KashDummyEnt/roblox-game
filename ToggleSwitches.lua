-- ToggleSwitches.lua (REMOTE MODULE, LUA-SAFE)
-- Must return a table.

local ToggleSwitches = {}

local toggleStates = {}

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

function ToggleSwitches.GetState(key, defaultState)
	local v = toggleStates[key]
	if v == nil then
		v = defaultState or false
		toggleStates[key] = v
	end
	return v
end

function ToggleSwitches.SetState(key, value)
	toggleStates[key] = value and true or false
end

function ToggleSwitches.FlipState(key, defaultState)
	local cur = ToggleSwitches.GetState(key, defaultState)
	local nextState = not cur
	toggleStates[key] = nextState
	return nextState
end

function ToggleSwitches.AddToggleCard(parent, key, title, desc, order, defaultState, config, services, onChanged)
	if toggleStates[key] == nil then
		toggleStates[key] = defaultState and true or false
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
		Position = UDim2.new(0, 0, 0, 0),
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
		if toggleStates[key] == nextState then
			return
		end
		toggleStates[key] = nextState
		applyVisual(nextState, false)
		if onChanged then
			onChanged(nextState)
		end
	end

	applyVisual(toggleStates[key], true)

	if not isTouchDevice(UserInputService) then
		card.MouseEnter:Connect(function()
			card.BackgroundColor3 = config.Bg3
		end)
		card.MouseLeave:Connect(function()
			card.BackgroundColor3 = config.Bg2
		end)

		switchBtn.MouseEnter:Connect(function()
			track.BackgroundColor3 = (toggleStates[key] and config.Accent) or config.Bg2
		end)
		switchBtn.MouseLeave:Connect(function()
			applyVisual(toggleStates[key], true)
		end)
	end

	switchBtn.MouseButton1Click:Connect(function()
		setState(not toggleStates[key])
	end)

	local clickCatcher = make("TextButton", {
		Name = "ClickCatcher",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		ZIndex = 45,
		Parent = card,
	})
	clickCatcher.MouseButton1Click:Connect(function()
		setState(not toggleStates[key])
	end)

	titleLbl.ZIndex = 46
	descLbl.ZIndex = 46
	switchBtn.ZIndex = 48
	track.ZIndex = 48
	knob.ZIndex = 49

	return {
		Get = function()
			return toggleStates[key] and true or false
		end,
		Set = function(v)
			setState(v)
		end,
		Flip = function()
			setState(not toggleStates[key])
		end,
	}
end

return ToggleSwitches
