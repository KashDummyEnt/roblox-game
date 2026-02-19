-- ClientSky.lua
-- Multi-preset skybox changer controlled by:
-- Toggle: world_skybox
-- Dropdown: world_skybox_dropdown
--
-- Each preset has its own ClockTime + SkyboxOrientation.
-- ClockTime + SkyboxOrientation are enforced every frame while enabled so the server can't override them.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

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
-- Presets (each has its own time + orientation)
-- =========================
local PRESETS = {
	["Space Rocks"] = {
		SkyboxBk = "rbxassetid://16262356578",
		SkyboxDn = "rbxassetid://16262358026",
		SkyboxFt = "rbxassetid://16262360469",
		SkyboxLf = "rbxassetid://16262362003",
		SkyboxRt = "rbxassetid://16262363873",
		SkyboxUp = "rbxassetid://16262366016",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Red Planet"] = {
		SkyboxBk = "rbxassetid://11730840088",
		SkyboxDn = "rbxassetid://11730842997",
		SkyboxFt = "rbxassetid://11730849615",
		SkyboxLf = "rbxassetid://11730852920",
		SkyboxRt = "rbxassetid://11730855491",
		SkyboxUp = "rbxassetid://11730857150",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Cyan Space"] = {
		SkyboxBk = "rbxassetid://16876760844",
		SkyboxDn = "rbxassetid://16876762818",
		SkyboxFt = "rbxassetid://16876765234",
		SkyboxLf = "rbxassetid://16876767659",
		SkyboxRt = "rbxassetid://16876769447",
		SkyboxUp = "rbxassetid://16876771721",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Purple Space"] = {
		SkyboxBk = "rbxassetid://14543264135",
		SkyboxDn = "rbxassetid://14543358958",
		SkyboxFt = "rbxassetid://14543257810",
		SkyboxLf = "rbxassetid://14543275895",
		SkyboxRt = "rbxassetid://14543280890",
		SkyboxUp = "rbxassetid://14543371676",
		CelestialBodiesShown = true,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Cyan Planet"] = {
		SkyboxBk = "rbxassetid://16823386986",
		SkyboxDn = "rbxassetid://16823388586",
		SkyboxFt = "rbxassetid://16823390254",
		SkyboxLf = "rbxassetid://16823392344",
		SkyboxRt = "rbxassetid://16823394120",
		SkyboxUp = "rbxassetid://16823395515",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Neon Borealis"] = {
		SkyboxBk = "rbxassetid://5260808177",
		SkyboxDn = "rbxassetid://5260653793",
		SkyboxFt = "rbxassetid://5260817288",
		SkyboxLf = "rbxassetid://5260800833",
		SkyboxRt = "rbxassetid://5260811073",
		SkyboxUp = "rbxassetid://5260824661",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Sunset"] = {
		SkyboxBk = "rbxassetid://151165214",
		SkyboxDn = "rbxassetid://151165197",
		SkyboxFt = "rbxassetid://151165224",
		SkyboxLf = "rbxassetid://151165191",
		SkyboxRt = "rbxassetid://151165206",
		SkyboxUp = "rbxassetid://151165227",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Aurora"] = {
		SkyboxBk = "rbxassetid://340908398",
		SkyboxDn = "rbxassetid://340908450",
		SkyboxFt = "rbxassetid://340908468",
		SkyboxLf = "rbxassetid://340908504",
		SkyboxRt = "rbxassetid://340908530",
		SkyboxUp = "rbxassetid://340908586",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Error"] = {
		SkyboxBk = "rbxassetid://13710453307",
		SkyboxDn = "rbxassetid://13710575997",
		SkyboxFt = "rbxassetid://13710453307",
		SkyboxLf = "rbxassetid://13710453307",
		SkyboxRt = "rbxassetid://13710453307",
		SkyboxUp = "rbxassetid://13710678849",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Dreamy"] = {
		SkyboxBk = "rbxassetid://16642371727",
		SkyboxDn = "rbxassetid://16642373510",
		SkyboxFt = "rbxassetid://16642374596",
		SkyboxLf = "rbxassetid://16642375956",
		SkyboxRt = "rbxassetid://16642377351",
		SkyboxUp = "rbxassetid://16642379025",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Emerald Borealis"] = {
		SkyboxBk = "rbxassetid://16563478983",
		SkyboxDn = "rbxassetid://16563481302",
		SkyboxFt = "rbxassetid://16563484084",
		SkyboxLf = "rbxassetid://16563485362",
		SkyboxRt = "rbxassetid://16563487078",
		SkyboxUp = "rbxassetid://16563489821",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["War"] = {
		SkyboxBk = "rbxassetid://1012890",
		SkyboxDn = "rbxassetid://1012891",
		SkyboxFt = "rbxassetid://1012887",
		SkyboxLf = "rbxassetid://1012889",
		SkyboxRt = "rbxassetid://1012888",
		SkyboxUp = "rbxassetid://1014449",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Nuke"] = {
		SkyboxBk = "rbxassetid://435049698",
		SkyboxDn = "rbxassetid://435037324",
		SkyboxFt = "rbxassetid://435050854",
		SkyboxLf = "rbxassetid://435034621",
		SkyboxRt = "rbxassetid://435034046",
		SkyboxUp = "rbxassetid://435051914",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Storm"] = {
		SkyboxBk = "rbxassetid://255027929",
		SkyboxDn = "rbxassetid://255027967",
		SkyboxFt = "rbxassetid://255027923",
		SkyboxLf = "rbxassetid://255027938",
		SkyboxRt = "rbxassetid://255027946",
		SkyboxUp = "rbxassetid://255027960",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Violet Moon"] = {
		SkyboxBk = "rbxassetid://17839210699",
		SkyboxDn = "rbxassetid://17839215896",
		SkyboxFt = "rbxassetid://17839218166",
		SkyboxLf = "rbxassetid://17839220800",
		SkyboxRt = "rbxassetid://17839223605",
		SkyboxUp = "rbxassetid://17839226876",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Toon Moon"] = {
		SkyboxBk = "rbxassetid://16676744885",
		SkyboxDn = "rbxassetid://16676747356",
		SkyboxFt = "rbxassetid://16676750819",
		SkyboxLf = "rbxassetid://16676754379",
		SkyboxRt = "rbxassetid://16676757270",
		SkyboxUp = "rbxassetid://16676760882",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Red Moon"] = {
		SkyboxBk = "rbxassetid://401664839",
		SkyboxDn = "rbxassetid://401664862",
		SkyboxFt = "rbxassetid://401664960",
		SkyboxLf = "rbxassetid://401664881",
		SkyboxRt = "rbxassetid://401664901",
		SkyboxUp = "rbxassetid://401664936",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Crimson Despair"] = {
		SkyboxBk = "rbxassetid://18705029692",
		SkyboxDn = "rbxassetid://18705031833",
		SkyboxFt = "rbxassetid://18705034432",
		SkyboxLf = "rbxassetid://18705037452",
		SkyboxRt = "rbxassetid://18705041280",
		SkyboxUp = "rbxassetid://18705044890",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Corrupted"] = {
		SkyboxBk = "rbxassetid://75147627948681",
		SkyboxDn = "rbxassetid://79112811930261",
		SkyboxFt = "rbxassetid://100726299880961",
		SkyboxLf = "rbxassetid://94672505047452",
		SkyboxRt = "rbxassetid://103152999464233",
		SkyboxUp = "rbxassetid://136002803290873",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Dark Matter"] = {
		SkyboxBk = "rbxassetid://97629693450922",
		SkyboxDn = "rbxassetid://97898396690232",
		SkyboxFt = "rbxassetid://134755033418084",
		SkyboxLf = "rbxassetid://118219143707956",
		SkyboxRt = "rbxassetid://114940065588775",
		SkyboxUp = "rbxassetid://95430908943263",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

	["Molten"] = {
		SkyboxBk = "rbxassetid://131463907527649",
		SkyboxDn = "rbxassetid://116154164311420",
		SkyboxFt = "rbxassetid://113077689016278",
		SkyboxLf = "rbxassetid://79984367513909",
		SkyboxRt = "rbxassetid://82395195737484",
		SkyboxUp = "rbxassetid://117530106700350",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

		["Ghost"] = {
		SkyboxBk = "rbxassetid://131463907527649",
		SkyboxDn = "rbxassetid://116154164311420",
		SkyboxFt = "rbxassetid://113077689016278",
		SkyboxLf = "rbxassetid://79984367513909",
		SkyboxRt = "rbxassetid://82395195737484",
		SkyboxUp = "rbxassetid://117530106700350",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

		["Battlerock"] = {
		SkyboxBk = "rbxassetid://131136284306917",
		SkyboxDn = "rbxassetid://89505977207531",
		SkyboxFt = "rbxassetid://140099243548102",
		SkyboxLf = "rbxassetid://121676169821100",
		SkyboxRt = "rbxassetid://97183886241447",
		SkyboxUp = "rbxassetid://107128620201556",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, 0),
	},

		["Stellar"] = {
		SkyboxBk = "rbxassetid://107264897520277",
		SkyboxDn = "rbxassetid://135637946277638",
		SkyboxFt = "rbxassetid://135705252786048",
		SkyboxLf = "rbxassetid://119667604517747",
		SkyboxRt = "rbxassetid://75904303027092",
		SkyboxUp = "rbxassetid://97011146822716",
		CelestialBodiesShown = false,
		ClockTime = 14.5,
		SkyboxOrientation = Vector3.new(0, 0, -90),
	},
}

-- =========================
-- Original sky + time backup
-- =========================
local originalSkyClone = nil
local originalClockTime: number? = nil

local function captureOriginalStateOnce()
	if originalSkyClone or originalClockTime ~= nil then
		return
	end

	originalClockTime = Lighting.ClockTime

	local existing = Lighting:FindFirstChildOfClass("Sky")
	if existing then
		originalSkyClone = existing:Clone()
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
-- ClockTime + SkyboxOrientation enforcement (anti override)
-- =========================
local enforceConn: RBXScriptConnection? = nil
local enforcedClockTime: number? = nil
local enforcedOrientation: Vector3? = nil

local function stopEnforce()
	enforcedClockTime = nil
	enforcedOrientation = nil
	if enforceConn then
		enforceConn:Disconnect()
		enforceConn = nil
	end
end

local function startEnforce(clockTime: number, orientation: Vector3)
	enforcedClockTime = clockTime
	enforcedOrientation = orientation
	if enforceConn then
		return
	end

	enforceConn = RunService.RenderStepped:Connect(function()
		if enforcedClockTime ~= nil and Lighting.ClockTime ~= enforcedClockTime then
			Lighting.ClockTime = enforcedClockTime
		end

		local sky = Lighting:FindFirstChild("ClientSky")
		if sky and sky:IsA("Sky") and enforcedOrientation ~= nil then
			if sky.SkyboxOrientation ~= enforcedOrientation then
				sky.SkyboxOrientation = enforcedOrientation
			end
		end
	end)
end

-- =========================
-- Apply / Restore
-- =========================
local function applyPresetByName(name)
	local preset = PRESETS[name]

	if not preset then
		for _, v in pairs(PRESETS) do
			preset = v
			break
		end
	end

	if not preset then
		return
	end

	captureOriginalStateOnce()

	local targetTime = preset.ClockTime or 14.5
	local targetOri = preset.SkyboxOrientation or Vector3.new(0, 0, 0)

	startEnforce(targetTime, targetOri)
	Lighting.ClockTime = targetTime

	removeAllSkyInstances()

	local sky = Instance.new("Sky")
	sky.Name = "ClientSky"

	sky.SkyboxBk = preset.SkyboxBk
	sky.SkyboxDn = preset.SkyboxDn
	sky.SkyboxFt = preset.SkyboxFt
	sky.SkyboxLf = preset.SkyboxLf
	sky.SkyboxRt = preset.SkyboxRt
	sky.SkyboxUp = preset.SkyboxUp

	sky.SunAngularSize = 21
	sky.MoonAngularSize = 11
	sky.StarCount = 3000
	sky.CelestialBodiesShown = (preset.CelestialBodiesShown ~= false)

	sky.SkyboxOrientation = targetOri

	sky.Parent = Lighting
end

local function restoreOriginalState()
	stopEnforce()
	removeAllSkyInstances()

	if originalSkyClone then
		local restored = originalSkyClone:Clone()
		restored.Parent = Lighting
	end

	if originalClockTime ~= nil then
		Lighting.ClockTime = originalClockTime
	end
end

-- =========================
-- Sync logic
-- =========================
local function getSelectedName()
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
		restoreOriginalState()
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
	pcall(stopEnforce)
end

-- Initial sync
if Toggles.GetState(TOGGLE_KEY, false) then
	applyPresetByName(getSelectedName())
end
