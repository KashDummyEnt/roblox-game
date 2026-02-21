--!strict
-- Rage.lua
-- Stable Delta-Based Rage Aimbot (Menu Smoothing Compatible)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

----------------------------------------------------
-- DEFAULTS (overwritten by menu)
----------------------------------------------------

local fov = 120
local smoothness = 0.18

----------------------------------------------------
-- GLOBAL TOGGLE ACCESS
----------------------------------------------------

local function getGlobal(): any
	local gg = (typeof(getgenv) == "function") and getgenv() or nil
	if gg then return gg end
	return _G
end

local G = getGlobal()

local function waitForTogglesApi(timeout: number): any?
	local start = os.clock()
	while os.clock() - start < timeout do
		local api = G.__HIGGI_TOGGLES_API
		if type(api) == "table" and type(api.Subscribe) == "function" then
			return api
		end
		task.wait(0.05)
	end
	return nil
end

local Toggles = waitForTogglesApi(6)
if not Toggles then
	warn("[Rage] Toggle API missing")
	return
end

----------------------------------------------------
-- STATE
----------------------------------------------------

local connection: RBXScriptConnection? = nil
local teamCheckEnabled = true
local currentTarget: BasePart? = nil

----------------------------------------------------
-- TEAM CHECK
----------------------------------------------------

local function isEnemy(plr: Player): boolean
	if plr == LocalPlayer then
		return false
	end

	if not teamCheckEnabled then
		return true
	end

	if LocalPlayer.Team and plr.Team then
		return plr.Team ~= LocalPlayer.Team
	end

	return true
end

----------------------------------------------------
-- HELPERS
----------------------------------------------------

local function isAlive(plr: Player): boolean
	local char = plr.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function getAimPart(plr: Player): BasePart?
	local char = plr.Character
	if not char then return nil end
	return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

----------------------------------------------------
-- TARGETING
----------------------------------------------------

local function getClosestTarget(): BasePart?
	if not Camera then return nil end
	if not LocalPlayer.Character then return nil end

	local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local viewport = Camera.ViewportSize
	local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)

	local bestPart: BasePart? = nil
	local bestDist = math.huge

	for _, plr in ipairs(Players:GetPlayers()) do
		if not isEnemy(plr) then continue end
		if not isAlive(plr) then continue end

		local part = getAimPart(plr)
		if not part then continue end

		local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen or screenPos.Z <= 0 then continue end

		local dx = screenPos.X - center.X
		local dy = screenPos.Y - center.Y
		local dist2 = dx*dx + dy*dy
		if dist2 > fov*fov then continue end

		local worldDist = (part.Position - root.Position).Magnitude
		if worldDist < bestDist then
			bestDist = worldDist
			bestPart = part
		end
	end

	return bestPart
end

----------------------------------------------------
-- SMOOTH DELTA ROTATION
----------------------------------------------------

local function rotateCharacterTowards(targetPos: Vector3)
	local character = LocalPlayer.Character
	if not character then return end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local rootPos = root.Position
	local flatTarget = Vector3.new(targetPos.X, rootPos.Y, targetPos.Z)

	local desiredDir = (flatTarget - rootPos).Unit
	local currentDir = root.CFrame.LookVector

	local dot = math.clamp(currentDir:Dot(desiredDir), -1, 1)
	local angle = math.acos(dot)

	if angle < 0.0005 then return end

	local cross = currentDir:Cross(desiredDir)
	local sign = cross.Y >= 0 and 1 or -1

	local deltaYaw = angle * sign

	-- menu-safe smoothing curve
	-- 0 = instant, 1 = slow
	local smoothingFactor = math.clamp(1 - smoothness, 0, 1)

	-- prevent massive snap if target teleports
	local maxStep = math.rad(35)
	local step = math.clamp(deltaYaw * smoothingFactor, -maxStep, maxStep)

	root.CFrame = root.CFrame * CFrame.Angles(0, step, 0)
end

----------------------------------------------------
-- CONTROL
----------------------------------------------------

local function start()
	if connection then return end

	connection = RunService.RenderStepped:Connect(function()

		local newTarget = getClosestTarget()

		if currentTarget and (not newTarget or newTarget ~= currentTarget) then
			currentTarget = nil
		end

		if not currentTarget and newTarget then
			currentTarget = newTarget
		end

		local character = LocalPlayer.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")

		if currentTarget then
			if hum then
				hum.AutoRotate = false
			end

			rotateCharacterTowards(currentTarget.Position)
		else
			if hum then
				hum.AutoRotate = true
			end
		end

	end)
end

local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end

	local character = LocalPlayer.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
	end

	currentTarget = nil
end

----------------------------------------------------
-- VALUE LINKS (UNCHANGED FOR MENU)
----------------------------------------------------

local function applyFromStore()
	fov = Toggles.GetValue("combat_rage_fov", 120)
	smoothness = Toggles.GetValue("combat_rage_smooth", 0.18)
end

Toggles.SubscribeValue("combat_rage_fov", function(v)
	fov = v
end)

Toggles.SubscribeValue("combat_rage_smooth", function(v)
	smoothness = v
end)

applyFromStore()

----------------------------------------------------
-- TOGGLES
----------------------------------------------------

Toggles.Subscribe("combat_rage", function(state)
	if state then
		start()
	else
		stop()
	end
end)

Toggles.Subscribe("combat_rage_teamcheck", function(state)
	teamCheckEnabled = state
end)

if Toggles.GetState("combat_rage", false) then
	start()
end

teamCheckEnabled = Toggles.GetState("combat_rage_teamcheck", true)
