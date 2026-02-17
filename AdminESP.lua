--!strict
-- AdminESP.lua
-- Multi-toggle ESP with proper distance scaling + snaplines from local feet (not screen center)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------
-- GLOBAL TOGGLE API ACCESS
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
	warn("[AdminESP] Toggle API missing")
	return
end

------------------------------------------------------------------
-- TOGGLE KEYS
------------------------------------------------------------------

local KEYS = {
	Name = "visuals_name",
	Health = "visuals_health",
	Player = "visuals_player",
	Snaplines = "visuals_snaplines",
}

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------

local NAME_TAG = "ESP_Name"
local HEALTH_TAG = "ESP_Health"
local GLOW_TAG = "ESP_Glow"

local NAME_BASE_W, NAME_BASE_H = 90, 22
local HP_BASE_W, HP_BASE_H = 70, 8

local MAX_DISTANCE = 500

------------------------------------------------------------------
-- STATE
------------------------------------------------------------------

local featureState = {
	Name = false,
	Health = false,
	Player = false,
	Snaplines = false,
}

local playerConns: {[number]: {RBXScriptConnection}} = {}
local scalerConn: RBXScriptConnection? = nil
local snaplineConn: RBXScriptConnection? = nil

------------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------------

local function cleanupPlayer(plr: Player)
	if playerConns[plr.UserId] then
		for _, c in ipairs(playerConns[plr.UserId]) do
			c:Disconnect()
		end
		playerConns[plr.UserId] = nil
	end

	if plr.Character then
		for _, inst in ipairs(plr.Character:GetDescendants()) do
			if inst.Name == NAME_TAG
			or inst.Name == HEALTH_TAG
			or inst.Name == GLOW_TAG then
				inst:Destroy()
			end
		end
	end
end

local function cleanupAll()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			cleanupPlayer(plr)
		end
	end
end

------------------------------------------------------------------
-- BUILDERS
------------------------------------------------------------------

local function buildName(plr: Player)
	local char = plr.Character
	if not char then return end
	local head = char:FindFirstChild("Head")
	if not head then return end
	if head:FindFirstChild(NAME_TAG) then return end

	local bill = Instance.new("BillboardGui")
	bill.Name = NAME_TAG
	bill.AlwaysOnTop = true
	bill.MaxDistance = MAX_DISTANCE
	bill.StudsOffset = Vector3.new(0, 2.9, 0)
	bill.Size = UDim2.new(0, NAME_BASE_W, 0, NAME_BASE_H)
	bill.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 70, 70)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Font = Enum.Font.GothamSemibold
	label.Text = plr.DisplayName
	label.Parent = bill
end

local function buildHealth(plr: Player)
	local char = plr.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	if root:FindFirstChild(HEALTH_TAG) then return end

	local bill = Instance.new("BillboardGui")
	bill.Name = HEALTH_TAG
	bill.AlwaysOnTop = true
	bill.MaxDistance = MAX_DISTANCE
	bill.StudsOffset = Vector3.new(0, -3.2, 0)
	bill.Size = UDim2.new(0, HP_BASE_W, 0, HP_BASE_H)
	bill.Parent = root

	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 1, 0)
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	back.BorderSizePixel = 0
	back.Parent = bill

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BorderSizePixel = 0
	fill.Parent = back

	local function update()
		local pct = 0
		if hum.MaxHealth > 0 then
			pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		end
		fill.Size = UDim2.new(pct, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(255 * (1 - pct), 255 * pct, 60)
	end

	update()

	playerConns[plr.UserId] = playerConns[plr.UserId] or {}
	table.insert(playerConns[plr.UserId], hum.HealthChanged:Connect(update))
end

local function buildGlow(plr: Player)
	local char = plr.Character
	if not char then return end
	if char:FindFirstChild(GLOW_TAG) then return end

	local h = Instance.new("Highlight")
	h.Name = GLOW_TAG
	h.FillColor = Color3.fromRGB(255, 0, 0)
	h.FillTransparency = 0.6
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = char
end

------------------------------------------------------------------
-- DISTANCE SCALING (YOUR ORIGINAL LOGIC)
------------------------------------------------------------------

local function startScaler()
	if scalerConn then return end

	scalerConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local char = plr.Character
				if char then
					local head = char:FindFirstChild("Head")
					local root = char:FindFirstChild("HumanoidRootPart")
					if head and root then
						local dist = (cam.CFrame.Position - root.Position).Magnitude
						local scale = math.clamp(70 / dist, 0.25, 1)

						if featureState.Name then
							local nameGui = head:FindFirstChild(NAME_TAG)
							if nameGui then
								nameGui.Size = UDim2.new(
									0,
									math.floor(NAME_BASE_W * scale),
									0,
									math.floor(NAME_BASE_H * scale)
								)
							end
						end

						if featureState.Health then
							local hpGui = root:FindFirstChild(HEALTH_TAG)
							if hpGui then
								hpGui.Size = UDim2.new(
									0,
									math.floor(HP_BASE_W * scale),
									0,
									math.floor(HP_BASE_H * scale)
								)
							end
						end
					end
				end
			end
		end
	end)
