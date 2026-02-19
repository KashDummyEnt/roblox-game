--!strict
-- NPCSelector.lua
-- Finds Model children in workspace.NPCs and injects a 1-at-a-time selector into Higgi's Menu.
-- If no NPCs are found, it does nothing (no UI, no error).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------
-- GLOBAL API (shared like your toggles)
------------------------------------------------------------------
local function getGlobal(): any
	local gg = (typeof(getgenv) == "function") and getgenv() or nil
	if gg then
		return gg
	end
	return _G
end

local G = getGlobal()

G.__HIGGI_NPC_SELECTOR = G.__HIGGI_NPC_SELECTOR or {}
local API = G.__HIGGI_NPC_SELECTOR

------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------
local GUI_NAME = "PopupMenuGui"
local POPUP_NAME = "PopupPanel"
local TARGET_PAGE_NAME = "Main" -- change to "World" / "Visuals" / etc if you want

local CARD_NAME = "NPCSelectorCard"
local CARD_ORDER = 2 -- layout order inside the page

------------------------------------------------------------------
-- UTIL
------------------------------------------------------------------
local function waitForChild(parent: Instance, name: string, timeout: number): Instance?
	local start = os.clock()
	while os.clock() - start < timeout do
		local f = parent:FindFirstChild(name)
		if f then
			return f
		end
		task.wait(0.05)
	end
	return nil
end

local function make(instanceType: string, props: {[string]: any}?): Instance
	local inst = Instance.new(instanceType)
	if props then
		for k, v in pairs(props) do
			(inst :: any)[k] = v
		end
	end
	return inst
end

local function addCorner(parent: Instance, radius: number)
	make("UICorner", {
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	})
end

