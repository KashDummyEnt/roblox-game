--!strict
-- features/NoFog.lua
-- Returns a controller table (local-only)

local Lighting = game:GetService("Lighting")

local saved = {
	FogStart = Lighting.FogStart,
	FogEnd = Lighting.FogEnd,
	FogColor = Lighting.FogColor,
}

local controller = {
	IsEnabled = false,
}

function controller.Enable()
	-- Refresh saved values each time in case something else changed them
	saved.FogStart = Lighting.FogStart
	saved.FogEnd = Lighting.FogEnd
	saved.FogColor = Lighting.FogColor

	Lighting.FogStart = 0
	Lighting.FogEnd = 1e6
end

function controller.Disable()
	Lighting.FogStart = saved.FogStart
	Lighting.FogEnd = saved.FogEnd
	Lighting.FogColor = saved.FogColor
end

function controller.Destroy()
	-- Optional cleanup if you ever want to fully unload
	if controller.IsEnabled then
		controller.Disable()
	end
end

return controller
