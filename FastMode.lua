-- FastMode.lua
-- Disables world textures & decals for FPS boost
-- Controlled by toggle key: world_fastmode

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

-- =========================
-- Global toggle access
-- =========================
local function getGlobal()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local G = getGlobal()
local Toggles = G.__HIGGI_TOGGLES_API

if not Toggles then
	warn("FastMode: Toggle API missing")
	return
end

-- =========================
-- State
-- =========================
local savedTransparency = {}
local savedMaterials = {}
local savedLighting = {}

local function disableTextures()
	for _, inst in ipairs(workspace:GetDescendants()) do
		
		-- Disable decals
		if inst:IsA("Decal") then
			if savedTransparency[inst] == nil then
				savedTransparency[inst] = inst.Transparency
			end
			inst.Transparency = 1
		
		-- Disable textures
		elseif inst:IsA("Texture") then
			if savedTransparency[inst] == nil then
				savedTransparency[inst] = inst.Transparency
			end
			inst.Transparency = 1
		
		-- Flatten materials
		elseif inst:IsA("BasePart") then
			if savedMaterials[inst] == nil then
				savedMaterials[inst] = inst.Material
			end
			inst.Material = Enum.Material.SmoothPlastic
		end
	end

	-- Optional lighting optimization
	if savedLighting.GlobalShadows == nil then
		savedLighting.GlobalShadows = Lighting.GlobalShadows
	end
	Lighting.GlobalShadows = false
end

local function restoreTextures()
	for inst, value in pairs(savedTransparency) do
		if inst and inst.Parent then
			inst.Transparency = value
		end
	end

	for inst, material in pairs(savedMaterials) do
		if inst and inst.Parent then
			inst.Material = material
		end
	end

	if savedLighting.GlobalShadows ~= nil then
		Lighting.GlobalShadows = savedLighting.GlobalShadows
	end

	savedTransparency = {}
	savedMaterials = {}
	savedLighting = {}
end

-- =========================
-- Subscribe to toggle
-- =========================
Toggles.Subscribe("world_fastmode", function(state: boolean)
	if state then
		disableTextures()
	else
		restoreTextures()
	end
end)
