--!strict
-- NoFog.lua (local-only controller)

local Lighting = game:GetService("Lighting")

local function getAtmosphere(): Atmosphere?
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("Atmosphere") then
			return c
		end
	end
	return nil
end

local saved = {
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
	FogColor = Lighting.FogColor,

	HasAtmosphere = false,
	AtmosDensity = 0,
	AtmosHaze = 0,
	AtmosGlare = 0,
}

local controller = {
	IsEnabled = false,
}

function controller.Enable()
	-- snapshot current values each time
	saved.FogStart = Lighting.FogStart
	saved.FogEnd = Lighting.FogEnd
	saved.FogColor = Lighting.FogColor

	local atm = getAtmosphere()
	saved.HasAtmosphere = atm ~= nil
	if atm then
		saved.AtmosDensity = atm.Density
		saved.AtmosHaze = atm.Haze
		saved.AtmosGlare = atm.Glare
	end

	Lighting.FogStart = 0
	Lighting.FogEnd = 1e6

	if atm then
		atm.Density = 0
		atm.Haze = 0
		atm.Glare = 0
	end

	print("[NoFog] Enabled")
end

function controller.Disable()
	Lighting.FogStart = saved.FogStart
	Lighting.FogEnd = saved.FogEnd
	Lighting.FogColor = saved.FogColor

	local atm = getAtmosphere()
	if atm and saved.HasAtmosphere then
		atm.Density = saved.AtmosDensity
		atm.Haze = saved.AtmosHaze
		atm.Glare = saved.AtmosGlare
	end

	print("[NoFog] Disabled")
end

function controller.Destroy()
	if controller.IsEnabled then
		controller.Disable()
	end
end

return controller
