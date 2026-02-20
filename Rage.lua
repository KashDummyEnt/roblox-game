--!strict
-- Rage.lua
-- Toggle-based Rage Aimbot (HIGGI SYSTEM)
-- Menu-linked sliders:
--		combat_rage_fov (number)
--		combat_rage_smooth (number)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------
-- DEFAULTS (will be overwritten by slider values)
----------------------------------------------------

local fov = 120			-- FOV radius in pixels
local smoothness = 0.18	-- 0 = instant snap | 0.1–0.3 = smooth | 1 = no movement

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
local fovGui: ScreenGui? = nil
local teamCheckEnabled = true

----------------------------------------------------
-- CAMERA
----------------------------------------------------

local Camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = workspace.CurrentCamera or Camera
end)

----------------------------------------------------
-- TEAM DETECTION (MULTI METHOD)
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

	if LocalPlayer.TeamColor and plr.TeamColor then
		return plr.TeamColor ~= LocalPlayer.TeamColor
	end

	local localAttrTeam = LocalPlayer:GetAttribute("Team")
	local plrAttrTeam = plr:GetAttribute("Team")
	if localAttrTeam ~= nil and plrAttrTeam ~= nil then
		return localAttrTeam ~= plrAttrTeam
	end

	local localFaction = LocalPlayer:GetAttribute("Faction")
	local plrFaction = plr:GetAttribute("Faction")
	if localFaction ~= nil and plrFaction ~= nil then
		return localFaction ~= plrFaction
	end

	return true
end

----------------------------------------------------
-- FOV CIRCLE
----------------------------------------------------

local function getFovCircleFrame(): Frame?
	if not fovGui then return nil end
	local circle = fovGui:FindFirstChild("Circle")
	if circle and circle:IsA("Frame") then
		return circle
	end
	return nil
end

local function applyFovToCircle()
	local circle = getFovCircleFrame()
	if not circle then return end
	circle.Size = UDim2.fromOffset(fov * 2, fov * 2)
end

local function createFov()
	if fovGui then return end

	local gui = Instance.new("ScreenGui")
	gui.Name = "RageFovGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.new(0.5, 0, 0.5, 0)
	circle.Size = UDim2.fromOffset(fov * 2, fov * 2)
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
-- TARGETING
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

local function getClosestTarget(): BasePart?
	if not Camera then return nil end

	local viewport = Camera.ViewportSize
	local center = Vector2.new(viewport.X * 0.5, viewport.Y * 0.5)

	local bestPart: BasePart? = nil
	local bestDist2 = fov * fov

	for _, plr in ipairs(Players:GetPlayers()) do
		if not isEnemy(plr) then continue end
		if not isAlive(plr) then continue end

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
-- SMOOTH AIM
----------------------------------------------------

local function smoothLookAt(targetPos: Vector3)
	local camCF = Camera.CFrame
	local desired = CFrame.new(camCF.Position, targetPos)
	Camera.CFrame = camCF:Lerp(desired, 1 - smoothness)
end

----------------------------------------------------
-- CONTROL
----------------------------------------------------

local function start()
	if connection then return end
	createFov()
	applyFovToCircle()

	connection = RunService.RenderStepped:Connect(function()
		local target = getClosestTarget()
		if not target then return end
		smoothLookAt(target.Position)
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
-- VALUE LINKS (SLIDERS)
----------------------------------------------------

local function applyFromStore()
	fov = Toggles.GetValue("combat_rage_fov", 120)
	smoothness = Toggles.GetValue("combat_rage_smooth", 0.18)
	applyFovToCircle()
end

Toggles.SubscribeValue("combat_rage_fov", function(v)
	fov = v
	applyFovToCircle()
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

-- Initialize states if already on
if Toggles.GetState("combat_rage", false) then
	start()
end

teamCheckEnabled = Toggles.GetState("combat_rage_teamcheck", true)
