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
-- SNAPLINES (3D WORLD BEAMS - FEET TO CHEST, FIRST-PERSON VISIBLE, NO TEXTURES)
------------------------------------------------------------------

local snapBeams: {[number]: {a1: Attachment, beam: Beam}} = {}
local snapOriginPart: BasePart? = nil
local snapOriginAttachment: Attachment? = nil

local FP_FORWARD_PUSH = 0.75
local FP_MIN_CAM_DIST = 1.35

local BEAM_W0 = 0.08
local BEAM_W1 = 0.06

local function clearSnaplines()
	for _, data in pairs(snapBeams) do
		if data.beam then data.beam:Destroy() end
		if data.a1 then data.a1:Destroy() end
	end
	table.clear(snapBeams)

	if snapOriginAttachment then
		snapOriginAttachment:Destroy()
		snapOriginAttachment = nil
	end

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

local function getChestPart(char: Model): BasePart?
	return (char:FindFirstChild("UpperTorso") :: BasePart?)
		or (char:FindFirstChild("Torso") :: BasePart?)
		or (char:FindFirstChild("HumanoidRootPart") :: BasePart?)
end

local function ensureOrigin()
	if snapOriginPart and snapOriginAttachment then
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

	local a0 = Instance.new("Attachment")
	a0.Name = "SnapFeet"
	a0.Position = Vector3.new(0, 0, 0)
	a0.Parent = p

	snapOriginPart = p
	snapOriginAttachment = a0
end

local function enableSnaplines()
	clearSnaplines()

	if snaplineConn then
		snaplineConn:Disconnect()
		snaplineConn = nil
	end

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

			if not snapOriginPart or not snapOriginAttachment then
				return
			end

			local localRoot, localHum = getLocalRootAndHum()
			if not localRoot or not localHum then
				for _, data in pairs(snapBeams) do
					data.beam.Enabled = false
				end
				return
			end

			local feetWorld = localRoot.Position - Vector3.new(0, localHum.HipHeight + (localRoot.Size.Y / 2), 0)

			local camPos = cam.CFrame.Position
			local distToFeet = (feetWorld - camPos).Magnitude

			local originWorld = feetWorld
			if distToFeet < FP_MIN_CAM_DIST then
				originWorld = feetWorld + (cam.CFrame.LookVector * FP_FORWARD_PUSH)
			end

			snapOriginPart.CFrame = CFrame.new(originWorld)

			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LocalPlayer then
					local char = plr.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local chest = char and getChestPart(char)

					if not chest or not hum or hum.Health <= 0 then
						local existing = snapBeams[plr.UserId]
						if existing then
							existing.beam.Enabled = false
						end
						continue
					end

					local data = snapBeams[plr.UserId]

					if not data then
						local a1 = Instance.new("Attachment")
						a1.Name = "SnapChest"
						a1.Position = Vector3.new(0, chest.Size.Y / 4, 0)
						a1.Parent = chest

						local beam = Instance.new("Beam")
						beam.Attachment0 = snapOriginAttachment
						beam.Attachment1 = a1

						beam.Width0 = BEAM_W0
						beam.Width1 = BEAM_W1
						beam.FaceCamera = true
						beam.LightEmission = 1
						beam.LightInfluence = 0
						beam.Transparency = NumberSequence.new(0)
						beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
						beam.Enabled = true
						beam.Parent = workspace

						snapBeams[plr.UserId] = {
							a1 = a1,
							beam = beam,
						}
					else
						if data.a1.Parent ~= chest then
							data.a1.Parent = chest
						end

						data.a1.Position = Vector3.new(0, chest.Size.Y / 4, 0)
						data.beam.Attachment0 = snapOriginAttachment
						data.beam.Enabled = true
					end
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
-- 3D BOXES (BEAMS AROUND MODEL:GetBoundingBox())
------------------------------------------------------------------

type BoxData = {
	part: BasePart,
	atts: {[string]: Attachment},
	beams: {Beam},
}

local boxDataByUserId: {[number]: BoxData} = {}

local BOX_W0 = 0.06
local BOX_W1 = 0.06

local boxRemoveConn: RBXScriptConnection? = nil

