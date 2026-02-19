--!strict
-- NoFog.lua
-- Toggle key: "world_nofog"

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local function getGlobal(): any
	local gg = (typeof(getgenv) == "function") and getgenv() or nil
	if gg then
		return gg
	end
	return _G
end

local G = getGlobal()

local TOGGLE_KEY = "world_nofog"

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
	warn("[NoFog] Toggle API not found")
	return
end

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local enabled = false
local enforceConn: RBXScriptConnection? = nil

local originalFogStart = Lighting.FogStart
local originalFogEnd = Lighting.FogEnd
local originalFogColor = Lighting.FogColor

type AtmosBackup = {
	Atmos: Atmosphere,
	Density: number,
	Haze: number,
	Glare: number,
	Offset: number,
	Color: Color3,
	Decay: Color3,
}

local atmosBackups: {AtmosBackup} = {}

--------------------------------------------------------------------------------
-- SNAPSHOT
--------------------------------------------------------------------------------

local function snapshotAtmospheres()
	table.clear(atmosBackups)

	for _, inst in ipairs(Lighting:GetDescendants()) do
		if inst:IsA("Atmosphere") then
			table.insert(atmosBackups, {
				Atmos = inst,
				Density = inst.Density,
				Haze = inst.Haze,
				Glare = inst.Glare,
				Offset = inst.Offset,
				Color = inst.Color,
				Decay = inst.Decay,
			})
		end
	end
end

--------------------------------------------------------------------------------
-- ENFORCEMENT LOOP
--------------------------------------------------------------------------------

local function startEnforce()
	if enforceConn then return end

	enforceConn = RunService.RenderStepped:Connect(function()
		if not enabled then
			return
		end

		-- Fog correction (cheap comparisons)
		if Lighting.FogStart ~= 0 then
			Lighting.FogStart = 0
		end

		if Lighting.FogEnd < 1e8 then
			Lighting.FogEnd = 1e9
		end

		-- Atmosphere correction (lightweight)
		for _, inst in ipairs(Lighting:GetDescendants()) do
			if inst:IsA("Atmosphere") then
				if inst.Density ~= 0 then inst.Density = 0 end
				if inst.Haze ~= 0 then inst.Haze = 0 end
				if inst.Glare ~= 0 then inst.Glare = 0 end
			end
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

local function applyNoFog()
	if enabled then return end
	enabled = true

	originalFogStart = Lighting.FogStart
	originalFogEnd = Lighting.FogEnd
	originalFogColor = Lighting.FogColor

	snapshotAtmospheres()

	Lighting.FogStart = 0
	Lighting.FogEnd = 1e9

	for _, b in ipairs(atmosBackups) do
		local a = b.Atmos
		if a.Parent then
			a.Density = 0
			a.Haze = 0
			a.Glare = 0
		end
	end

	startEnforce()
	print("[NoFog] enabled")
end

local function revertNoFog()
	if not enabled then return end
	enabled = false

	stopEnforce()

	Lighting.FogStart = originalFogStart
	Lighting.FogEnd = originalFogEnd
	Lighting.FogColor = originalFogColor

	for _, b in ipairs(atmosBackups) do
		local a = b.Atmos
		if a.Parent then
			a.Density = b.Density
			a.Haze = b.Haze
			a.Glare = b.Glare
			a.Offset = b.Offset
			a.Color = b.Color
			a.Decay = b.Decay
		end
	end

	print("[NoFog] disabled")
end

--------------------------------------------------------------------------------
-- NEW ATMOSPHERE SAFETY
--------------------------------------------------------------------------------

Lighting.DescendantAdded:Connect(function(inst: Instance)
	if not enabled then return end
	if inst:IsA("Atmosphere") then
		inst.Density = 0
		inst.Haze = 0
		inst.Glare = 0
	end
end)

--------------------------------------------------------------------------------
-- TOGGLE BINDING
--------------------------------------------------------------------------------

local function onToggle(nextState: boolean)
	if nextState then
		applyNoFog()
	else
		revertNoFog()
	end
end

Toggles.Subscribe(TOGGLE_KEY, onToggle)

if Toggles.GetState(TOGGLE_KEY, false) then
	applyNoFog()
end
