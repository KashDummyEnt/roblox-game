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
-- SNOW (NO WIND, HEAVY LAYERED, SPEED = 1)
------------------------------------------------------------

local function createEmitter(parent: Instance, rate: number, sizeMin: number, sizeMax: number, lifetimeMin: number, lifetimeMax: number)
	local emitter = Instance.new("ParticleEmitter")

	emitter.Texture = "rbxassetid://118641183"

	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(lifetimeMin, lifetimeMax)

	-- LOCKED SPEED
	emitter.Speed = NumberRange.new(1, 1)

	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.VelocitySpread = 180

	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, sizeMin),
		NumberSequenceKeypoint.new(1, sizeMax),
	})

	emitter.Acceleration = Vector3.new(0, -1.2, 0)

	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-8, 8)

emitter.Transparency = NumberSequence.new(0.05)

	emitter.Parent = parent
end

local function createSnow()
	if snowPart then
		return
	end

	local part = Instance.new("Part")
	part.Name = "LocalSnowCeiling"

	part.Size = Vector3.new(500, 1, 500) -- bigger coverage
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.CastShadow = false
	part.Parent = workspace

	-- Layer 1 (micro flakes, heavy density)
	createEmitter(part, 1800, 0.12, 0.18, 6, 9)

	-- Layer 2 (small flakes)
	createEmitter(part, 2500, 0.18, 0.24, 7, 10)

	-- Layer 3 (medium flakes)
	createEmitter(part, 1500, 0.25, 0.32, 8, 12)

	-- Layer 4 (bigger flakes)
	createEmitter(part, 650, 0.35, 0.45, 9, 14)

	-- Layer 5 (rare chunky flakes)
	createEmitter(part, 240, 0.5, 0.65, 10, 15)

	snowPart = part

	followConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end

		part.Position = cam.CFrame.Position + Vector3.new(0, 45, 0)
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
