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

local snowPart: Part? = nil
local followConn: RBXScriptConnection? = nil

------------------------------------------------------------
-- SNOW (NO WIND, LAYERED)
------------------------------------------------------------

local function createEmitter(parent: Instance, rate: number, sizeMin: number, sizeMax: number)
	local emitter = Instance.new("ParticleEmitter")

	emitter.Texture = "rbxassetid://118641183"

	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(12, 16)

	-- Very slow initial downward motion
	emitter.Speed = NumberRange.new(0.5, 1.2)

	-- Emit straight down
	emitter.EmissionDirection = Enum.NormalId.Bottom

	-- Slight size variation
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, sizeMin),
		NumberSequenceKeypoint.new(1, sizeMax),
	})

	-- Straight downward gravity only
	emitter.Acceleration = Vector3.new(0, -1.5, 0)

	emitter.VelocitySpread = 180

	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-10, 10)

	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})

	emitter.Parent = parent
end

local function createSnow()
	if snowPart then
		return
	end

	local part = Instance.new("Part")
	part.Name = "LocalSnowCeiling"

	part.Size = Vector3.new(350, 1, 350)

	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.CastShadow = false
	part.Parent = workspace

	-- Small flakes (main density)
	createEmitter(part, 1400, 0.15, 0.2)

	-- Medium flakes
	createEmitter(part, 500, 0.22, 0.3)

	-- Larger occasional flakes
	createEmitter(part, 150, 0.32, 0.4)

	snowPart = part

	followConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end

		part.Position = cam.CFrame.Position + Vector3.new(0, 60, 0)
	end)
end

local function removeSnow()
	if followConn then
		followConn:Disconnect()
		followConn = nil
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
	if enabled then return end
	enabled = true

	if currentType == "Snow" then
		createSnow()
	end
end

local function revertWeather()
	if not enabled then return end
	enabled = false
	removeSnow()
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

if Toggles.GetState(TOGGLE_KEY, false) then
	applyWeather()
end
