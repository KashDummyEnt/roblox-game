--!strict
-- Weather.lua
-- Toggle key: "world_weather"
-- Value key:  "world_weather_type"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

------------------------------------------------------------
-- GLOBAL ACCESS
------------------------------------------------------------

local function getGlobal(): any
	local gg = (typeof(getgenv) == "function") and getgenv() or nil
	if gg then
		return gg
	end
	return _G
end

local G = getGlobal()

local TOGGLE_KEY = "world_weather"
local VALUE_KEY = "world_weather_type"

------------------------------------------------------------
-- WAIT FOR TOGGLE API
------------------------------------------------------------

local function waitForTogglesApi(timeoutSeconds: number): any?
	local start = os.clock()

	while os.clock() - start < timeoutSeconds do
		local api = G.__HIGGI_TOGGLES_API

		if type(api) == "table"
		and type(api.GetState) == "function"
		and type(api.Subscribe) == "function"
		and type(api.SubscribeValue) == "function" then
			return api
		end

		task.wait(0.05)
	end

	return nil
end

local Toggles = waitForTogglesApi(6)
if not Toggles then
	warn("[Weather] Toggle API not found")
	return
end

------------------------------------------------------------
-- STATE
------------------------------------------------------------

local enabled = false
local currentType = Toggles.GetValue(VALUE_KEY, "Snow")

-- Snow system
local snowPart: Part? = nil
local snowEmitter: ParticleEmitter? = nil
local followConn: RBXScriptConnection? = nil

------------------------------------------------------------
-- SNOW (CAMERA VOLUME SYSTEM)
------------------------------------------------------------

local function createSnow()
	if snowPart then
		return
	end

	local part = Instance.new("Part")
	part.Name = "LocalSnowVolume"

	-- MUCH bigger volume
	part.Size = Vector3.new(200, 2, 200)

	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.CastShadow = false
	part.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SnowEmitter"
	emitter.Texture = "rbxassetid://118641183"

	-- DENSITY BOOST
	emitter.Rate = 600

	-- More visible flakes at once
	emitter.Lifetime = NumberRange.new(6, 8)

	-- Slightly slower fall for realism
	emitter.Speed = NumberRange.new(8, 12)

	-- Spread across entire plane
	emitter.SpreadAngle = Vector2.new(180, 180)

	-- Stronger gravity pull
	emitter.Acceleration = Vector3.new(0, -6, 0)

	emitter.VelocitySpread = 180

	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.2),
	})

	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})

	emitter.Parent = part

	snowPart = part
	snowEmitter = emitter

	followConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end

		local camPos = cam.CFrame.Position

		-- spawn higher up so it falls longer
		part.Position = camPos + Vector3.new(0, 50, 0)
	end)
end

local function removeSnow()
	if followConn then
		followConn:Disconnect()
		followConn = nil
	end

	if snowEmitter then
		snowEmitter.Enabled = false
		snowEmitter:Destroy()
		snowEmitter = nil
	end

	if snowPart then
		snowPart:Destroy()
		snowPart = nil
	end
end

------------------------------------------------------------
-- APPLY / REVERT
------------------------------------------------------------

local function applyWeather()
	if enabled then
		return
	end

	enabled = true

	if currentType == "Snow" then
		createSnow()
	end

	print("[Weather] enabled:", currentType)
end

local function revertWeather()
	if not enabled then
		return
	end

	enabled = false

	removeSnow()

	print("[Weather] disabled")
end

------------------------------------------------------------
-- TOGGLE BINDINGS
------------------------------------------------------------

local function onToggle(nextState: boolean)
	if nextState then
		applyWeather()
	else
		revertWeather()
	end
end

local function onTypeChanged(newType: string)
	currentType = newType

	if enabled then
		revertWeather()
		applyWeather()
	end
end

Toggles.Subscribe(TOGGLE_KEY, onToggle)
Toggles.SubscribeValue(VALUE_KEY, onTypeChanged)

-- auto-enable if already on
if Toggles.GetState(TOGGLE_KEY, false) then
	applyWeather()
end