local function addStroke(parent: Instance, thickness: number, color: Color3, transparency: number?)
	make("UIStroke", {
		Thickness = thickness,
		Color = color,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

------------------------------------------------------------------
-- FIND MENU PAGE + CONFIG COLORS (pull from existing UI so it matches)
------------------------------------------------------------------
type UiRefs = {
	Page: ScrollingFrame,
	Config: {
		Bg2: Color3,
		Bg3: Color3,
		Text: Color3,
		SubText: Color3,
		Stroke: Color3,
		Accent: Color3,
	},
}

local function resolveMenu(): UiRefs?
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end

	local screenGui = pg:FindFirstChild(GUI_NAME)
	if not screenGui then
		return nil
	end

	local popup = screenGui:FindFirstChild(POPUP_NAME)
	if not popup then
		return nil
	end

	local body = popup:FindFirstChild("Body")
	if not body then
		return nil
	end

	local pages = body:FindFirstChild("Pages")
	if not pages then
		return nil
	end

	local page = pages:FindFirstChild(TARGET_PAGE_NAME)
	if not page then
		return nil
	end

	local pageSf = page :: ScrollingFrame

	-- Try to sniff colors from sidebar buttons/cards so we match theme,
	-- fallback to sane defaults.
	local fallback = {
		Bg2 = Color3.fromRGB(20, 20, 24),
		Bg3 = Color3.fromRGB(26, 26, 32),
		Text = Color3.fromRGB(240, 240, 244),
		SubText = Color3.fromRGB(170, 170, 180),
		Stroke = Color3.fromRGB(55, 55, 65),
		Accent = Color3.fromRGB(253, 55, 0),
	}

	local cfg = fallback

	local anyCard = pageSf:FindFirstChildWhichIsA("Frame")
	if anyCard then
		local stroke = anyCard:FindFirstChildOfClass("UIStroke")
		if stroke then
			cfg.Stroke = (stroke :: UIStroke).Color
		end
		cfg.Bg2 = (anyCard :: Frame).BackgroundColor3
	end

	return {
		Page = pageSf,
		Config = cfg,
	}
end

------------------------------------------------------------------
-- NPC LISTING
------------------------------------------------------------------
local function getNpcFolder(): Instance?
	return workspace:FindFirstChild("NPCs")
end

local function collectNpcModels(): {Model}
	local folder = getNpcFolder()
	if not folder then
		return {}
	end

	local out: {Model} = {}
	for _, ch in ipairs(folder:GetChildren()) do
		if ch:IsA("Model") then
			table.insert(out, ch :: Model)
		end
	end

	table.sort(out, function(a: Model, b: Model)
		return a.Name:lower() < b.Name:lower()
	end)

	return out
end

------------------------------------------------------------------
-- UI BUILD
------------------------------------------------------------------
type SelectorUi = {
	Root: Frame,
	NameLabel: TextLabel,
	Prev: TextButton,
	Next: TextButton,
	SubLabel: TextLabel,
}

local ui: SelectorUi? = nil
local npcList: {Model} = {}
local index: number = 1

local function destroyExistingCard(page: ScrollingFrame)
	local existing = page:FindFirstChild(CARD_NAME)
	if existing then
		existing:Destroy()
	end
end

local function updateLabel()
	if not ui then
		return
	end

	if #npcList <= 0 then
		ui.Root.Visible = false
		return
	end

	ui.Root.Visible = true
	index = math.clamp(index, 1, #npcList)

	local m = npcList[index]
	ui.NameLabel.Text = m.Name

	ui.SubLabel.Text = ("NPC %d / %d"):format(index, #npcList)
	ui.Prev.Active = (#npcList > 1)
	ui.Next.Active = (#npcList > 1)
	ui.Prev.AutoButtonColor = false
	ui.Next.AutoButtonColor = false
end

local function buildCard(refs: UiRefs)
	local page = refs.Page
	local cfg = refs.Config

	destroyExistingCard(page)

	local card = make("Frame", {
		Name = CARD_NAME,
		BackgroundColor3 = cfg.Bg2,
		Size = UDim2.new(1, 0, 0, 76),
		ZIndex = 43,
		LayoutOrder = CARD_ORDER,
		Parent = page,
	}) :: Frame
	addCorner(card, 12)
	addStroke(card, 1, cfg.Stroke, 0.35)

	local title = make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Text = "NPC Selector",
		TextColor3 = cfg.Text,
		TextSize = 15,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.new(0, 10, 0, 8),
		ZIndex = 44,
		Parent = card,
	}) :: TextLabel

	local sub = make("TextLabel", {
		Name = "Sub",
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = cfg.SubText,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.new(0, 10, 0, 28),
		ZIndex = 44,
		Parent = card,
	}) :: TextLabel

	local prevBtn = make("TextButton", {
		Name = "Prev",
		AutoButtonColor = false,
		Text = "<",
		TextColor3 = cfg.Text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		BackgroundColor3 = cfg.Bg3,
		Size = UDim2.fromOffset(34, 28),
		Position = UDim2.new(1, -14 - 34 - 34 - 10 - 170, 0, 40),
		ZIndex = 45,
		Parent = card,
	}) :: TextButton
	addCorner(prevBtn, 10)
	addStroke(prevBtn, 1, cfg.Stroke, 0.25)

	local nextBtn = make("TextButton", {
		Name = "Next",
		AutoButtonColor = false,
		Text = ">",
		TextColor3 = cfg.Text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		BackgroundColor3 = cfg.Bg3,
		Size = UDim2.fromOffset(34, 28),
		Position = UDim2.new(1, -14 - 34, 0, 40),
		ZIndex = 45,
		Parent = card,
	}) :: TextButton
	addCorner(nextBtn, 10)
	addStroke(nextBtn, 1, cfg.Stroke, 0.25)

	local nameBox = make("Frame", {
		Name = "NameBox",
		BackgroundColor3 = cfg.Bg3,
		Size = UDim2.new(0, 170, 0, 28),
		Position = UDim2.new(1, -14 - 34 - 10 - 170, 0, 40),
		ZIndex = 44,
		Parent = card,
	}) :: Frame
	addCorner(nameBox, 10)
	addStroke(nameBox, 1, cfg.Stroke, 0.25)

	-- shift namebox between prev/next
	nameBox.Position = UDim2.new(1, -14 - 34 - 10 - 170 - 34 - 10, 0, 40)

	local nameLbl = make("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = cfg.Text,
		TextSize = 14,
		Font = Enum.Font.GothamSemibold,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.new(0, 6, 0, 0),
		ZIndex = 45,
		Parent = nameBox,
	}) :: TextLabel

	-- button interactions
	local function hover(btn: TextButton, over: boolean)
		btn.BackgroundColor3 = over and cfg.Bg2 or cfg.Bg3
	end

	prevBtn.MouseEnter:Connect(function() hover(prevBtn, true) end)
	prevBtn.MouseLeave:Connect(function() hover(prevBtn, false) end)
	nextBtn.MouseEnter:Connect(function() hover(nextBtn, true) end)
	nextBtn.MouseLeave:Connect(function() hover(nextBtn, false) end)

	prevBtn.MouseButton1Click:Connect(function()
		if #npcList <= 0 then
			return
		end
		index -= 1
		if index < 1 then
			index = #npcList
		end
		updateLabel()
	end)

	nextBtn.MouseButton1Click:Connect(function()
		if #npcList <= 0 then
			return
		end
		index += 1
		if index > #npcList then
			index = 1
		end
		updateLabel()
	end)

	ui = {
		Root = card,
		NameLabel = nameLbl,
		Prev = prevBtn,
		Next = nextBtn,
		SubLabel = sub,
	}

	-- If list is empty, hide card (your requirement)
	card.Visible = false
end

------------------------------------------------------------------
-- PUBLIC API
------------------------------------------------------------------
function API.GetSelectedName(): string?
	if #npcList <= 0 then
		return nil
	end
	index = math.clamp(index, 1, #npcList)
	return npcList[index].Name
end

function API.GetSelectedModel(): Model?
	if #npcList <= 0 then
		return nil
	end
	index = math.clamp(index, 1, #npcList)
	local m = npcList[index]
	if m and m.Parent then
		return m
	end
	return nil
end

function API.Refresh()
	npcList = collectNpcModels()
	if #npcList <= 0 then
		-- Hide UI if it exists, otherwise do nothing
		if ui then
			ui.Root.Visible = false
		end
		return
	end

	-- clamp index and update UI
	index = math.clamp(index, 1, #npcList)
	updateLabel()
end

------------------------------------------------------------------
-- MAIN
------------------------------------------------------------------
-- wait a bit for menu to exist, but don't hard-fail
local refs: UiRefs? = nil

local function tryAttach(): boolean
	local r = resolveMenu()
	if not r then
		return false
	end

	-- Build initial list
	npcList = collectNpcModels()
	if #npcList <= 0 then
		-- Nothing found => don't list anything, don't build UI
		return true
	end

	buildCard(r)
	updateLabel()

	-- Watch NPC folder changes to keep the list fresh
	local folder = getNpcFolder()
	if folder then
		folder.ChildAdded:Connect(function()
			API.Refresh()
		end)
		folder.ChildRemoved:Connect(function()
			API.Refresh()
		end)
	end

	return true
end

-- Try for a short window while Menu loads
local start = os.clock()
while os.clock() - start < 6 do
	if tryAttach() then
		break
	end
	RunService.Heartbeat:Wait()
end
