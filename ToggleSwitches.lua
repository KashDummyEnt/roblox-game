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

	values = {}, -- [key] = any (string/number/table)
	valueListeners = {}, -- [key] = {fn, fn, ...}
}

local Store = G.__HIGGI_TOGGLES

--============================================================
-- Dropdown manager (ONLY ONE open at a time)
--============================================================
local DropdownManager = {
	OpenPopup = nil :: Frame?,
	OpenButton = nil :: GuiObject?,
	OpenClose = nil :: (() -> ())?,
}


local function closeAnyDropdown()
	if DropdownManager.OpenClose then
		DropdownManager.OpenClose()
	elseif DropdownManager.OpenPopup then
		DropdownManager.OpenPopup.Visible = false
	end

	DropdownManager.OpenPopup = nil
	DropdownManager.OpenButton = nil
	DropdownManager.OpenClose = nil
end


function ToggleSwitches.CloseAllDropdowns()
	closeAnyDropdown()
end


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

--============================================================
-- Toggle state notifications
--============================================================
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

--============================================================
-- Value notifications (dropdown + future controls)
--============================================================
local function notifyValue(key, value)
	local list = Store.valueListeners[key]
	if not list then
		return
	end
	for i = 1, #list do
		local fn = list[i]
		if type(fn) == "function" then
			pcall(fn, value)
		end
	end
end

function ToggleSwitches.SubscribeValue(key, fn)
	if type(fn) ~= "function" then
		return function() end
	end

	Store.valueListeners[key] = Store.valueListeners[key] or {}
	local list = Store.valueListeners[key]
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

function ToggleSwitches.GetValue(key, defaultValue)
	local v = Store.values[key]
	if v == nil then
		v = defaultValue
		Store.values[key] = v
	end
	return v
end

function ToggleSwitches.SetValue(key, value)
	if Store.values[key] == value then
		return
	end
	Store.values[key] = value
	notifyValue(key, value)
end

--============================================================
-- Toggle UI card
--============================================================
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

	if not isTouchDevice(UserInputService) then
		card.MouseEnter:Connect(function()
			card.BackgroundColor3 = config.Bg3
		end)
		card.MouseLeave:Connect(function()
			card.BackgroundColor3 = config.Bg2
		end)

		switchBtn.MouseEnter:Connect(function()
			track.BackgroundColor3 = (Store.states[key] and config.Accent) or config.Bg2
		end)
		switchBtn.MouseLeave:Connect(function()
			applyVisual(Store.states[key], true)
		end)
	end

	switchBtn.MouseButton1Click:Connect(function()
		setState(not Store.states[key])
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
		setState(not Store.states[key])
	end)

	titleLbl.ZIndex = 46
	descLbl.ZIndex = 46
	switchBtn.ZIndex = 48
	track.ZIndex = 48
	knob.ZIndex = 49

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

--============================================================
-- Dropdown UI card
--============================================================
function ToggleSwitches.AddDropDownCard(parent, key, title, desc, order, defaultValue, getOptions, config, services, onSelected)
	if Store.values[key] == nil then
		Store.values[key] = defaultValue
	end

	local UserInputService = services.UserInputService
	local TweenService = services.TweenService


	local card = make("Frame", {
		Name = "DropDownCard_" .. tostring(key),
		BackgroundColor3 = config.Bg2,
		Size = UDim2.new(1, 0, 0, 92),
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
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 10, 0, 8),
		ZIndex = 44,
		Parent = card,
	})

	make("TextLabel", {
		BackgroundTransparency = 1,
		Text = desc,
		TextColor3 = config.SubText,
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

	local btn = make("TextButton", {
		Name = "DropButton",
		AutoButtonColor = false,
		BackgroundColor3 = config.Bg3,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 10, 0, 56),
		Text = "",
		ZIndex = 45,
		Parent = card,
	})
	addCorner(btn, 10)
	addStroke(btn, 1, config.Stroke, 0.25)

	local label = make("TextLabel", {
		Name = "Value",
		BackgroundTransparency = 1,
		Text = tostring(Store.values[key] or ""),
		TextColor3 = config.Text,
		TextSize = 14,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -34, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		ZIndex = 46,
		Parent = btn,
	})

	make("TextLabel", {
		Name = "Caret",
		BackgroundTransparency = 1,
		Text = "▾",
		TextColor3 = config.SubText,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 24, 1, 0),
		Position = UDim2.new(1, -26, 0, 0),
		ZIndex = 46,
		Parent = btn,
	})

