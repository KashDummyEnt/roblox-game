--!strict
-- AdminESP.lua
-- Multi-toggle ESP with proper distance scaling + snaplines from local feet (not screen center)
-- + 3D Beam Boxes (bounding-box based)

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
	Box3D = "visuals_box3d",
}

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------

local NAME_TAG = "ESP_Name"
local HEALTH_TAG = "ESP_Health"
local GLOW_TAG = "ESP_Glow"

local NAME_BASE_W, NAME_BASE_H = 90, 22
local HP_BASE_W, HP_BASE_H = 70, 8
local NAME_MIN_W, NAME_MIN_H = 50, 14
local HP_MIN_W, HP_MIN_H = 40, 6


local MAX_DISTANCE = 500

------------------------------------------------------------------
-- STATE
------------------------------------------------------------------

local featureState = {
	Name = false,
	Health = false,
	Player = false,
	Snaplines = false,
	Box3D = false,
}

local playerConns: {[number]: {RBXScriptConnection}} = {}
local scalerConn: RBXScriptConnection? = nil
local snaplineConn: RBXScriptConnection? = nil
local boxConn: RBXScriptConnection? = nil

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

	-- center / fill
	h.FillColor = Color3.fromRGB(255, 40, 40)
	h.FillTransparency = 0.7

	-- outline
	h.OutlineColor = Color3.fromRGB(255, 255, 255)
	h.OutlineTransparency = 0.1

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

						-- smoother scaling (no forced 0.25 floor anymore)
						local scale = math.clamp(70 / dist, 0, 1)

						------------------------------------------------------------------
						-- NAME SCALING (WITH MIN SIZE)
						------------------------------------------------------------------
						if featureState.Name then
							local nameGui = head:FindFirstChild(NAME_TAG)
							if nameGui then
								local w = math.floor(NAME_BASE_W * scale)
								local h = math.floor(NAME_BASE_H * scale)

								w = math.max(w, NAME_MIN_W)
								h = math.max(h, NAME_MIN_H)

								nameGui.Size = UDim2.new(0, w, 0, h)
							end
						end

						------------------------------------------------------------------
						-- HEALTHBAR SCALING (WITH MIN SIZE)
						------------------------------------------------------------------
						if featureState.Health then
							local hpGui = root:FindFirstChild(HEALTH_TAG)
							if hpGui then
								local w = math.floor(HP_BASE_W * scale)
								local h = math.floor(HP_BASE_H * scale)

								w = math.max(w, HP_MIN_W)
								h = math.max(h, HP_MIN_H)

								hpGui.Size = UDim2.new(0, w, 0, h)
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
-- SNAPLINES (BOXHANDLEADORNMENT "RODS" - FEET TO FEET, THROUGH WALLS)
------------------------------------------------------------------

type SnapData = {
	part: BasePart,
	ad: BoxHandleAdornment,
}

local snapDataByUserId: {[number]: SnapData} = {}
local snapOriginPart: BasePart? = nil

local FP_FORWARD_PUSH = 0.75
local FP_MIN_CAM_DIST = 1.35

local SNAP_THICKNESS = 0.10
local SNAP_TRANSPARENCY = 0.15

local snapRemoveConn: RBXScriptConnection? = nil

local function destroySnapForUserId(userId: number)
	local data = snapDataByUserId[userId]
	if not data then return end

	if data.ad then data.ad:Destroy() end
	if data.part then data.part:Destroy() end

	snapDataByUserId[userId] = nil
end

local function clearSnaplines()
	for userId, _ in pairs(snapDataByUserId) do
		destroySnapForUserId(userId)
	end
	table.clear(snapDataByUserId)

	if snapOriginPart then
		snapOriginPart:Destroy()
		snapOriginPart = nil
	end
end

local function getLocalRootAndHum(): (BasePart?, Humanoid?)
	local char = LocalPlayer.Character
	if not char then return nil, nil end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	return root, hum
end

local function getFeetWorld(root: BasePart, hum: Humanoid): Vector3
	return root.Position - Vector3.new(0, hum.HipHeight + (root.Size.Y / 2), 0)
end

local function ensureOrigin()
	if snapOriginPart then
		return
	end

	local p = Instance.new("Part")
	p.Name = "SnapOrigin"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Parent = workspace

	snapOriginPart = p
end

