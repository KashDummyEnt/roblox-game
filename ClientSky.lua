local Lighting = game:GetService("Lighting")

-- Remove existing sky (client only)
local oldSky = Lighting:FindFirstChildOfClass("Sky")
if oldSky then
	oldSky:Destroy()
end

local sky = Instance.new("Sky")
sky.Name = "ClientSky"

sky.SkyboxBk = "rbxassetid://16823386986"
sky.SkyboxDn = "rbxassetid://16823388586"
sky.SkyboxFt = "rbxassetid://16823390254"
sky.SkyboxLf = "rbxassetid://16823392344"
sky.SkyboxRt = "rbxassetid://16823394120"
sky.SkyboxUp = "rbxassetid://16823395515"

sky.SunAngularSize = 21
sky.MoonAngularSize = 11
sky.StarCount = 3000
sky.CelestialBodiesShown = true

sky.Parent = Lighting