local Overlay = services.Overlay
assert(Overlay, "DropDown requires Overlay in services")

local popup = make("Frame", {
	Name = "Popup",
	BackgroundColor3 = config.Bg2,
	Visible = false,
	Size = UDim2.fromOffset(200, 180),
	ZIndex = 500,
	ClipsDescendants = true,
	Parent = Overlay,
})


local POPUP_HEIGHT = 180
local POPUP_NUDGE_X = 0
local POPUP_NUDGE_Y = 6

local function positionPopup()
	local btnPos = btn.AbsolutePosition
	local btnSize = btn.AbsoluteSize

	popup.Position = UDim2.fromOffset(
		btnPos.X + POPUP_NUDGE_X,
		btnPos.Y + btnSize.Y + POPUP_NUDGE_Y
	)

	popup.Size = UDim2.fromOffset(
		btnSize.X,
		POPUP_HEIGHT
	)
end

local openTween: Tween? = nil
local closeTween: Tween? = nil

local OPEN_TIME = 0.18
local CLOSE_TIME = 0.12

local OPEN_FADE_FROM = 1
local OPEN_FADE_TO = 0
local CLOSE_FADE_TO = 1

local function cancelTweens()
	if openTween then
		openTween:Cancel()
		openTween = nil
	end
	if closeTween then
		closeTween:Cancel()
		closeTween = nil
	end
end

addCorner(popup, 12)
addStroke(popup, 1, config.Stroke, 0.25)

local popupStroke = popup:FindFirstChildOfClass("UIStroke")

popup.BackgroundTransparency = 1
if popupStroke then
	(popupStroke :: UIStroke).Transparency = 1
end

