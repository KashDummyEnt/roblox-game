-- TweenToNPC.lua
-- Continuously positions player 5 studs in front of selected NPC
-- Constant speed follow. Stops only when toggle turns off.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- =========================
-- CONFIG
-- =========================
local MOVE_SPEED = 45            -- studs per second (change this)
local FRONT_DISTANCE = 5         -- how far in front of NPC

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

local function cancelFollow()
	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end
end

-- =========================
-- Helpers
-- =========================
local function getRoot(): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
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
-- Core Follow Logic
-- =========================
local function startFollowing()
	cancelFollow()

	activeConnection = RunService.Heartbeat:Connect(function(dt)
		if not Toggles.GetState("world_tween_to_npc", false) then
			cancelFollow()
			return
		end

		local selected = G.__HIGGI_SELECTED_NPC
		if not selected or selected == "" then
			return
		end

		local root = getRoot()
		if not root then
			return
		end

		local npc = getNpcModel(selected)
		if not npc then
			return
		end

		local npcPart = getNpcPrimaryPart(npc)
		if not npcPart then
			return
		end

		-- Calculate position 5 studs in FRONT of NPC
		local npcPos = npcPart.Position
		local npcLook = npcPart.CFrame.LookVector
		local targetPos = npcPos + (npcLook * FRONT_DISTANCE)

		local currentPos = root.Position
		local offset = targetPos - currentPos
		local distance = offset.Magnitude

		if distance < 0.05 then
			-- Snap rotation to always face NPC
			root.CFrame = CFrame.new(currentPos, npcPos)
			return
		end

		local moveStep = offset.Unit * MOVE_SPEED * dt

		-- Prevent overshooting
		if moveStep.Magnitude > distance then
			moveStep = offset
		end

		local newPos = currentPos + moveStep

		-- Face NPC while staying in front
		root.CFrame = CFrame.new(newPos, npcPos)
	end)
end

-- =========================
-- Toggle Handling
-- =========================
local function handleState(state)
	if state then
		startFollowing()
	else
		cancelFollow()
	end
end

Toggles.Subscribe("world_tween_to_npc", handleState)

-- Run immediately if already enabled
if Toggles.GetState("world_tween_to_npc", false) then
	handleState(true)
end
