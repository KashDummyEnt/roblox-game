--!strict
-- PlayerSpeed.lua
-- Toggle key: "misc_speed"

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function getGlobal(): any
	local gg = (typeof(getgenv) == "function") and getgenv() or nil
	if gg then
		return gg
	end
	return _G
end

local G = getGlobal()

local TOGGLE_KEY = "misc_speed"
local SPEED_VALUE = 80 -- change this to whatever you want

--------------------------------------------------------------------------------
-- WAIT FOR TOGGLES API
--------------------------------------------------------------------------------

local function waitForTogglesApi(timeoutSeconds: number): any?
	local start = os.clock()
	while os.clock() - start < timeoutSeconds do
		local api = G.__HIGGI_TOGGLES_API
		if type(api) == "table" then
			if type(api.GetState) == "function" and type(api.Subscribe) == "function" then
				return api
			end
		end
		task.wait(0.05)
	end
	return nil
end

local Toggles = waitForTogglesApi(6)
if not Toggles then
	warn("[PlayerSpeed] Toggle API not found")
	return
end

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local enabled = false
local originalSpeed = 16
local enforceConn: RBXScriptConnection? = nil

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function getHumanoid(): Humanoid?
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

local function startEnforce()
	if enforceConn then return end

	enforceConn = game:GetService("RunService").RenderStepped:Connect(function()
		if not enabled then return end

		local hum = getHumanoid()
		if hum and hum.WalkSpeed ~= SPEED_VALUE then
			hum.WalkSpeed = SPEED_VALUE
		end
	end)
end

local function stopEnforce()
	if enforceConn then
		enforceConn:Disconnect()
		enforceConn = nil
	end
end

--------------------------------------------------------------------------------
-- APPLY / REVERT
--------------------------------------------------------------------------------

local function applySpeed()
	if enabled then return end
	enabled = true

	local hum = getHumanoid()
	if hum then
		originalSpeed = hum.WalkSpeed
		hum.WalkSpeed = SPEED_VALUE
	end

	startEnforce()
	print("[PlayerSpeed] enabled")
end

local function revertSpeed()
	if not enabled then return end
	enabled = false

	stopEnforce()

	local hum = getHumanoid()
	if hum then
		hum.WalkSpeed = originalSpeed
	end

	print("[PlayerSpeed] disabled")
end

--------------------------------------------------------------------------------
-- RESPAWN SAFETY
--------------------------------------------------------------------------------

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	if enabled then
		applySpeed()
	end
end)

--------------------------------------------------------------------------------
-- TOGGLE BINDING
--------------------------------------------------------------------------------

local function onToggle(nextState: boolean)
	if nextState then
		applySpeed()
	else
		revertSpeed()
	end
end

Toggles.Subscribe(TOGGLE_KEY, onToggle)

if Toggles.GetState(TOGGLE_KEY, false) then
	applySpeed()
end
