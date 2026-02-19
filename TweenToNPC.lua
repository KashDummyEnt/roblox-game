-- TweenToNPC.lua
-- True linear fly, no physics fighting, no jitter, instant noclip

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- =========================
-- CONFIG
-- =========================
local MOVE_SPEED = 150
local FRONT_DISTANCE = 15
local HEIGHT_OFFSET = 3
local ARRIVAL_THRESHOLD = 1

-- =========================
-- GLOBAL
-- =========================
local function getGlobal()
	return (typeof(getgenv) == "function" and getgenv()) or _G
end

local G = getGlobal()
local Toggles = G.__HIGGI_TOGGLES_API
if not Toggles then return end

-- =========================
-- STATE
-- =========================
local connection: RBXScriptConnection? = nil
local locked = false

-- =========================
-- Helpers
-- =========================
local function getChar()
	return player.Character
end

local function getRoot(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRegistryEntry(name)
	local reg = G.__HIGGI_NPC_REGISTRY
	return reg and reg.byName and reg.byName[name]
end

local function resolveNpcPose(name)
	local entry = getRegistryEntry(name)
	if not entry then return nil, nil end

	if entry.model and entry.model.Parent then
		local m = entry.model
		local pp = m.PrimaryPart
			or m:FindFirstChild("HumanoidRootPart")
			or m:FindFirstChildWhichIsA("BasePart")

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
-- Hard Noclip
-- =========================
local function forceNoclip(char)
	for _, v in ipairs(char:GetDescendants()) do
		if v:IsA("BasePart") then
			v.CanCollide = false
		end
	end
end

-- =========================
-- Stop
-- =========================
local function stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end

	local char = getChar()
	if not char then return end

	local humanoid = getHumanoid(char)
	if humanoid then
		humanoid.PlatformStand = false
	end

	local root = getRoot(char)
	if root then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end

	locked = false
end

-- =========================
-- Start
-- =========================
local function start()
	stop()

	local char = getChar()
	if not char then return end

	local root = getRoot(char)
	local humanoid = getHumanoid(char)
	if not root or not humanoid then return end

	-- kill physics controller entirely
	humanoid.PlatformStand = true

	connection = RunService.Heartbeat:Connect(function(dt)

		if not Toggles.GetState("world_tween_to_npc", false) then
			stop()
			return
		end

		if not root:IsDescendantOf(workspace) then
			stop()
			return
		end

		forceNoclip(char)

		local selected = G.__HIGGI_SELECTED_NPC
		if not selected or selected == "" then return end

		local npcPos, npcLook = resolveNpcPose(selected)
		if not npcPos then return end

		local target =
			npcPos
			+ npcLook * FRONT_DISTANCE
			+ Vector3.new(0, HEIGHT_OFFSET, 0)

		local delta = target - root.Position
		local dist = delta.Magnitude

		-- ARRIVAL
		if dist <= ARRIVAL_THRESHOLD then
			if not locked then
				locked = true
				root.Anchored = true
				root.CFrame = CFrame.new(target, npcPos)
			end
			return
		end

		-- MOVING
		if locked then
			root.Anchored = false
			locked = false
		end

		local step = math.min(MOVE_SPEED * dt, dist)
		local newPos = root.Position + delta.Unit * step

		root.CFrame = CFrame.new(newPos, npcPos)
	end)
end

-- =========================
-- Toggle
-- =========================
Toggles.Subscribe("world_tween_to_npc", function(state)
	if state then
		start()
	else
		stop()
	end
end)

if Toggles.GetState("world_tween_to_npc", false) then
	start()
end

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	if Toggles.GetState("world_tween_to_npc", false) then
		start()
	end
end)