local function ensureSnapFor(plr: Player): SnapData
	local existing = snapDataByUserId[plr.UserId]
	if existing then
		return existing
	end

	local p = Instance.new("Part")
	p.Name = ("ESP_SnapRod_%d"):format(plr.UserId)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Parent = workspace

	local ad = Instance.new("BoxHandleAdornment")
	ad.Name = "ESP_SnapAdornment"
	ad.Adornee = p
	ad.AlwaysOnTop = true
	ad.ZIndex = 10

	ad.Color3 = Color3.fromRGB(255, 0, 0)
	ad.Transparency = SNAP_TRANSPARENCY
	ad.AdornCullingMode = Enum.AdornCullingMode.Automatic
	ad.Visible = true

	ad.Parent = workspace

	local data: SnapData = {
		part = p,
		ad = ad,
	}

	snapDataByUserId[plr.UserId] = data
	return data
end

local function setSnapEnabled(data: SnapData, enabled: boolean)
	data.ad.Visible = enabled
end

local function updateSnapFor(plr: Player, data: SnapData, originWorld: Vector3)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and (char:FindFirstChild("HumanoidRootPart") :: BasePart?)

	if not root or not hum or hum.Health <= 0 then
		setSnapEnabled(data, false)
		return
	end

	-- feet-to-feet target
	local targetFeet = getFeetWorld(root, hum)

	-- build a "rod" from origin to target
	local dir = targetFeet - originWorld
	local len = dir.Magnitude
	if len < 0.05 then
		setSnapEnabled(data, false)
		return
	end

	local mid = originWorld + (dir * 0.5)

	-- orient so Z axis points toward target
	data.part.CFrame = CFrame.lookAt(mid, targetFeet)

	-- thin box stretched along Z
	data.ad.Size = Vector3.new(SNAP_THICKNESS, SNAP_THICKNESS, len)
	setSnapEnabled(data, true)
end

