--!strict
-- AdminESP.lua
-- Full 3D ESP System (Name, Health, Highlight, Snaplines, Boxes)

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
	Boxes = "visuals_boxes",
}

------------------------------------------------------------------
-- STATE
------------------------------------------------------------------

local featureState = {
	Name = false,
	Health = false,
	Player = false,
	Snaplines = false,
	Boxes = false,
}

------------------------------------------------------------------
-- NAME ESP
------------------------------------------------------------------

local NAME_TAG = "ESP_Name"

local function buildName(plr: Player)
	local char = plr.Character
	if not char then return end
	local head = char:FindFirstChild("Head")
	if not head then return end
	if head:FindFirstChild(NAME_TAG) then return end

	local bill = Instance.new("BillboardGui")
	bill.Name = NAME_TAG
	bill.AlwaysOnTop = true
	bill.Size = UDim2.new(0, 90, 0, 22)
	bill.StudsOffset = Vector3.new(0, 2.8, 0)
	bill.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1,0,1,0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255,70,70)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Font = Enum.Font.GothamSemibold
	label.Text = plr.DisplayName
	label.Parent = bill
end

------------------------------------------------------------------
-- HEALTH ESP
------------------------------------------------------------------

local HEALTH_TAG = "ESP_Health"

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
	bill.Size = UDim2.new(0, 70, 0, 8)
	bill.StudsOffset = Vector3.new(0, -3.2, 0)
	bill.Parent = root

	local back = Instance.new("Frame")
	back.Size = UDim2.new(1,0,1,0)
	back.BackgroundColor3 = Color3.fromRGB(25,25,25)
	back.BorderSizePixel = 0
	back.Parent = bill

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1,0,1,0)
	fill.BorderSizePixel = 0
	fill.Parent = back

	local function update()
		local pct = hum.Health / hum.MaxHealth
		pct = math.clamp(pct, 0, 1)
		fill.Size = UDim2.new(pct,0,1,0)
		fill.BackgroundColor3 = Color3.fromRGB(255*(1-pct),255*pct,60)
	end

	update()
	hum.HealthChanged:Connect(update)
end

------------------------------------------------------------------
-- HIGHLIGHT (CHAMS)
------------------------------------------------------------------

local GLOW_TAG = "ESP_Glow"

local function buildGlow(plr: Player)
	local char = plr.Character
	if not char then return end
	if char:FindFirstChild(GLOW_TAG) then return end

	local h = Instance.new("Highlight")
	h.Name = GLOW_TAG
	h.FillColor = Color3.fromRGB(255,0,0)
	h.FillTransparency = 0.6
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = char
end

------------------------------------------------------------------
-- SNAPLINES (3D FEET → CHEST)
------------------------------------------------------------------

local snapBeams: {[number]: {beam: Beam, a1: Attachment}} = {}
local originPart: BasePart? = nil
local originAttachment: Attachment? = nil
local snapConn: RBXScriptConnection? = nil

local function clearSnap()
	for _, data in pairs(snapBeams) do
		data.beam:Destroy()
		data.a1:Destroy()
	end
	table.clear(snapBeams)
	if originPart then originPart:Destroy() end
	originPart = nil
	originAttachment = nil
end

local function ensureOrigin()
	if originPart then return end

	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2,0.2,0.2)
	p.Parent = workspace

	local a = Instance.new("Attachment")
	a.Parent = p

	originPart = p
	originAttachment = a
end

