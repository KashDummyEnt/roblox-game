-- TweenToNPC.lua
-- Solver-safe linear fly follow using LinearVelocity (no gravity pull)

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
local activeAttachment: Attachment? = nil
local activeVelocity: LinearVelocity? = nil
local savedCanCollide: {[BasePart]: boolean} = {}

-- =========================
-- Character helpers
-- =========================
local function getChar(): Model?
	return player.Character
end

local function getHumanoid(char: Model): Humanoid?
	return char:FindFirstChildOfClass("Humanoid")
end

local function getRoot(char: Model): BasePart?
	local root = char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- =========================
-- Registry integration
-- =========================
local function getRegistryEntry(name: string)
	local reg = G.__HIGGI_NPC_REGISTRY
	if not reg or not reg.byName then
		return nil
	end
	return reg.byName[name]
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

local function resolveNpcPose(selected: string): (Vector3?, Vector3?)
	local entry = getRegistryEntry(selected)
	if not entry then
		return nil, nil
	end

	local m = entry.model
	if m and m.Parent then
		local pp = getNpcPrimaryPart(m)
		if pp then
			return pp.Position, pp.CFrame.LookVector
		end
	end

	local cf = entry.lastCFrame
	if cf then
		return cf.Position, cf.LookVector
	end

	return nil, nil
end

-- =========================
-- Noclip
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

-- =========================
-- Stop
-- =========================
local function stopFly()

	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end

	if activeVelocity then
		activeVelocity:Destroy()
		activeVelocity = nil
	end

	if activeAttachment then
		activeAttachment:Destroy()
		activeAttachment = nil
	end

	local char = getChar()
	if char then
		setNoclip(char, false)

		local root = getRoot(char)
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- =========================
-- Core linear movement (solver-safe)
-- =========================
local function startFlyFollow()

	stopFly()

	local char = getChar()
	if not char then return end

	local humanoid = getHumanoid(char)
	if not humanoid then return end

	local root = getRoot(char)
	if not root then return end

	setNoclip(char, true)

	-- Create physics attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "TweenAttachment"
	attachment.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Name = "TweenVelocity"
	lv.Attachment0 = attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root

	activeAttachment = attachment
	activeVelocity = lv

	activeConnection = RunService.Heartbeat:Connect(function(dt)

		if not root:IsDescendantOf(workspace) then
			stopFly()
			return
		end

		if not Toggles.GetState("world_tween_to_npc", false) then
			stopFly()
			return
		end

		setNoclip(char, true)

		local selected = G.__HIGGI_SELECTED_NPC
		if not selected or selected == "" then
			lv.VectorVelocity = Vector3.zero
			return
		end

		local npcPos, npcLook = resolveNpcPose(selected)
		if not npcPos or not npcLook then
			lv.VectorVelocity = Vector3.zero
			return
		end

		local targetPos =
			npcPos
			+ (npcLook * FRONT_DISTANCE)
			+ Vector3.new(0, HEIGHT_OFFSET, 0)

		local currentPos = root.Position
		local delta = targetPos - currentPos
		local dist = delta.Magnitude

		if dist <= ARRIVAL_THRESHOLD then
			lv.VectorVelocity = Vector3.zero
			root.CFrame = CFrame.new(targetPos, npcPos)
			return
		end

		local direction = delta.Unit
		lv.VectorVelocity = direction * MOVE_SPEED

		-- Keep facing NPC
		root.CFrame = CFrame.new(root.Position, npcPos)

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

if Toggles.GetState("world_tween_to_npc", false) then
	handleState(true)
end

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	if Toggles.GetState("world_tween_to_npc", false) then
		startFlyFollow()
	end
end)
