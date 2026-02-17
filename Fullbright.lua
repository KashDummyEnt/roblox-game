-- Fullbright.lua (REMOTE FEATURE SCRIPT)
-- Reads shared toggle state + keeps itself synced.

local function getGlobal()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local G = getGlobal()
local Store = G.__HIGGI_TOGGLES
if not Store then
	warn("Fullbright: Toggle store missing (ToggleSwitches not loaded yet)")
	return
end

local Lighting = game:GetService("Lighting")

-- prevent double-load
G.__HIGGI_FULLBRIGHT = G.__HIGGI_FULLBRIGHT or {}
local FB = G.__HIGGI_FULLBRIGHT
if FB.Loaded then
	return
end
FB.Loaded = true

local KEY = "world_fullbright"

local original = {
	Has = false,
	Brightness = nil,
	ClockTime = nil,
	FogEnd = nil,
	GlobalShadows = nil,
	Ambient = nil,
	OutdoorAmbient = nil,
}

local function captureOriginal()
	if original.Has then
		return
	end
	original.Has = true
	original.Brightness = Lighting.Brightness
	original.ClockTime = Lighting.ClockTime
	original.FogEnd = Lighting.FogEnd
	original.GlobalShadows = Lighting.GlobalShadows
	original.Ambient = Lighting.Ambient
	original.OutdoorAmbient = Lighting.OutdoorAmbient
end

local function applyOn()
	captureOriginal()
	Lighting.Brightness = 3
	Lighting.ClockTime = 14
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = false
	Lighting.Ambient = Color3.fromRGB(255, 255, 255)
	Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
end

local function applyOff()
	if not original.Has then
		return
	end
	Lighting.Brightness = original.Brightness
	Lighting.ClockTime = original.ClockTime
	Lighting.FogEnd = original.FogEnd
	Lighting.GlobalShadows = original.GlobalShadows
	Lighting.Ambient = original.Ambient
	Lighting.OutdoorAmbient = original.OutdoorAmbient
end

local function setEnabled(state)
	if state then
		applyOn()
	else
		applyOff()
	end
end

-- if your ToggleSwitches module is loaded, it provides Subscribe.
-- If not, we still handle current state once.
if type(G.__HIGGI_TOGGLES_API) == "table" and type(G.__HIGGI_TOGGLES_API.Subscribe) == "function" then
	local unsub = G.__HIGGI_TOGGLES_API.Subscribe(KEY, function(state)
		setEnabled(state)
	end)
	FB.Unsub = unsub
end

-- Always apply current state on load
local current = Store.states[KEY]
setEnabled(current and true or false)