local function setPopupOpen(open: boolean)
	cancelTweens()

	local stroke = popupStroke

	if open then
		positionPopup()

		-- start collapsed + faded, then expand + fade in
		popup.Visible = true
		popup.Size = UDim2.fromOffset(btn.AbsoluteSize.X, 0)
		popup.BackgroundTransparency = OPEN_FADE_FROM

		if stroke then
			(stroke :: UIStroke).Transparency = 1
		end

		local tInfo = TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		openTween = TweenService:Create(popup, tInfo, {
			Size = UDim2.fromOffset(btn.AbsoluteSize.X, POPUP_HEIGHT),
			BackgroundTransparency = OPEN_FADE_TO,
		})
		openTween:Play()

		if stroke then
			TweenService:Create(stroke, tInfo, {Transparency = 0.25}):Play()
		end
	else
		if not popup.Visible then
			return
		end

		local tInfo = TweenInfo.new(CLOSE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		closeTween = TweenService:Create(popup, tInfo, {
			Size = UDim2.fromOffset(popup.Size.X.Offset, 0),
			BackgroundTransparency = CLOSE_FADE_TO,
		})
		closeTween.Completed:Once(function()
			popup.Visible = false
			cancelTweens()

			-- reset for next open
			popup.BackgroundTransparency = OPEN_FADE_FROM
			if stroke then
				(stroke :: UIStroke).Transparency = 1
			end
		end)
		closeTween:Play()

		if stroke then
			TweenService:Create(stroke, tInfo, {Transparency = 1}):Play()
		end
	end
end

closeTween:Play()

if stroke then
	TweenService:Create(stroke, tInfo, {Transparency = 1}):Play()
end

	end
end

	addCorner(popup, 12)
	addStroke(popup, 1, config.Stroke, 0.25)

	local list = make("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 501,
		Parent = popup,
	})

	local function rebuild()
		for _, ch in ipairs(list:GetChildren()) do
			if ch:IsA("TextButton") or ch:IsA("TextLabel") then
				ch:Destroy()
			end
		end

		local options = {}
		if type(getOptions) == "function" then
			local ok, res = pcall(getOptions)
			if ok and type(res) == "table" then
				options = res
			end
		end

		if #options == 0 then
			make("TextLabel", {
				BackgroundTransparency = 1,
				Text = "No options.",
				TextColor3 = config.SubText,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Size = UDim2.new(1, -16, 1, -16),
				Position = UDim2.new(0, 8, 0, 8),
				ZIndex = 502,
				Parent = list,
			})
			list.CanvasSize = UDim2.new(0, 0, 0, 0)
			return
		end

		local y = 0
		local itemH = 30

		for i = 1, #options do
			local opt = options[i]
			local text = tostring(opt)

			local item = make("TextButton", {
				AutoButtonColor = false,
				BackgroundColor3 = config.Bg3,
				Size = UDim2.new(1, -8, 0, itemH),
				Position = UDim2.new(0, 4, 0, y + 4),
				Text = "",
				ZIndex = 502,
				Parent = list,
			})
			addCorner(item, 8)
			addStroke(item, 1, config.Stroke, 0.35)

			make("TextLabel", {
				BackgroundTransparency = 1,
				Text = text,
				TextColor3 = config.Text,
				TextSize = 13,
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, -12, 1, 0),
				Position = UDim2.new(0, 8, 0, 0),
				ZIndex = 503,
				Parent = item,
			})

			item.MouseEnter:Connect(function()
				item.BackgroundColor3 = config.Bg2
			end)
			item.MouseLeave:Connect(function()
				item.BackgroundColor3 = config.Bg3
			end)

			item.MouseButton1Click:Connect(function()
				Store.values[key] = opt
				label.Text = tostring(opt)
				notifyValue(key, opt)

				if onSelected then
					pcall(onSelected, opt)
				end

				closeAnyDropdown()

			end)

			y = y + itemH + 6
		end

		list.CanvasSize = UDim2.new(0, 0, 0, y + 8)
	end

btn.MouseButton1Click:Connect(function()
	local wantOpen = not popup.Visible

	if wantOpen then
		-- close whatever is currently open first
		if DropdownManager.OpenPopup and DropdownManager.OpenPopup ~= popup then
			closeAnyDropdown()
		end

		setPopupOpen(true)
		rebuild()

		DropdownManager.OpenPopup = popup
		DropdownManager.OpenButton = btn
		DropdownManager.OpenClose = function()
			setPopupOpen(false)
		end
	else
		setPopupOpen(false)

		if DropdownManager.OpenPopup == popup then
			DropdownManager.OpenPopup = nil
			DropdownManager.OpenButton = nil
			DropdownManager.OpenClose = nil
		end
	end
end)




	-- click-off close
UserInputService.InputBegan:Connect(function(input, gp)

	if not popup.Visible then return end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1
	and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	-- Only react if THIS popup is the open one
	if DropdownManager.OpenPopup ~= popup then
		return
	end

	local clickPos = input.Position

	local function isInside(guiObject: GuiObject)
		local absPos = guiObject.AbsolutePosition
		local absSize = guiObject.AbsoluteSize

		return clickPos.X >= absPos.X
			and clickPos.X <= absPos.X + absSize.X
			and clickPos.Y >= absPos.Y
			and clickPos.Y <= absPos.Y + absSize.Y
	end

	-- If click is NOT inside popup AND NOT inside the dropdown button
	if not isInside(popup) and not isInside(btn) then
		closeAnyDropdown()
	end
end)




	return {
		Get = function()
			return Store.values[key]
		end,
		Set = function(v)
			Store.values[key] = v
			label.Text = tostring(v)
			notifyValue(key, v)
			if onSelected then
				pcall(onSelected, v)
			end
		end,
		Refresh = function()
			if popup.Visible then
				rebuild()
			end
		end,
	}
end

return ToggleSwitches
