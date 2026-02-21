--!strict
-- Weather.lua
-- Toggle key: "world_weather"
-- Value key:  "world_weather_type"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

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
-- Wait for toggle API (same pattern as NoFog)
------------------------------------------------------------
local function waitForTogglesApi(timeoutSeconds: number): any?
	local start = os.clock()
	while os.clock() - start < timeoutSeconds do
		local api = G.__HIGGI_TOGGLES_API
		if type(api) == "table" then
			if type(api.GetState) == "function"
			and type(api.Subscribe) == "function"
			and type(api.SubscribeValue) == "function" then
				return api
			end
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

local snowEmitter: ParticleEmitter? = nil
local snowAttachment: Attachment? = nil

------------------------------------------------------------
-- Snow Creation
------------------------------------------------------------
local function createSnow()
	if snowEmitter then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	snowAttachment = Instance.new("Attachment")
	snowAttachment.Name = "SnowAttachment"
	snowAttachment.Parent = hrp

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SnowEmitter"
	emitter.Texture = "rbxassetid://284205403" -- simple snow dot
	emitter.Rate = 150
	emitter.Lifetime = NumberRange.new(4, 6)
	emitter.Speed = NumberRange.new(8, 12)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-20, 20)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Acceleration = Vector3.new(0, -2, 0)
	emitter.VelocitySpread = 180
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = snowAttachment

	snowEmitter = emitter
end

local function removeSnow()
	if snowEmitter then
		snowEmitter.Enabled = false
		snowEmitter:Destroy()
		snowEmitter = nil
	end

	if snowAttachment then
		snowAttachment:Destroy()
		snowAttachment = nil
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

	print("[Weather] enabled:", currentType)
end

local function revertWeather()
	if not enabled then return end
	enabled = false

	removeSnow()

	print("[Weather] disabled")
end

------------------------------------------------------------
-- Toggle + Value Binding
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

-- if already enabled
if Toggles.GetState(TOGGLE_KEY, false) then
	applyWeather()
end
