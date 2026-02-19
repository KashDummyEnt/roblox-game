-- TweenToNPC.lua
-- Tweens local player to selected NPC model (Workspace > NPCs)
-- Cancels tween cleanly when toggle turns off

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- get shared global
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

local activeTween: Tween? = nil
local activeConnection: RBXScriptConnection? = nil

local function cancelTween()
	if activeTween then
		pcall(function()
			activeTween:Cancel()
		end)
		activeTween = nil
	end

	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end
end

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

local function getModelPosition(model: Model): Vector3?
	if model.PrimaryPart then
		return model.PrimaryPart.Position
	end

	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end

	local anyPart = model:FindFirstChildWhichIsA("BasePart")
	if anyPart then
		return anyPart.Position
	end

	return nil
end

local function tweenToNpc()
	local selected = G.__HIGGI_SELECTED_NPC

	-- wait briefly for dropdown to populate if needed
	if not selected or selected == "" then
		task.wait(0.1)
		selected = G.__HIGGI_SELECTED_NPC
	end

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

	local targetPos = getModelPosition(npc)
	if not targetPos then
		return
	end

	cancelTween()

	local distance = (root.Position - targetPos).Magnitude
	local duration = math.clamp(distance / 60, 0.25, 3)

	local tweenInfo = TweenInfo.new(
		duration,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	activeTween = TweenService:Create(root, tweenInfo, {
		CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
	})

	activeTween:Play()

	-- auto cancel if toggle flips off mid-flight
	activeConnection = RunService.Heartbeat:Connect(function()
		if not Toggles.GetState("world_tween_to_npc", false) then
			cancelTween()
		end
	end)
end

local function handleState(state)
	if state then
		task.defer(function()
			tweenToNpc()
		end)
	else
		cancelTween()
	end
end

Toggles.Subscribe("world_tween_to_npc", handleState)

-- IMPORTANT: run immediately if already enabled
if Toggles.GetState("world_tween_to_npc", false) then
	handleState(true)
end


