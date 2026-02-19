-- ClientSky.lua
-- Multi-preset skybox changer controlled by:
-- Toggle: world_skybox
-- Dropdown: world_skybox_dropdown

local Lighting = game:GetService("Lighting")

-- =========================
-- Global access + toggle api
-- =========================
local function getGlobal()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local G = getGlobal()

local function waitForTogglesApi(timeoutSeconds)
	local start = os.clock()
	while os.clock() - start < timeoutSeconds do
		local api = G.__HIGGI_TOGGLES_API
		if type(api) == "table"
		and type(api.GetState) == "function"
		and type(api.Subscribe) == "function"
		and type(api.GetValue) == "function"
		and type(api.SubscribeValue) == "function" then
			return api
		end
		task.wait(0.05)
	end
	return nil
end

local Toggles = waitForTogglesApi(6)
if not Toggles then
	warn("[ClientSky] Toggle API missing")
	return
end

-- prevent double-running and stacking listeners if script loads twice
G.__HIGGI_SKYBOX_STATE = G.__HIGGI_SKYBOX_STATE or {}

local State = G.__HIGGI_SKYBOX_STATE
if State.cleanup then
	pcall(State.cleanup)
	State.cleanup = nil
end

-- =========================
-- Keys (must match Menu.lua)
-- =========================
local TOGGLE_KEY = "world_skybox"
local VALUE_KEY = "world_skybox_dropdown"

-- =========================
-- Presets (placeholders)
-- =========================
-- Put whatever names you want (must match the dropdown options list)
-- Replace asset ids later.
local PRESETS = {
	["Neon Night"] = {
		SkyboxBk = "rbxassetid://11111111111",
		SkyboxDn = "rbxassetid://11111111112",
		SkyboxFt = "rbxassetid://11111111113",
		SkyboxLf = "rbxassetid://11111111114",
		SkyboxRt = "rbxassetid://11111111115",
		SkyboxUp = "rbxassetid://11111111116",
		SunAngularSize = 21,
		MoonAngularSize = 11,
		StarCount = 3000,
		CelestialBodiesShown = true,
	},

	["Pastel Clouds"] = {
		SkyboxBk = "rbxassetid://22222222221",
		SkyboxDn = "rbxassetid://22222222222",
		SkyboxFt = "rbxassetid://22222222223",
		SkyboxLf = "rbxassetid://22222222224",
		SkyboxRt = "rbxassetid://22222222225",
		SkyboxUp = "rbxassetid://22222222226",
		SunAngularSize = 18,
		MoonAngularSize = 10,
		StarCount = 1500,
		CelestialBodiesShown = true,
	},

	["Purple Dusk"] = {
		SkyboxBk = "rbxassetid://33333333331",
		SkyboxDn = "rbxassetid://33333333332",
		SkyboxFt = "rbxassetid://33333333333",
		SkyboxLf = "rbxassetid://33333333334",
		SkyboxRt = "rbxassetid://33333333335",
		SkyboxUp = "rbxassetid://33333333336",
		SunAngularSize = 20,
		MoonAngularSize = 12,
		StarCount = 4000,
		CelestialBodiesShown = true,
	},

	["Cyber Grid"] = {
		SkyboxBk = "rbxassetid://44444444441",
		SkyboxDn = "rbxassetid://44444444442",
		SkyboxFt = "rbxassetid://44444444443",
		SkyboxLf = "rbxassetid://44444444444",
		SkyboxRt = "rbxassetid://44444444445",
		SkyboxUp = "rbxassetid://44444444446",
		SunAngularSize = 16,
		MoonAngularSize = 9,
		StarCount = 0,
		CelestialBodiesShown = false,
	},
}

-- =========================
-- Original sky backup
-- =========================
local originalSkyClone = nil

local function captureOriginalSkyOnce()
	if originalSkyClone then
		return
	end

	local existing = Lighting:FindFirstChildOfClass("Sky")
	if existing then
		originalSkyClone = existing:Clone()
	end
end

local function destroyAnySkyNamedClientSky()
	local s = Lighting:FindFirstChild("ClientSky")
	if s and s:IsA("Sky") then
		s:Destroy()
	end
end

local function removeAllSkyInstances()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
end

-- =========================
-- Apply / Restore
-- =========================
local function applyPresetByName(name)
	local preset = PRESETS[name]
	if not preset then
		-- fallback to any preset if name is unknown
		for _, v in pairs(PRESETS) do
			preset = v
			break
		end
	end
	if not preset then
		return
	end

	captureOriginalSkyOnce()

	-- remove any existing sky (client-side)
	removeAllSkyInstances()

	local sky = Instance.new("Sky")
	sky.Name = "ClientSky"

	sky.SkyboxBk = preset.SkyboxBk
	sky.SkyboxDn = preset.SkyboxDn
	sky.SkyboxFt = preset.SkyboxFt
	sky.SkyboxLf = preset.SkyboxLf
	sky.SkyboxRt = preset.SkyboxRt
	sky.SkyboxUp = preset.SkyboxUp

	sky.SunAngularSize = preset.SunAngularSize or 21
	sky.MoonAngularSize = preset.MoonAngularSize or 11
	sky.StarCount = preset.StarCount or 3000
	sky.CelestialBodiesShown = (preset.CelestialBodiesShown ~= false)

	sky.Parent = Lighting
end

local function restoreOriginalSky()
	-- clear our sky first
	removeAllSkyInstances()

	if originalSkyClone then
		local restored = originalSkyClone:Clone()
		restored.Parent = Lighting
	else
		-- nothing to restore; just leave it empty
		destroyAnySkyNamedClientSky()
	end
end

-- =========================
-- Sync logic
-- =========================
local function getSelectedName()
	-- Prefer the value store (dropdown), but also accept the convenience global if you set it.
	local v = Toggles.GetValue(VALUE_KEY, "Neon Night")
	if type(v) == "string" and v ~= "" then
		return v
	end

	local g = G.__HIGGI_SELECTED_SKYBOX
	if type(g) == "string" and g ~= "" then
		return g
	end

	return "Neon Night"
end

local function applyIfEnabled()
	if Toggles.GetState(TOGGLE_KEY, false) then
		applyPresetByName(getSelectedName())
	end
end

local function onToggleChanged(state)
	if state then
		applyPresetByName(getSelectedName())
	else
		restoreOriginalSky()
	end
end

local function onDropdownChanged(_newValue)
	applyIfEnabled()
end

-- =========================
-- Subscriptions
-- =========================
local unsubToggle = Toggles.Subscribe(TOGGLE_KEY, onToggleChanged)
local unsubValue = Toggles.SubscribeValue(VALUE_KEY, onDropdownChanged)

State.cleanup = function()
	pcall(unsubToggle)
	pcall(unsubValue)
end

-- initial sync (in case toggle was already on)
if Toggles.GetState(TOGGLE_KEY, false) then
	applyPresetByName(getSelectedName())
end
