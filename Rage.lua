--!strict
-- Rage.lua
-- Toggle-based Rage Aimbot (HIGGI SYSTEM - ALIGNED WITH ESP)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------
-- GLOBAL TOGGLE ACCESS (same pattern as AdminESP)
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
-- CONFIG
----------------------------------------------------

local AIM_AT = "Head" -- "Head" or "HumanoidRootPart"
local FOV_RADIUS = 250
local ALIVE_ONLY = true

-- EXACT same style as AdminESP
local TEAM_CHECK_ENABLED = true

----------------------------------------------------
-- STATE
----------------------------------------------------

local connection: RBXScriptConnection? = nil
local fovGui: ScreenGui? = nil

----------------------------------------------------
-- CAMERA HANDLING
----------------------------------------------------

local Camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = workspace.CurrentCamera or Camera
end)

----------------------------------------------------
-- FOV CIRCLE
----------------------------------------------------

local function createFov()
	if fovGui then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "RageFovGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.new(0.5, 0, 0.5, 0)
	circle.Size = UDim2.fromOffset(FOV_RADIUS * 2, FOV_RADIUS * 2)
	circle.BackgroundTransparency = 1
	circle.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = circle

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	fovGui = gui
end

local function destroyFov()
	if fovGui then
		fovGui:Destroy()
		fovGui = nil
	end
end

----------------------------------------------------
-- TARGETING (ALIGNED WITH ESP STYLE)
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

	if AIM_AT == "HumanoidRootPart" then
		return char:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

-- IDENTICAL STRUCTURE TO ADMINESP
local function isEnemy(plr: Player): boolean
	if plr == LocalPlayer then
		return false
	end
	
	if not TEAM_CHECK_ENABLED then
		return true
	end
	
	if not LocalPlayer.Team or not plr.Team then
		return true
	end
	
	return plr.Team ~= LocalPlayer.Team
end

local function getClosestTargetInFov(): BasePart?
	if not Camera then return nil end

	local viewport = Camera.ViewportSize
	local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)

	local bestPart: BasePart? = nil
	local bestDist2 = FOV_RADIUS * FOV_RADIUS

	for _, plr in ipairs(Players:GetPlayers()) do
		if not isEnemy(plr) then
			continue
		end

		if ALIVE_ONLY and not isAlive(plr) then
			continue
		end

		local part = getAimPart(plr)
		if not part then continue end

		local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen or screenPos.Z <= 0 then continue end

		local dx = screenPos.X - center.X
		local dy = screenPos.Y - center.Y
		local dist2 = dx * dx + dy * dy

		if dist2 <= bestDist2 then
			bestDist2 = dist2
			bestPart = part
		end
	end

	return bestPart
end

----------------------------------------------------
-- LOOP CONTROL
----------------------------------------------------

local function start()
	if connection then return end

	createFov()

	connection = RunService.RenderStepped:Connect(function()
		local targetPart = getClosestTargetInFov()
		if not targetPart then return end

		local camPos = Camera.CFrame.Position
		Camera.CFrame = CFrame.new(camPos, targetPart.Position)
	end)
end

local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end

	destroyFov()
end

----------------------------------------------------
-- TOGGLE SUBSCRIPTION
----------------------------------------------------

Toggles.Subscribe("combat_rage", function(state)
	if state then
		start()
	else
		stop()
	end
end)

-- If toggle was already enabled before load
if Toggles.GetState("combat_rage", false) then
	start()
end