local function enableSnap()
	clearSnap()
	ensureOrigin()

	snapConn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end

		local char = LocalPlayer.Character
		if not char then return end

		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then return end

		local feet = root.Position - Vector3.new(0, hum.HipHeight + root.Size.Y/2, 0)
		originPart.CFrame = CFrame.new(feet)

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local c = plr.Character
				local h = c and c:FindFirstChildOfClass("Humanoid")
				local chest = c and (c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart"))
				if not chest or not h or h.Health <= 0 then continue end

				if not snapBeams[plr.UserId] then
					local a1 = Instance.new("Attachment")
					a1.Position = Vector3.new(0, chest.Size.Y/4, 0)
					a1.Parent = chest

					local beam = Instance.new("Beam")
					beam.Attachment0 = originAttachment
					beam.Attachment1 = a1
					beam.Width0 = 0.08
					beam.Width1 = 0.06
					beam.FaceCamera = true
					beam.LightEmission = 1
					beam.LightInfluence = 0
					beam.Transparency = NumberSequence.new(0)
					beam.Color = ColorSequence.new(Color3.fromRGB(255,0,0))
					beam.Parent = workspace

					snapBeams[plr.UserId] = {beam=beam,a1=a1}
				end
			end
		end
	end)
end

local function disableSnap()
	if snapConn then snapConn:Disconnect() end
	clearSnap()
end

------------------------------------------------------------------
-- BOXES (3D WIREFRAME)
------------------------------------------------------------------

local boxData: {[number]: {attachments:{Attachment}, beams:{Beam}}} = {}
local boxConn: RBXScriptConnection? = nil

local function clearBoxes()
	for _, data in pairs(boxData) do
		for _, b in ipairs(data.beams) do b:Destroy() end
		for _, a in ipairs(data.attachments) do a:Destroy() end
	end
	table.clear(boxData)
end

local function createBox(plr: Player)
	local char = plr.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local w,h,d = 4,6,2
	local hw,hd = w/2,d/2

	local offsets = {
		Vector3.new(-hw,0,-hd), Vector3.new(hw,0,-hd),
		Vector3.new(hw,0,hd), Vector3.new(-hw,0,hd),
		Vector3.new(-hw,h,-hd), Vector3.new(hw,h,-hd),
		Vector3.new(hw,h,hd), Vector3.new(-hw,h,hd),
	}

	local atts = {}
	for i=1,8 do
		local a=Instance.new("Attachment")
		a.Position=offsets[i]
		a.Parent=root
		table.insert(atts,a)
	end

	local edges={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
	local beams={}

	for _,e in ipairs(edges) do
		local beam=Instance.new("Beam")
		beam.Attachment0=atts[e[1]]
		beam.Attachment1=atts[e[2]]
		beam.Width0=0.05
		beam.Width1=0.05
		beam.FaceCamera=true
		beam.LightEmission=1
		beam.LightInfluence=0
		beam.Color=ColorSequence.new(Color3.fromRGB(255,0,0))
		beam.Transparency=NumberSequence.new(0)
		beam.Parent=workspace
		table.insert(beams,beam)
	end

	boxData[plr.UserId]={attachments=atts,beams=beams}
end

local function enableBoxes()
	clearBoxes()
	boxConn=RunService.RenderStepped:Connect(function()
		for _,plr in ipairs(Players:GetPlayers()) do
			if plr~=LocalPlayer then
				local c=plr.Character
				local h=c and c:FindFirstChildOfClass("Humanoid")
				if not c or not h or h.Health<=0 then continue end
				if not boxData[plr.UserId] then
					createBox(plr)
				end
			end
		end
	end)
end

local function disableBoxes()
	if boxConn then boxConn:Disconnect() end
	clearBoxes()
end

------------------------------------------------------------------
-- REFRESH
------------------------------------------------------------------

local function refresh()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			if featureState.Name then buildName(plr) end
			if featureState.Health then buildHealth(plr) end
			if featureState.Player then buildGlow(plr) end
		end
	end
end

------------------------------------------------------------------
-- BIND TOGGLES
------------------------------------------------------------------

local function bind(feature:string,key:string)
	Toggles.Subscribe(key,function(state:boolean)
		featureState[feature]=state

		if feature=="Snaplines" then
			if state then enableSnap() else disableSnap() end
			return
		end

		if feature=="Boxes" then
			if state then enableBoxes() else disableBoxes() end
			return
		end

		refresh()
	end)
end

bind("Name",KEYS.Name)
bind("Health",KEYS.Health)
bind("Player",KEYS.Player)
bind("Snaplines",KEYS.Snaplines)
bind("Boxes",KEYS.Boxes)

refresh()
