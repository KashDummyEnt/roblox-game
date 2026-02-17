--!strict
-- NoFog.lua
-- Requires Menu.lua to have already loaded ToggleSwitches.lua and set:
-- getgenv().__HIGGI_TOGGLES_API = TogglesTable
--
-- Toggle key expected: "world_nofog"

local Lighting = game:GetService("Lighting")

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
			-- minimal surface we expect
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
	warn("[NoFog] Toggle API not found (did Menu.lua run first?)")
	return
end

--////////////////////////////////////////////////////////////////////////////////
-- State capture + apply/revert
--////////////////////////////////////////////////////////////////////////////////

local enabled = false

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

local function applyNoFog()
	if enabled then
		return
	end
	enabled = true

	-- capture current (in case something changed after initial load)
	originalFogStart = Lighting.FogStart
	originalFogEnd = Lighting.FogEnd
	originalFogColor = Lighting.FogColor
	snapshotAtmospheres()

	-- basically “fog off”
	Lighting.FogStart = 0
	Lighting.FogEnd = 1e9

	-- keep fog color as-is (some games use it for vibe). if you want, you can force:
	-- Lighting.FogColor = Color3.fromRGB(255, 255, 255)

	-- Atmosphere can still haze you even with FogEnd huge, so dial it down
	for _, b in ipairs(atmosBackups) do
		local a = b.Atmos
		if a.Parent then
			a.Density = 0
			a.Haze = 0
			a.Glare = 0
		end
	end

	print("[NoFog] enabled")
end

local function revertNoFog()
	if not enabled then
		return
	end
	enabled = false

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

-- If atmospheres get added later while enabled, clamp them too
Lighting.DescendantAdded:Connect(function(inst: Instance)
	if not enabled then
		return
	end
	if inst:IsA("Atmosphere") then
		-- newly added atmosphere should also get killed
		inst.Density = 0
		inst.Haze = 0
		inst.Glare = 0
	end
end)

--////////////////////////////////////////////////////////////////////////////////
-- Toggle wiring
--////////////////////////////////////////////////////////////////////////////////

local function onToggle(nextState: boolean)
	if nextState then
		applyNoFog()
	else
		revertNoFog()
	end
end

-- subscribe to future changes
Toggles.Subscribe(TOGGLE_KEY, onToggle)

-- apply current state if already ON
if Toggles.GetState(TOGGLE_KEY, false) then
	applyNoFog()
else
	-- stay idle until user turns it on
	print("[NoFog] waiting (toggle is OFF)")
end
