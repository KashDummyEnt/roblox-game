--!strict
-- Flight.lua
-- Advanced Mobile-Supported Flight (Toggle Driven)
-- Flight + Noclip together (no separate toggle)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------
-- TOGGLE API (MATCHES ESP STYLE)
------------------------------------------------------------------

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
	warn("[Flight] Toggle API missing")
	return
end

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------

local KEY = "world_flight"

local MAX_SPEED = 70
local BOOST_MULT = 1.6
local VERTICAL_SPEED = 55

local ACCEL = 12
local DECEL = 14
local TURN_RESPONSIVENESS = 60

local VERTICAL_RELATIVE_TO_CAMERA = false

------------------------------------------------------------------
-- SAFETY (PREVENT STACKING)
------------------------------------------------------------------

if G.__HIGGI_FLIGHT and G.__HIGGI_FLIGHT.Cleanup then
	G.__HIGGI_FLIGHT.Cleanup()
end

G.__HIGGI_FLIGHT = {}
local State = G.__HIGGI_FLIGHT

------------------------------------------------------------------
-- STATE
------------------------------------------------------------------

local flying = false
local boosting = false
local goUp = false
local goDown = false

local att: Attachment? = nil
local lv: LinearVelocity? = nil
local ao: AlignOrientation? = nil

local hbConn: RBXScriptConnection? = nil
local charConn: RBXScriptConnection? = nil
local diedConn: RBXScriptConnection? = nil
local noclipConn: RBXScriptConnection? = nil

local currentVel = Vector3.zero
local Controls = nil

------------------------------------------------------------------
-- HELPERS
------------------------------------------------------------------

local function getChar()
	local char = LocalPlayer.Character
	if not char then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end

	return char, hum, root
end

local function destroyForces()
	if ao then ao:Destroy() ao = nil end
	if lv then lv:Destroy() lv = nil end
	if att then att:Destroy() att = nil end
end

------------------------------------------------------------------
-- MOBILE CONTROLS
------------------------------------------------------------------

local function hookControls()
	local ok, playerModule = pcall(function()
		return require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)

	if ok and playerModule then
		Controls = playerModule:GetControls()
	end
end

------------------------------------------------------------------
-- NOCLIP (AUTO WITH FLIGHT)
------------------------------------------------------------------

local function setCharacterCollide(canCollide: boolean)
	local char = LocalPlayer.Character
	if not char then return end

	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = canCollide
		end
	end
end

local function stopNoclip()
	if noclipConn then
		noclipConn:Disconnect()
		noclipConn = nil
	end
	setCharacterCollide(true)
end

local function startNoclip()
	stopNoclip()

	noclipConn = RunService.Stepped:Connect(function()
		setCharacterCollide(false)
	end)
end

------------------------------------------------------------------
-- VERTICAL BIND
------------------------------------------------------------------

local function bindVertical()
	ContextActionService:BindAction("FlyUp", function(_, state)
		goUp = (state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space)

	ContextActionService:BindAction("FlyDown", function(_, state)
		goDown = (state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftControl, Enum.KeyCode.C)

	ContextActionService:BindAction("FlyBoost", function(_, state)
		boosting = (state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change)
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift)
end

local function unbindVertical()
	ContextActionService:UnbindAction("FlyUp")
	ContextActionService:UnbindAction("FlyDown")
	ContextActionService:UnbindAction("FlyBoost")
	goUp = false
	goDown = false
	boosting = false
end

------------------------------------------------------------------
-- STOP FLIGHT
------------------------------------------------------------------

local function stopFlight()
	if not flying then return end
	flying = false

	if hbConn then hbConn:Disconnect() hbConn = nil end
	unbindVertical()

	local _, hum, root = getChar()

	if hum then
		hum.AutoRotate = true
		if hum:GetState() == Enum.HumanoidStateType.Physics then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end

	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	destroyForces()
	stopNoclip()
	currentVel = Vector3.zero
end

------------------------------------------------------------------
-- START FLIGHT
------------------------------------------------------------------

local function startFlight()
	local _, hum, root = getChar()
	if not hum or not root then return end
	if flying then return end

	flying = true
	currentVel = Vector3.zero

	hum.AutoRotate = false
	hum:ChangeState(Enum.HumanoidStateType.Physics)

	att = Instance.new("Attachment")
	att.Parent = root

	lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root

	ao = Instance.new("AlignOrientation")
	ao.Attachment0 = att
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Responsiveness = TURN_RESPONSIVENESS
	ao.MaxTorque = math.huge
	ao.Parent = root

	startNoclip()
	bindVertical()

	hbConn = RunService.Heartbeat:Connect(function(dt)
		local _, hum2, root2 = getChar()
		if not hum2 or not root2 or not lv or not ao then return end

		local cam = workspace.CurrentCamera
		if not cam then return end

		-- Mobile joystick support
		local mv = Vector3.zero
		if Controls and Controls.GetMoveVector then
			local raw = Controls:GetMoveVector()
			mv = Vector3.new(raw.X, 0, -raw.Z)
		else
			mv = Vector3.new(hum2.MoveDirection.X, 0, hum2.MoveDirection.Z)
		end

		local forward = cam.CFrame.LookVector.Unit
		local right = cam.CFrame.RightVector.Unit

		local desired = (right * mv.X + forward * mv.Z)
		if desired.Magnitude > 1 then
			desired = desired.Unit
		end

		local speed = MAX_SPEED * (boosting and BOOST_MULT or 1)
		local planarVel = desired * speed

		local y = 0
		if goUp then y += 1 end
		if goDown then y -= 1 end

		local verticalVel
		if VERTICAL_RELATIVE_TO_CAMERA then
			verticalVel = cam.CFrame.UpVector * (y * VERTICAL_SPEED)
		else
			verticalVel = Vector3.new(0, y * VERTICAL_SPEED, 0)
		end

		local targetVel = planarVel + verticalVel

		local rate = (targetVel.Magnitude > currentVel.Magnitude) and ACCEL or DECEL
		local alpha = math.clamp(rate * dt, 0, 1)
		currentVel = currentVel:Lerp(targetVel, alpha)

		lv.VectorVelocity = currentVel
		ao.CFrame = cam.CFrame
	end)
end

------------------------------------------------------------------
-- TOGGLE BIND
------------------------------------------------------------------

Toggles.Subscribe(KEY, function(state: boolean)
	if state then
		startFlight()
	else
		stopFlight()
	end
end)

if Toggles.GetState(KEY, false) then
	startFlight()
end

------------------------------------------------------------------
-- RESPAWN / DEATH
------------------------------------------------------------------

local function hookCharacter()
	if diedConn then diedConn:Disconnect() diedConn = nil end

	local _, hum, _ = getChar()
	if hum then
		diedConn = hum.Died:Connect(function()
			stopFlight()
		end)
	end
end

hookControls()
hookCharacter()

charConn = LocalPlayer.CharacterAdded:Connect(function()
	stopFlight()
	task.wait(0.1)
	hookCharacter()

	if Toggles.GetState(KEY, false) then
		startFlight()
	end
end)

------------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------------

State.Cleanup = function()
	stopFlight()
	if charConn then charConn:Disconnect() charConn = nil end
	if diedConn then diedConn:Disconnect() diedConn = nil end
	unbindVertical()
	destroyForces()
	stopNoclip()
	Controls = nil
end
