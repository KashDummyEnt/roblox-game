-- TweenToNPC.lua
-- Heartbeat-based gravity-proof fly follow
-- Constant Freefall animation
-- Hard noclip every frame

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- =========================
-- CONFIG
-- =========================
local MOVE_SPEED = 150
local FRONT_DISTANCE = 15
local HEIGHT_OFFSET = 3
local ARRIVAL_THRESHOLD = 0.25

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
local activeConnection = nil
local savedCanCollide = {}

-- =========================
-- Character helpers
-- =========================
local function getChar()
	return player.Character
end

local function getHumanoid(char)
	return char:FindFirstChildOfClass("Humanoid")
end

local function getRoot(char)
	return char:FindFirstChild("HumanoidRootPart")
end

-- =========================
-- Registry integration
-- =========================
local function getRegistryEntry(name)
	local reg = G.__HIGGI_NPC_REGISTRY
	if not reg then return nil end
	return reg.byName[name]
end

local function resolveNpcPose(selected)
	local entry = getRegistryEntry(selected)
	if not entry then return nil, nil end

	if entry.model and entry.model.Parent then
		local m = entry.model
		local pp = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
		if pp then
			return pp.Position, pp.CFrame.LookVector
		end
	end

	if entry.lastCFrame then
		return entry.lastCFrame.Position, entry.lastCFrame.LookVector
	end

	return nil, nil
end

-- =========================
-- Noclip (hard enforced)
-- =========================
local function applyNoclip(char)
	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("BasePart") then
			if savedCanCollide[inst] == nil then
				savedCanCollide[inst] = inst.CanCollide
			end
			inst.CanCollide = false
		end
	end
end

local function restoreNoclip()
	for part, state in pairs(savedCanCollide) do
		if part and part.Parent then
			part.CanCollide = state
		end
	end
	savedCanCollide = {}
end

-- =========================
-- Stop
-- =========================
local function stopFly()
	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end

	local char = getChar()
	if not char then return end

	restoreNoclip()

	local root = getRoot(char)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

-- =========================
-- Start (Heartbeat)
-- =========================
local function startFlyFollow()
	stopFly()

	local char = getChar()
	if not char then return end

	local h = getHumanoid(char)
	local root = getRoot(char)
	if not h or not root then return end

	activeConnection = RunService.Heartbeat:Connect(function(dt)

		if not Toggles.GetState("world_tween_to_npc", false) then
			stopFly()
			return
		end

		if not root:IsDescendantOf(workspace) then
			stopFly()
			return
		end

		-- Force noclip every frame (some games reset collision)
		applyNoclip(char)

		-- Force Freefall animation state every frame
		if h:GetState() ~= Enum.HumanoidStateType.Freefall then
			h:ChangeState(Enum.HumanoidStateType.Freefall)
		end

		local selected = G.__HIGGI_SELECTED_NPC
		if not selected or selected == "" then return end

		local npcPos, npcLook = resolveNpcPose(selected)
		if not npcPos then return end

		local targetPos =
			npcPos
			+ (npcLook * FRONT_DISTANCE)
			+ Vector3.new(0, HEIGHT_OFFSET, 0)

		local currentPos = root.Position
		local delta = targetPos - currentPos
		local dist = delta.Magnitude

		if dist < ARRIVAL_THRESHOLD then
			root.AssemblyLinearVelocity = Vector3.zero
			return
		end

		-- Constant speed movement
		local direction = delta.Unit
		local velocity = direction * MOVE_SPEED

		-- Completely override gravity by replacing velocity
		root.AssemblyLinearVelocity = velocity

		-- Face NPC
		root.CFrame = CFrame.new(root.Position, npcPos)
	end)
end

-- =========================
-- Toggle
-- =========================
local function handleState(state)
	if state then
		startFlyFollow()
	else
		stopFly()
	end
end

Toggles.Subscribe("world_tween_to_npc", handleState)

if Toggles.GetState("world_tween_to_npc", false) then
	handleState(true)
end

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	if Toggles.GetState("world_tween_to_npc", false) then
		startFlyFollow()
	end
end)