end

local function stopScaler()
	if scalerConn then
		scalerConn:Disconnect()
		scalerConn = nil
	end
end

------------------------------------------------------------------
-- SNAPLINES (FROM LOCAL FEET)
------------------------------------------------------------------

local snapLines: {[number]: any} = {}

local function clearSnaplines()
	for _, line in pairs(snapLines) do
		if line then
			pcall(function()
				line:Remove()
			end)
		end
	end
	table.clear(snapLines)
end

local function getLocalFeetWorldPos(): Vector3?
	local char = LocalPlayer.Character
	if not char then
		return nil
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")

	-- Preferred: root + hip height offset (works across rigs reasonably)
	if hum and root then
		return root.Position - Vector3.new(0, hum.HipHeight + (root.Size.Y * 0.5), 0)
	end

	-- Fallback: R15 foot parts
	local lf = char:FindFirstChild("LeftFoot")
	if lf and lf:IsA("BasePart") then
		return lf.Position
	end

	if root then
		return root.Position
	end

	return nil
end

local function enableSnaplines()
	clearSnaplines()

	if snaplineConn then
		snaplineConn:Disconnect()
		snaplineConn = nil
	end

	-- Defer one tick so camera/viewport/character are ready
	task.defer(function()
		if not featureState.Snaplines then
			return
		end

		snaplineConn = RunService.RenderStepped:Connect(function()
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end

			local vp = cam.ViewportSize
			if vp.X <= 1 or vp.Y <= 1 then
				return
			end

			local feetWorld = getLocalFeetWorldPos()
			if not feetWorld then
				return
			end

			local from3 = cam:WorldToViewportPoint(feetWorld)
			if from3.Z <= 0 then
				-- If your feet are behind the camera, lines will look weird; just hide them this frame.
				for _, line in pairs(snapLines) do
					if line then
						line.Visible = false
					end
				end
				return
			end

			local pad = 8
			local fromX = math.clamp(from3.X, pad, vp.X - pad)
			local fromY = math.clamp(from3.Y, pad, vp.Y - pad)
			local from2 = Vector2.new(fromX, fromY)

			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer then
					local char = plr.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")

					if not root or not hum or hum.Health <= 0 then
						local deadLine = snapLines[plr.UserId]
						if deadLine then
							deadLine.Visible = false
						end
						continue
					end

					local line = snapLines[plr.UserId]
					if not line then
						line = Drawing.new("Line")
						line.Thickness = 1
						line.Color = Color3.fromRGB(255, 0, 0)
						line.Transparency = 1
						snapLines[plr.UserId] = line
					end

					local to3 = cam:WorldToViewportPoint(root.Position)

					-- Behind camera mirror like your old logic
					if to3.Z < 0 then
						to3 = Vector3.new(
							vp.X - to3.X,
							vp.Y - to3.Y,
							to3.Z
						)
					end

					local toX = math.clamp(to3.X, pad, vp.X - pad)
					local toY = math.clamp(to3.Y, pad, vp.Y - pad)

					line.From = from2
					line.To = Vector2.new(toX, toY)
					line.Visible = true
				end
			end
		end)
	end)
end

local function disableSnaplines()
	if snaplineConn then
		snaplineConn:Disconnect()
		snaplineConn = nil
	end

	clearSnaplines()
end

------------------------------------------------------------------
-- APPLY LOGIC
------------------------------------------------------------------

local function refresh()
	cleanupAll()

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			if featureState.Name then buildName(plr) end
			if featureState.Health then buildHealth(plr) end
			if featureState.Player then buildGlow(plr) end
		end
	end

	if featureState.Name or featureState.Health then
		startScaler()
	else
		stopScaler()
	end
end

------------------------------------------------------------------
-- BIND TOGGLES
------------------------------------------------------------------

local function bind(feature: string, key: string)
	Toggles.Subscribe(key, function(state: boolean)
		featureState[feature] = state

		if feature == "Snaplines" then
			if state then
				enableSnaplines()
			else
				disableSnaplines()
			end
			return
		end

		refresh()
	end)

	-- Apply initial state immediately (not just saving it)
	if Toggles.GetState(key, false) then
		featureState[feature] = true

		if feature == "Snaplines" then
			enableSnaplines()
		else
			refresh()
		end
	end
end

bind("Name", KEYS.Name)
bind("Health", KEYS.Health)
bind("Player", KEYS.Player)
bind("Snaplines", KEYS.Snaplines)

refresh()
