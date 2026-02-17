--!strict
-- AdminESP.lua
-- Toggle key expected: "visuals_adminesp"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local function getGlobal(): any
	local gg = (typeof(getgenv) == "function") and getgenv() or nil
	if gg then
		return gg
	end
	return _G
end

local G = getGlobal()
local TOGGLE_KEY = "visuals_adminesp"

-- wait for toggle API
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
-- CONFIG
------------------------------------------------------------------

local NAME_TAG = "AdminTag"
local HEALTH_TAG = "AdminHealthBar"
local GLOW_TAG = "AdminGlow"

local MAX_DISTANCE = 500

local NAME_BASE_W, NAME_BASE_H = 90, 22
local HP_BASE_W, HP_BASE_H = 70, 8

------------------------------------------------------------------
-- INTERNAL STATE
------------------------------------------------------------------

local enabled = false
local playerConns: {[number]: {RBXScriptConnection}} = {}
local scalerConn: RBXScriptConnection? = nil

------------------------------------------------------------------
-- UTIL
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
			if inst.Name == NAME_TAG or inst.Name == HEALTH_TAG or inst.Name == GLOW_TAG then
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

	if scalerConn then
		scalerConn:Disconnect()
		scalerConn = nil
	end
end

------------------------------------------------------------------
-- BUILD ESP
------------------------------------------------------------------

local function buildESP(plr: Player)
	if plr == LocalPlayer then return end
	local char = plr.Character
	if not char then return end

	local head = char:FindFirstChild("Head")
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not head or not root or not hum then return end

	-- NAME
	if not head:FindFirstChild(NAME_TAG) then
		local bill = Instance.new("BillboardGui")
		bill.Name = NAME_TAG
		bill.AlwaysOnTop = true
		bill.MaxDistance = MAX_DISTANCE
		bill.StudsOffset = Vector3.new(0, 2.9, 0)
		bill.Size = UDim2.new(0, NAME_BASE_W, 0, NAME_BASE_H)
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

	-- HEALTH
	if not root:FindFirstChild(HEALTH_TAG) then
		local bill = Instance.new("BillboardGui")
		bill.Name = HEALTH_TAG
		bill.AlwaysOnTop = true
		bill.MaxDistance = MAX_DISTANCE
		bill.StudsOffset = Vector3.new(0, -3.2, 0)
		bill.Size = UDim2.new(0, HP_BASE_W, 0, HP_BASE_H)
		bill.Parent = root

		local back = Instance.new("Frame")
		back.Size = UDim2.new(1,0,1,0)
		back.BackgroundColor3 = Color3.fromRGB(25,25,25)
		back.BorderSizePixel = 0
		back.Parent = bill

		local fill = Instance.new("Frame")
		fill.Name = "HealthFill"
		fill.Size = UDim2.new(1,0,1,0)
		fill.BackgroundColor3 = Color3.fromRGB(80,255,120)
		fill.BorderSizePixel = 0
		fill.Parent = back

		local function update()
			local pct = 0
			if hum.MaxHealth > 0 then
				pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
			end
			fill.Size = UDim2.new(pct,0,1,0)
			fill.BackgroundColor3 = Color3.fromRGB(255*(1-pct),255*pct,60)
		end

		update()

		local healthConn = hum.HealthChanged:Connect(update)

		playerConns[plr.UserId] = playerConns[plr.UserId] or {}
		table.insert(playerConns[plr.UserId], healthConn)
	end

	-- GLOW
	if not char:FindFirstChild(GLOW_TAG) then
		local h = Instance.new("Highlight")
		h.Name = GLOW_TAG
		h.FillColor = Color3.fromRGB(255,0,0)
		h.FillTransparency = 0.6
		h.OutlineTransparency = 0.2
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = char
	end
end

------------------------------------------------------------------
-- ENABLE / DISABLE
------------------------------------------------------------------

local function enable()
	if enabled then return end
	enabled = true

	for _, plr in ipairs(Players:GetPlayers()) do
		buildESP(plr)
	end

	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(function()
			task.wait(0.2)
			if enabled then
				buildESP(plr)
			end
		end)
	end)

	-- scaling loop
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

						local nameGui = head:FindFirstChild(NAME_TAG)
						if nameGui then
							nameGui.Size = UDim2.new(0, math.floor(NAME_BASE_W * scale), 0, math.floor(NAME_BASE_H * scale))
						end

						local hpGui = root:FindFirstChild(HEALTH_TAG)
						if hpGui then
							hpGui.Size = UDim2.new(0, math.floor(HP_BASE_W * scale), 0, math.floor(HP_BASE_H * scale))
						end
					end
				end
			end
		end
	end)

	print("[AdminESP] enabled")
end

local function disable()
	if not enabled then return end
	enabled = false
	cleanupAll()
	print("[AdminESP] disabled")
end

------------------------------------------------------------------
-- TOGGLE BINDING
------------------------------------------------------------------

Toggles.Subscribe(TOGGLE_KEY, function(state: boolean)
	if state then
		enable()
	else
		disable()
	end
end)

if Toggles.GetState(TOGGLE_KEY, false) then
	enable()
end
