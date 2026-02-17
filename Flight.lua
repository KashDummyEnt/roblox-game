-- Flight.lua
-- Toggle-driven Flight + Noclip
-- Requires ToggleSwitches system

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Get shared toggle API
local function getGlobal()
	if typeof(getgenv) == "function" then
		return getgenv()
	end
	return _G
end

local G = getGlobal()
local Toggles = G.__HIGGI_TOGGLES_API

if not Toggles then
	warn("Flight.lua: Toggle API not found.")
	return
end

local KEY = "world_flight"

local flying = false
local bodyVelocity: BodyVelocity? = nil
local bodyGyro: BodyGyro? = nil
local flightConn: RBXScriptConnection? = nil
local noclipConn: RBXScriptConnection? = nil

local SPEED = 60

local function getCharacter()
	return player.Character
end

local function getHRP()
	local char = getCharacter()
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
	local char = getCharacter()
	if not char then return nil end
	return char:FindFirstChildOfClass("Humanoid")
end

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

-- Listen to toggle
Toggles.Subscribe(KEY, function(state)
	if state then
		enableFlight()
	else
		disableFlight()
	end
end)

-- Handle respawn
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	if Toggles.GetState(KEY, false) then
		enableFlight()
	end
end)
