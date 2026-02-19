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
	["Space Rocks"] = {
		SkyboxBk = "rbxassetid://16262356578",
		SkyboxDn = "rbxassetid://16262358026",
		SkyboxFt = "rbxassetid://16262360469",
		SkyboxLf = "rbxassetid://16262362003",
		SkyboxRt = "rbxassetid://16262363873",
		SkyboxUp = "rbxassetid://16262366016",
		CelestialBodiesShown = false,
	},

	["Red Planet"] = {
		SkyboxBk = "rbxassetid://11730840088",
		SkyboxDn = "rbxassetid://11730842997",
		SkyboxFt = "rbxassetid://11730849615",
		SkyboxLf = "rbxassetid://11730852920",
		SkyboxRt = "rbxassetid://11730855491",
		SkyboxUp = "rbxassetid://11730857150",
		CelestialBodiesShown = false,
	},

	["Cyan Space"] = {
		SkyboxBk = "rbxassetid://16876760844",
		SkyboxDn = "rbxassetid://16876762818",
		SkyboxFt = "rbxassetid://16876765234",
		SkyboxLf = "rbxassetid://16876767659",
		SkyboxRt = "rbxassetid://16876769447",
		SkyboxUp = "rbxassetid://16876771721",
		CelestialBodiesShown = false,
	},

	["Purple Space"] = {
		SkyboxBk = "rbxassetid://14543264135",
		SkyboxDn = "rbxassetid://14543358958",
		SkyboxFt = "rbxassetid://14543257810",
		SkyboxLf = "rbxassetid://14543275895",
		SkyboxRt = "rbxassetid://14543280890",
		SkyboxUp = "rbxassetid://14543371676",
		CelestialBodiesShown = true,
	},

	["Neon Planet"] = {
		SkyboxBk = "rbxassetid://16823386986",
		SkyboxDn = "rbxassetid://16823388586",
		SkyboxFt = "rbxassetid://16823390254",
		SkyboxLf = "rbxassetid://16823392344",
		SkyboxRt = "rbxassetid://16823394120",
		SkyboxUp = "rbxassetid://16823395515",
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
	local v = Toggles.GetValue(VALUE_KEY, "Space Rocks")
	if type(v) == "string" and v ~= "" then
		return v
	end

	local g = G.__HIGGI_SELECTED_SKYBOX
	if type(g) == "string" and g ~= "" then
		return g
	end

	return "Space Rocks"
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
