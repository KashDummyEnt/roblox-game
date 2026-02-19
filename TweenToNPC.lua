-- TweenToNPC.lua
-- Constant-speed fly-to / noclip follow: stays 5 studs in front of selected NPC
-- Stops only when toggle turns off.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- =========================
-- CONFIG
-- =========================
local MOVE_SPEED = 150			-- studs per second
local FRONT_DISTANCE = 5		-- studs in front of NPC
local HEIGHT_OFFSET = 3			-- keep you slightly above target so you don't scrape floors

-- =========================
-- Global access
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
	warn("TweenToNPC: Toggles API missing")
	return
end

-- =========================
-- State
-- =========================
local activeConnection: RBXScriptConnection? = nil
local savedCanCollide: {[BasePart]: boolean} = {}
local savedHumanoidState: Enum.HumanoidStateType? = nil

local function getChar(): Model?
	return player.Character
end

local function getHumanoid(char: Model): Humanoid?
	local h = char:FindFirstChildOfClass("Humanoid")
	if h and h:IsA("Humanoid") then
		return h
	end
	return nil
end

local function getRoot(char: Model): BasePart?
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function getNpcModel(name: string): Model?
	local folder = workspace:FindFirstChild("NPCs")
	if not folder then
		return nil
	end

	local m = folder:FindFirstChild(name)
	if m and m:IsA("Model") then
		return m
	end

	return nil
end

local function getNpcPrimaryPart(model: Model): BasePart?
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	return model:FindFirstChildWhichIsA("BasePart")
end

-- =========================
-- Noclip + humanoid control
-- =========================
local function setNoclip(char: Model, enabled: boolean)
	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("BasePart") then
			if enabled then
				if savedCanCollide[inst] == nil then
					savedCanCollide[inst] = inst.CanCollide
				end
				inst.CanCollide = false
			else
				if savedCanCollide[inst] ~= nil then
					inst.CanCollide = savedCanCollide[inst]
				end
			end
		end
	end

	if not enabled then
		savedCanCollide = {}
	end
end

local function setHumanoidPhysics(h: Humanoid, enabled: boolean)
	if enabled then
		-- Save state once
		if not savedHumanoidState then
			savedHumanoidState = h:GetState()
		end

		-- Disable common states that fight movement
		pcall(function()
			h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			h:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			h:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
			h:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
			h:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
		end)

		-- Put humanoid into Physics so gravity/walking controllers stop fighting
		pcall(function()
			h:ChangeState(Enum.HumanoidStateType.Physics)
		end)

		h.AutoRotate = false
	else
		-- Restore state enabling
		pcall(function()
			h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			h:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			h:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
			h:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
			h:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
		end)

		h.AutoRotate = true

		if savedHumanoidState then
			pcall(function()
				h:ChangeState(savedHumanoidState :: Enum.HumanoidStateType)
			end)
		end
		savedHumanoidState = nil
	end
end

local function stopFly()
	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end

	local char = getChar()
	if char then
		local h = getHumanoid(char)
		if h then
			setHumanoidPhysics(h, false)
		end
		setNoclip(char, false)

		local root = getRoot(char)
		if root then
			-- Clear velocity so you don't keep drifting
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- =========================
-- Core follow logic (fly/velocity)
-- =========================
local function startFlyFollow()
	stopFly()

	local char = getChar()
	if not char then
		return
	end

	local h = getHumanoid(char)
	local root = getRoot(char)
	if not h or not root then
		return
	end

	setHumanoidPhysics(h, true)
	setNoclip(char, true)

	activeConnection = RunService.Heartbeat:Connect(function(dt)
		if not Toggles.GetState("world_tween_to_npc", false) then
			stopFly()
			return
		end

		-- keep noclip forced (some games re-enable collisions)
		setNoclip(char, true)

		local selected = G.__HIGGI_SELECTED_NPC
		if not selected or selected == "" then
			root.AssemblyLinearVelocity = Vector3.zero
			return
		end

		local npc = getNpcModel(selected)
		if not npc then
			root.AssemblyLinearVelocity = Vector3.zero
			return
		end

		local npcPart = getNpcPrimaryPart(npc)
		if not npcPart then
			root.AssemblyLinearVelocity = Vector3.zero
			return
		end

		local npcPos = npcPart.Position
		local npcLook = npcPart.CFrame.LookVector

		-- 5 studs in front of NPC, plus a small height lift
		local targetPos = npcPos + (npcLook * FRONT_DISTANCE) + Vector3.new(0, HEIGHT_OFFSET, 0)

		local currentPos = root.Position
		local delta = targetPos - currentPos
		local dist = delta.Magnitude

		if dist < 0.25 then
			-- close enough: hold position + face NPC
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(currentPos, npcPos)
			return
		end

		-- velocity-based constant speed (no gravity fight)
		local vel = delta.Unit * MOVE_SPEED
		root.AssemblyLinearVelocity = vel

		-- face NPC while moving
		root.CFrame = CFrame.new(currentPos, npcPos)
	end)
end

-- =========================
-- Toggle handling
-- =========================
local function handleState(state: boolean)
	if state then
		startFlyFollow()
	else
		stopFly()
	end
end

Toggles.Subscribe("world_tween_to_npc", handleState)

-- Run immediately if already enabled
if Toggles.GetState("world_tween_to_npc", false) then
	handleState(true)
end
