--!strict
-- Fullbright.lua
-- Toggle key: "world_fullbright"

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local function getGlobal()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local G = getGlobal()

local Store = G.__HIGGI_TOGGLES
if not Store then
	warn("Fullbright: Toggle store missing")
	return
end

G.__HIGGI_FULLBRIGHT = G.__HIGGI_FULLBRIGHT or {}
local FB = G.__HIGGI_FULLBRIGHT
if FB.Loaded then
	return
end
FB.Loaded = true

local KEY = "world_fullbright"

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local enabled = false
local enforceConn: RBXScriptConnection? = nil

local original = {
	Has = false,
	Brightness = nil :: number?,
	ClockTime = nil :: number?,
	GlobalShadows = nil :: boolean?,
	Ambient = nil :: Color3?,
	OutdoorAmbient = nil :: Color3?,
}

--------------------------------------------------------------------------------
-- CAPTURE
--------------------------------------------------------------------------------

local function captureOriginal()
	if original.Has then return end

	original.Has = true
	original.Brightness = Lighting.Brightness
	original.ClockTime = Lighting.ClockTime
	original.GlobalShadows = Lighting.GlobalShadows
	original.Ambient = Lighting.Ambient
	original.OutdoorAmbient = Lighting.OutdoorAmbient
end

--------------------------------------------------------------------------------
-- ENFORCE
--------------------------------------------------------------------------------

local function startEnforce()
	if enforceConn then return end

	enforceConn = RunService.RenderStepped:Connect(function()
		if not enabled then return end

		if Lighting.Brightness ~= 3 then
			Lighting.Brightness = 3
		end

		if Lighting.ClockTime ~= 14 then
			Lighting.ClockTime = 14
		end

		if Lighting.GlobalShadows ~= false then
			Lighting.GlobalShadows = false
		end

		local white = Color3.fromRGB(255, 255, 255)

		if Lighting.Ambient ~= white then
			Lighting.Ambient = white
		end

		if Lighting.OutdoorAmbient ~= white then
			Lighting.OutdoorAmbient = white
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

local function applyOn()
	if enabled then return end
	enabled = true

	captureOriginal()

	Lighting.Brightness = 3
	Lighting.ClockTime = 14
	Lighting.GlobalShadows = false
	Lighting.Ambient = Color3.fromRGB(255, 255, 255)
	Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)

	startEnforce()
end

local function applyOff()
	if not enabled then return end
	enabled = false

	stopEnforce()

	if not original.Has then return end

	Lighting.Brightness = original.Brightness
	Lighting.ClockTime = original.ClockTime
	Lighting.GlobalShadows = original.GlobalShadows
	Lighting.Ambient = original.Ambient
	Lighting.OutdoorAmbient = original.OutdoorAmbient
end

--------------------------------------------------------------------------------
-- TOGGLE
--------------------------------------------------------------------------------

local function setEnabled(state: boolean)
	if state then
		applyOn()
	else
		applyOff()
	end
end

if type(G.__HIGGI_TOGGLES_API) == "table"
and type(G.__HIGGI_TOGGLES_API.Subscribe) == "function" then
	G.__HIGGI_TOGGLES_API.Subscribe(KEY, function(state)
		setEnabled(state)
	end)
end

local current = Store.states[KEY]
setEnabled(current and true or false)