local function clearBoxes()
	for _, data in pairs(boxDataByUserId) do
		for _, b in ipairs(data.beams) do
			if b then b:Destroy() end
		end
		for _, a in pairs(data.atts) do
			if a then a:Destroy() end
		end
		if data.part then data.part:Destroy() end
	end
	table.clear(boxDataByUserId)
end

local function destroyBoxForUserId(userId: number)
	local data = boxDataByUserId[userId]
	if not data then return end

	for _, b in ipairs(data.beams) do
		if b then b:Destroy() end
	end
	for _, a in pairs(data.atts) do
		if a then a:Destroy() end
	end
	if data.part then data.part:Destroy() end

	boxDataByUserId[userId] = nil
end

local function makeCornerAttachments(parent: BasePart): {[string]: Attachment}
	local atts: {[string]: Attachment} = {}

	local function mk(name: string): Attachment
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = parent
		atts[name] = a
		return a
	end

	-- Naming: Axyz where x=0/1 for -/+ X, y=0/1 for -/+ Y, z=0/1 for -/+ Z
	mk("A000")
	mk("A001")
	mk("A010")
	mk("A011")
	mk("A100")
	mk("A101")
	mk("A110")
	mk("A111")

	return atts
end

local function mkBeam(a0: Attachment, a1: Attachment): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = BOX_W0
	beam.Width1 = BOX_W1
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new(0)
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
	beam.Enabled = true
	beam.Parent = workspace
	return beam
end

local function ensureBoxFor(plr: Player): BoxData
	local existing = boxDataByUserId[plr.UserId]
	if existing then
		return existing
	end

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

	local atts = makeCornerAttachments(p)

	local beams: {Beam} = {}

	-- 12 edges of a box:
	-- Bottom rectangle (Y-): A0y0z
	table.insert(beams, mkBeam(atts.A000, atts.A100))
	table.insert(beams, mkBeam(atts.A100, atts.A101))
	table.insert(beams, mkBeam(atts.A101, atts.A001))
	table.insert(beams, mkBeam(atts.A001, atts.A000))

	-- Top rectangle (Y+): A0y1z
	table.insert(beams, mkBeam(atts.A010, atts.A110))
	table.insert(beams, mkBeam(atts.A110, atts.A111))
	table.insert(beams, mkBeam(atts.A111, atts.A011))
	table.insert(beams, mkBeam(atts.A011, atts.A010))

	-- Vertical edges
	table.insert(beams, mkBeam(atts.A000, atts.A010))
	table.insert(beams, mkBeam(atts.A100, atts.A110))
	table.insert(beams, mkBeam(atts.A101, atts.A111))
	table.insert(beams, mkBeam(atts.A001, atts.A011))

	local data: BoxData = {
		part = p,
		atts = atts,
		beams = beams,
	}

	boxDataByUserId[plr.UserId] = data
	return data
end

local function setBoxEnabled(data: BoxData, enabled: boolean)
	for _, b in ipairs(data.beams) do
		b.Enabled = enabled
	end
end

local function updateBoxFor(plr: Player, data: BoxData)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then
		setBoxEnabled(data, false)
		return
	end

	local cf, size = char:GetBoundingBox()
	data.part.CFrame = cf

	local hx = size.X * 0.5
	local hy = size.Y * 0.5
	local hz = size.Z * 0.5

	-- corners in the part’s local space (since part.CFrame = bounding CF)
	-- x: -hx (0) / +hx (1)
	-- y: -hy (0) / +hy (1)
	-- z: -hz (0) / +hz (1)
	data.atts.A000.Position = Vector3.new(-hx, -hy, -hz)
	data.atts.A001.Position = Vector3.new(-hx, -hy,  hz)
	data.atts.A010.Position = Vector3.new(-hx,  hy, -hz)
	data.atts.A011.Position = Vector3.new(-hx,  hy,  hz)

	data.atts.A100.Position = Vector3.new( hx, -hy, -hz)
	data.atts.A101.Position = Vector3.new( hx, -hy,  hz)
	data.atts.A110.Position = Vector3.new( hx,  hy, -hz)
	data.atts.A111.Position = Vector3.new( hx,  hy,  hz)

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
