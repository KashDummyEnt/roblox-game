--!strict
-- Flight.lua
-- Toggle-driven Flight + Noclip
-- API-safe (matches AdminESP style)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------
-- GLOBAL TOGGLE API ACCESS (MATCHES ESP STYLE)
------------------------------------------------------------------

local function getGlobal(): any
	local gg = (typeof(getgenv) == "function") and getgenv() or nil
	if gg then
		return gg
	end
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
	warn("[Flight] Toggle API missing")
	return
end

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------

local KEY = "world_flight"
local SPEED = 60

------------------------------------------------------------------
-- STATE
------------------------------------------------------------------

local flying = false
local bodyVelocity: BodyVelocity? = nil
local bodyGyro: BodyGyro? = nil
local flightConn: RBXScriptConnection? = nil
local noclipConn: RBXScriptConnection? = nil

------------------------------------------------------------------
-- HELPERS
------------------------------------------------------------------

local function getCharacter()
	return LocalPlayer.Character
end

local function getHRP(): BasePart?
	local char = getCharacter()
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getHumanoid(): Humanoid?
	local char = getCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

------------------------------------------------------------------
-- NOCLIP
------------------------------------------------------------------

local function enableNoclip()
	if noclipConn then return end

	noclipConn = RunService.Stepped:Connect(function()
		local char = getCharacter()
		if not char then return end

		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end)
end

local function disableNoclip()
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
end

------------------------------------------------------------------
-- FLIGHT
------------------------------------------------------------------

local function enableFlight()
	if flying then return end

	local hrp = getHRP()
	local humanoid = getHumanoid()
	if not hrp or not humanoid then return end

	flying = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.Parent = hrp

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	bodyGyro.P = 10000
	bodyGyro.CFrame = workspace.CurrentCamera.CFrame
	bodyGyro.Parent = hrp

	enableNoclip()

	flightConn = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera or not bodyVelocity or not bodyGyro then return end

		local moveDir = Vector3.zero

		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			moveDir += camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			moveDir -= camera.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			moveDir -= camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moveDir += camera.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			moveDir += Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			moveDir -= Vector3.new(0, 1, 0)
		end

		if moveDir.Magnitude > 0 then
			moveDir = moveDir.Unit * SPEED
		end

		bodyVelocity.Velocity = moveDir
		bodyGyro.CFrame = camera.CFrame
	end)
end

local function disableFlight()
	if not flying then return end
	flying = false

	if flightConn then
		flightConn:Disconnect()
		flightConn = nil
	end

	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end

	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end

	local humanoid = getHumanoid()
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	disableNoclip()
end

------------------------------------------------------------------
-- TOGGLE BIND
------------------------------------------------------------------

Toggles.Subscribe(KEY, function(state: boolean)
	if state then
		enableFlight()
	else
		disableFlight()
	end
end)

-- If already enabled before script loaded
if Toggles.GetState(KEY, false) then
	enableFlight()
end

------------------------------------------------------------------
-- RESPAWN SUPPORT
------------------------------------------------------------------

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	if Toggles.GetState(KEY, false) then
		enableFlight()
	end
end)
