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
-- SNOW (REALISTIC CEILING METHOD)
------------------------------------------------------------

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

	-- WIND (constant sideways drift)
	local windX = math.random(-2, 2)
	local windZ = math.random(-2, 2)

	--------------------------------------------------------
	-- SMALL FLAKES (base layer)
	--------------------------------------------------------

	local small = Instance.new("ParticleEmitter")
	small.Texture = "rbxassetid://118641183"

	small.Rate = 2000
	small.Lifetime = NumberRange.new(12, 18)
	small.Speed = NumberRange.new(0.5, 1.5)

	small.Size = NumberSequence.new(0.2)

	small.EmissionDirection = Enum.NormalId.Bottom
	small.VelocitySpread = 180

	small.Acceleration = Vector3.new(windX, -1.5, windZ)

	small.Rotation = NumberRange.new(0, 360)
	small.RotSpeed = NumberRange.new(-25, 25)

	small.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})

	small.Parent = part

	--------------------------------------------------------
	-- MEDIUM FLAKES (depth layer)
	--------------------------------------------------------

	local medium = Instance.new("ParticleEmitter")
	medium.Texture = "rbxassetid://118641183"

	medium.Rate = 600
	medium.Lifetime = NumberRange.new(14, 20)
	medium.Speed = NumberRange.new(0.3, 1)

	medium.Size = NumberSequence.new(0.35)

	medium.EmissionDirection = Enum.NormalId.Bottom
	medium.VelocitySpread = 180

	medium.Acceleration = Vector3.new(windX * 1.2, -1.2, windZ * 1.2)

	medium.Rotation = NumberRange.new(0, 360)
	medium.RotSpeed = NumberRange.new(-30, 30)

	medium.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})

	medium.Parent = part

	snowPart = part

	followConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end

		part.Position = cam.CFrame.Position + Vector3.new(0, 70, 0)
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
