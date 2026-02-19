-- TweenToNPC.lua
-- Constant-speed fly-to / noclip follow
-- Constant Freefall animation while active
-- Uses registry fallback if NPC despawns

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
local ROTATION_LERP = 0.25

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
		if not savedHumanoidState then
			savedHumanoidState = h:GetState()
		end

		pcall(function()
			h:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
			h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			h:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			h:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
			h:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
		end)

		h.AutoRotate = false
	else
		pcall(function()
			h:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
			h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			h:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
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
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- =========================
-- Core follow logic (CFrame-based + forced Freefall)
-- =========================
local function startFlyFollow()
	stopFly()

	local char = getChar()
	if not char then return end

	local h = getHumanoid(char)
	local root = getRoot(char)
	if not h or not root then return end

	setHumanoidPhysics(h, true)
	setNoclip(char, true)

	activeConnection = RunService.RenderStepped:Connect(function(dt)
		if not root:IsDescendantOf(workspace) then
			stopFly()
			return
		end

		if not Toggles.GetState("world_tween_to_npc", false) then
			stopFly()
			return
		end

		-- Force constant falling animation
		if h:GetState() ~= Enum.HumanoidStateType.Freefall then
			pcall(function()
				h:ChangeState(Enum.HumanoidStateType.Freefall)
			end)
		end

		local selected = G.__HIGGI_SELECTED_NPC
		if not selected or selected == "" then
			return
		end

		local npcPos, npcLook = resolveNpcPose(selected)
		if not npcPos or not npcLook then
			return
		end

		local targetPos =
			npcPos
			+ (npcLook * FRONT_DISTANCE)
			+ Vector3.new(0, HEIGHT_OFFSET, 0)

		local currentPos = root.Position
		local delta = targetPos - currentPos
		local dist = delta.Magnitude

		if dist < ARRIVAL_THRESHOLD then
			local lookCF = CFrame.new(targetPos, npcPos)
			root.CFrame = root.CFrame:Lerp(lookCF, ROTATION_LERP)
			return
		end

		local moveStep = math.min(MOVE_SPEED * dt, dist)
		local newPos = currentPos + delta.Unit * moveStep

		local lookCF = CFrame.new(newPos, npcPos)
		root.CFrame = root.CFrame:Lerp(lookCF, ROTATION_LERP)
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

-- Respawn safety
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	if Toggles.GetState("world_tween_to_npc", false) then
		startFlyFollow()
	end
end)