local function enableSnaplines()
	clearSnaplines()

	if snaplineConn then
		snaplineConn:Disconnect()
		snaplineConn = nil
	end

	if snapRemoveConn then
		snapRemoveConn:Disconnect()
		snapRemoveConn = nil
	end

	snapRemoveConn = Players.PlayerRemoving:Connect(function(plr: Player)
		destroySnapForUserId(plr.UserId)
	end)

	task.defer(function()
		if not featureState.Snaplines then
			return
		end

		ensureOrigin()

		snaplineConn = RunService.RenderStepped:Connect(function()
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end

			if not snapOriginPart then
				return
			end

			local localRoot, localHum = getLocalRootAndHum()
			if not localRoot or not localHum then
				for _, data in pairs(snapDataByUserId) do
					setSnapEnabled(data, false)
				end
				return
			end

			-- local feet origin
			local feetWorld = getFeetWorld(localRoot, localHum)

			-- anti-clip in true first-person
			local camPos = cam.CFrame.Position
			local distToFeet = (feetWorld - camPos).Magnitude

			local originWorld = feetWorld
			if distToFeet < FP_MIN_CAM_DIST then
				originWorld = feetWorld + (cam.CFrame.LookVector * FP_FORWARD_PUSH)
			end

			snapOriginPart.CFrame = CFrame.new(originWorld)

			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer then
					local data = ensureSnapFor(plr)
					updateSnapFor(plr, data, originWorld)
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

	if snapRemoveConn then
		snapRemoveConn:Disconnect()
		snapRemoveConn = nil
	end

	clearSnaplines()
end

------------------------------------------------------------------
-- 3D BOXES (BOXHANDLEADORNMENT AROUND MODEL:GetBoundingBox())
-- Through-walls via AlwaysOnTop
------------------------------------------------------------------

type BoxData = {
	part: BasePart,
	ad: BoxHandleAdornment,
}

local boxDataByUserId: {[number]: BoxData} = {}

local boxRemoveConn: RBXScriptConnection? = nil

local function destroyBoxForUserId(userId: number)
	local data = boxDataByUserId[userId]
	if not data then return end

	if data.ad then data.ad:Destroy() end
	if data.part then data.part:Destroy() end

	boxDataByUserId[userId] = nil
end

local function clearBoxes()
	for userId, _ in pairs(boxDataByUserId) do
		destroyBoxForUserId(userId)
	end
	table.clear(boxDataByUserId)
end

local function ensureBoxFor(plr: Player): BoxData
	local existing = boxDataByUserId[plr.UserId]
	if existing then
		return existing
	end

	-- Invisible holder part that we move to the boundingbox CFrame
	local p = Instance.new("Part")
	p.Name = ("ESP_Box3D_%d"):format(plr.UserId)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Parent = workspace

	local ad = Instance.new("BoxHandleAdornment")
	ad.Name = "ESP_BoxAdornment"
	ad.Adornee = p
	ad.AlwaysOnTop = true
	ad.ZIndex = 10

	-- This is the line thickness
	ad.SizeRelativeOffset = Vector3.new(0, 0, 0)
	ad.Transparency = 0.6
	ad.Color3 = Color3.fromRGB(170, 0, 255)

	-- Wireframe look
	ad.AlwaysOnTop = true

	-- You can swap to Enum.AdornCullingMode.Never if you want it to never cull
	ad.AdornCullingMode = Enum.AdornCullingMode.Automatic

	ad.Parent = workspace

	local data: BoxData = {
		part = p,
		ad = ad,
	}

	boxDataByUserId[plr.UserId] = data
	return data
end

local function setBoxEnabled(data: BoxData, enabled: boolean)
	if data.ad then
		data.ad.Visible = enabled
	end
end

local function computeHitboxOBB(char: Model): (CFrame?, Vector3?)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, nil
	end

	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)

	local found = false
	local rootCF = root.CFrame

	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("BasePart") then
			local part = inst :: BasePart

			-- Skip obvious accessory handles
			if part.Name == "Handle" and part.Parent and part.Parent:IsA("Accessory") then
				continue
			end

			-- Use CanQuery as “can be hit by raycasts”
			if not part.CanQuery then
				continue
			end

			-- Transform the part into root-local space so the box is oriented with the character
			local rel = rootCF:ToObjectSpace(part.CFrame)
			local sx = part.Size.X * 0.5
			local sy = part.Size.Y * 0.5
			local sz = part.Size.Z * 0.5

			-- 8 corners of the part in root-local space
			local corners = {
				(rel * CFrame.new(-sx, -sy, -sz)).Position,
				(rel * CFrame.new(-sx, -sy,  sz)).Position,
				(rel * CFrame.new(-sx,  sy, -sz)).Position,
				(rel * CFrame.new(-sx,  sy,  sz)).Position,
				(rel * CFrame.new( sx, -sy, -sz)).Position,
				(rel * CFrame.new( sx, -sy,  sz)).Position,
				(rel * CFrame.new( sx,  sy, -sz)).Position,
				(rel * CFrame.new( sx,  sy,  sz)).Position,
			}

			for _, p in ipairs(corners) do
				minV = Vector3.new(
					math.min(minV.X, p.X),
					math.min(minV.Y, p.Y),
					math.min(minV.Z, p.Z)
				)
				maxV = Vector3.new(
					math.max(maxV.X, p.X),
					math.max(maxV.Y, p.Y),
					math.max(maxV.Z, p.Z)
				)
			end

			found = true
		end
	end

	if not found then
		return nil, nil
	end

	local size = maxV - minV
	local centerLocal = (minV + maxV) * 0.5

	-- World-space oriented box aligned to HumanoidRootPart
	local cf = rootCF * CFrame.new(centerLocal)
	return cf, size
end

local function updateBoxFor(plr: Player, data: BoxData)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		setBoxEnabled(data, false)
		return
	end

	local cf, size = computeHitboxOBB(char)
	if not cf or not size then
		setBoxEnabled(data, false)
		return
	end

	data.part.CFrame = cf
	data.ad.Size = size
	setBoxEnabled(data, true)
end


local function enableBoxes()
	clearBoxes()

	if boxConn then
		boxConn:Disconnect()
		boxConn = nil
	end

	if boxRemoveConn then
		boxRemoveConn:Disconnect()
		boxRemoveConn = nil
	end

	boxRemoveConn = Players.PlayerRemoving:Connect(function(plr: Player)
		destroyBoxForUserId(plr.UserId)
	end)

	task.defer(function()
		if not featureState.Box3D then
			return
		end

		boxConn = RunService.RenderStepped:Connect(function()
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer then
					local data = ensureBoxFor(plr)
					updateBoxFor(plr, data)
				end
			end
		end)
	end)
end

local function disableBoxes()
	if boxConn then
		boxConn:Disconnect()
		boxConn = nil
	end

	if boxRemoveConn then
		boxRemoveConn:Disconnect()
		boxRemoveConn = nil
	end

	clearBoxes()
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

		if feature == "Box3D" then
			if state then
				enableBoxes()
			else
				disableBoxes()
			end
			return
		end

		refresh()
	end)

	if Toggles.GetState(key, false) then
		featureState[feature] = true

		if feature == "Snaplines" then
			enableSnaplines()
		elseif feature == "Box3D" then
			enableBoxes()
		else
			refresh()
		end
	end
end

bind("Name", KEYS.Name)
bind("Health", KEYS.Health)
bind("Player", KEYS.Player)
bind("Snaplines", KEYS.Snaplines)
bind("Box3D", KEYS.Box3D)

refresh()
