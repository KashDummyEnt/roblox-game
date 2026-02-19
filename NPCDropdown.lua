--!strict
-- NPCDropdown.lua
-- Always-on NPC dropdown: lists workspace.NPCs Model children in a scrollable dropdown.
-- Safe: if folder/models don't exist, dropdown stays empty (no errors).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------
-- GLOBAL API (so other remotes can read the selected NPC)
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

API.SelectedName = API.SelectedName or nil
API.SelectedModel = API.SelectedModel or nil

------------------------------------------------------------------
-- CONFIG: where to inject the card
------------------------------------------------------------------
local GUI_NAME = "PopupMenuGui"
local POPUP_NAME = "PopupPanel"
local TARGET_PAGE_NAME = "Main" -- change if you want it on "World" / "Visuals" etc
local CARD_NAME = "NPCDropdownCard"
local CARD_ORDER = 2

------------------------------------------------------------------
-- SAFE WAIT HELPERS
------------------------------------------------------------------
local function waitForNamedChild(parent: Instance, name: string, timeout: number): Instance?
	local start = os.clock()
	while os.clock() - start < timeout do
		local f = parent:FindFirstChild(name)
		if f then return f end
		task.wait(0.03)
	end
	return nil
end

local function make(className: string, props: {[string]: any}?): Instance
	local inst = Instance.new(className)
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
-- RESOLVE MENU + THEME COLORS (sniff from existing UI)
------------------------------------------------------------------
type Theme = {
	Bg: Color3,
	Bg2: Color3,
	Bg3: Color3,
	Text: Color3,
	SubText: Color3,
	Stroke: Color3,
	Accent: Color3,
}

type UiRefs = {
	Page: ScrollingFrame,
	Theme: Theme,
}

local function resolveMenu(): UiRefs?
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then return nil end

	local screenGui = pg:FindFirstChild(GUI_NAME)
	if not screenGui then return nil end

	local popup = screenGui:FindFirstChild(POPUP_NAME)
	if not popup then return nil end

	local body = popup:FindFirstChild("Body")
	if not body then return nil end

	local pages = body:FindFirstChild("Pages")
	if not pages then return nil end

	local page = pages:FindFirstChild(TARGET_PAGE_NAME)
	if not page then return nil end

	local pageSf = page :: ScrollingFrame

	local fallback: Theme = {
		Bg = Color3.fromRGB(14, 14, 18),
		Bg2 = Color3.fromRGB(20, 20, 24),
		Bg3 = Color3.fromRGB(26, 26, 32),
		Text = Color3.fromRGB(240, 240, 244),
		SubText = Color3.fromRGB(170, 170, 180),
		Stroke = Color3.fromRGB(55, 55, 65),
		Accent = Color3.fromRGB(253, 55, 0),
	}

	-- Try to pull from an existing card/button so it matches your theme
	local anyFrame = pageSf:FindFirstChildWhichIsA("Frame")
	local anyButton = pageSf:FindFirstChildWhichIsA("TextButton")

	if anyFrame then
		fallback.Bg2 = (anyFrame :: Frame).BackgroundColor3
		local s = anyFrame:FindFirstChildOfClass("UIStroke")
		if s then fallback.Stroke = (s :: UIStroke).Color end
	end

	if anyButton then
		fallback.Bg2 = (anyButton :: TextButton).BackgroundColor3
		local s = anyButton:FindFirstChildOfClass("UIStroke")
		if s then fallback.Stroke = (s :: UIStroke).Color end
	end

	return { Page = pageSf, Theme = fallback }
end

------------------------------------------------------------------
-- NPC COLLECTION
------------------------------------------------------------------
local function getNpcFolder(): Instance?
	return workspace:FindFirstChild("NPCs")
end

local function collectNpcModels(): {Model}
	local folder = getNpcFolder()
	if not folder then return {} end

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
-- UI STATE
------------------------------------------------------------------
type UiState = {
	Root: Frame,
	Button: TextButton,
	ButtonLabel: TextLabel,
	Popup: Frame,
	List: ScrollingFrame,
	EmptyLabel: TextLabel,
	IsOpen: boolean,
}

local ui: UiState? = nil
local npcList: {Model} = {}
local selectedIndex: number? = nil

local function setSelected(idx: number?)
	if not idx or idx < 1 or idx > #npcList then
		selectedIndex = nil
		API.SelectedName = nil
		API.SelectedModel = nil
		if ui then
			ui.ButtonLabel.Text = "Select NPC"
		end
		return
	end

	selectedIndex = idx
	local m = npcList[idx]
	API.SelectedName = m.Name
	API.SelectedModel = (m.Parent ~= nil) and m or nil

	if ui then
		ui.ButtonLabel.Text = m.Name
	end
end

local function closeDropdown()
	if not ui then return end
	ui.IsOpen = false
	ui.Popup.Visible = false
end

local function openDropdown()
	if not ui then return end
	ui.IsOpen = true
	ui.Popup.Visible = true
end

local function toggleDropdown()
	if not ui then return end
	if ui.IsOpen then
		closeDropdown()
	else
		openDropdown()
	end
end

local function clearList()
	if not ui then return end
	for _, ch in ipairs(ui.List:GetChildren()) do
		if ch:IsA("TextButton") then
			ch:Destroy()
		end
	end
end

local function rebuildList(theme: Theme)
	if not ui then return end

	clearList()

	if #npcList == 0 then
		ui.EmptyLabel.Visible = true
		ui.List.CanvasSize = UDim2.new(0, 0, 0, 0)
		return
	end

	ui.EmptyLabel.Visible = false

	local y = 0
	local itemH = 30

	for i, m in ipairs(npcList) do
		local item = make("TextButton", {
			Name = "Item_" .. tostring(i),
			AutoButtonColor = false,
			BackgroundColor3 = theme.Bg3,
			Size = UDim2.new(1, -8, 0, itemH),
			Position = UDim2.new(0, 4, 0, y + 4),
			Text = "",
			ZIndex = 200,
			Parent = ui.List,
		}) :: TextButton
		addCorner(item, 8)
		addStroke(item, 1, theme.Stroke, 0.35)

		local label = make("TextLabel", {
			BackgroundTransparency = 1,
			Text = m.Name,
			TextColor3 = theme.Text,
			TextSize = 13,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			ZIndex = 201,
			Parent = item,
		}) :: TextLabel

		item.MouseEnter:Connect(function()
			item.BackgroundColor3 = theme.Bg2
		end)
		item.MouseLeave:Connect(function()
			item.BackgroundColor3 = theme.Bg3
		end)

		item.MouseButton1Click:Connect(function()
			setSelected(i)
			closeDropdown()
		end)

		y += itemH + 6
	end

	ui.List.CanvasSize = UDim2.new(0, 0, 0, y + 8)
end

------------------------------------------------------------------
-- BUILD DROPDOWN CARD
------------------------------------------------------------------
local function destroyExistingCard(page: ScrollingFrame)
	local existing = page:FindFirstChild(CARD_NAME)
	if existing then
		existing:Destroy()
	end
end

local function buildCard(refs: UiRefs)
	local page = refs.Page
	local theme = refs.Theme

	destroyExistingCard(page)

	local card = make("Frame", {
		Name = CARD_NAME,
		BackgroundColor3 = theme.Bg2,
		Size = UDim2.new(1, 0, 0, 92),
		ZIndex = 120,
		LayoutOrder = CARD_ORDER,
		Parent = page,
	}) :: Frame
	addCorner(card, 12)
	addStroke(card, 1, theme.Stroke, 0.35)

	make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Text = "NPC",
		TextColor3 = theme.Text,
		TextSize = 15,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.new(0, 10, 0, 8),
		ZIndex = 121,
		Parent = card,
	})

	make("TextLabel", {
		Name = "Sub",
		BackgroundTransparency = 1,
		Text = "Pick an NPC from Workspace > NPCs",
		TextColor3 = theme.SubText,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.new(0, 10, 0, 28),
		ZIndex = 121,
		Parent = card,
	})

	local btn = make("TextButton", {
		Name = "DropdownButton",
		AutoButtonColor = false,
		BackgroundColor3 = theme.Bg3,
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 10, 0, 56),
		Text = "",
		ZIndex = 122,
		Parent = card,
	}) :: TextButton
	addCorner(btn, 10)
	addStroke(btn, 1, theme.Stroke, 0.25)

	local btnLabel = make("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Text = "Select NPC",
		TextColor3 = theme.Text,
		TextSize = 14,
		Font = Enum.Font.GothamSemibold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -34, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		ZIndex = 123,
		Parent = btn,
	}) :: TextLabel

	local caret = make("TextLabel", {
		Name = "Caret",
		BackgroundTransparency = 1,
		Text = "▾",
		TextColor3 = theme.SubText,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 24, 1, 0),
		Position = UDim2.new(1, -26, 0, 0),
		ZIndex = 123,
		Parent = btn,
	}) :: TextLabel

	-- Popup dropdown (overlays below button)
	local popup = make("Frame", {
		Name = "DropdownPopup",
		BackgroundColor3 = theme.Bg2,
		Visible = false,
		Size = UDim2.new(1, -20, 0, 180),
		Position = UDim2.new(0, 10, 0, 90),
		ZIndex = 180,
		Parent = card,
	}) :: Frame
	addCorner(popup, 12)
	addStroke(popup, 1, theme.Stroke, 0.25)

	local list = make("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 181,
		Parent = popup,
	}) :: ScrollingFrame

	local empty = make("TextLabel", {
		Name = "Empty",
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = theme.SubText,
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		ZIndex = 182,
		Visible = false,
		Parent = list,
	}) :: TextLabel

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = theme.Bg2
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = theme.Bg3
	end)

	btn.MouseButton1Click:Connect(function()
		toggleDropdown()
	end)

	ui = {
		Root = card,
		Button = btn,
		ButtonLabel = btnLabel,
		Popup = popup,
		List = list,
		EmptyLabel = empty,
		IsOpen = false,
	}

	-- Build list now
	rebuildList(theme)

	-- If no NPCs, show nothing inside dropdown instead of failing
	if #npcList == 0 then
		ui.EmptyLabel.Text = "No NPCs found in Workspace > NPCs."
		ui.EmptyLabel.Visible = true
	end
end

------------------------------------------------------------------
-- REFRESH LOGIC
------------------------------------------------------------------
local function refresh(theme: Theme?)
	npcList = collectNpcModels()

	-- Keep selection if the same name still exists
	local keepName = API.SelectedName
	if keepName then
		local found: number? = nil
		for i, m in ipairs(npcList) do
			if m.Name == keepName then
				found = i
				break
			end
		end
		if found then
			selectedIndex = found
		else
			selectedIndex = nil
			API.SelectedName = nil
			API.SelectedModel = nil
		end
	end

	if ui then
		if theme then
			rebuildList(theme)
		end

		if #npcList == 0 then
			ui.EmptyLabel.Text = "No NPCs found in Workspace > NPCs."
			ui.EmptyLabel.Visible = true
		else
			ui.EmptyLabel.Visible = false
		end

		if selectedIndex then
			setSelected(selectedIndex)
		else
			if #npcList > 0 then
				setSelected(1)
			else
				setSelected(nil)
			end
		end
	end
end

------------------------------------------------------------------
-- PUBLIC API
------------------------------------------------------------------
function API.GetSelectedName(): string?
	return API.SelectedName
end

function API.GetSelectedModel(): Model?
	local m = API.SelectedModel
	if m and m.Parent then
		return m
	end
	return nil
end

function API.Refresh()
	if ui then
		-- Theme is stable after build; just rebuild using current button color set
		local theme: Theme = {
			Bg = Color3.fromRGB(14, 14, 18),
			Bg2 = ui.Root.BackgroundColor3,
			Bg3 = ui.Button.BackgroundColor3,
			Text = ui.ButtonLabel.TextColor3,
			SubText = ui.EmptyLabel.TextColor3,
			Stroke = Color3.fromRGB(55, 55, 65),
			Accent = Color3.fromRGB(253, 55, 0),
		}
		local stroke = ui.Root:FindFirstChildOfClass("UIStroke")
		if stroke then
			theme.Stroke = (stroke :: UIStroke).Color ;
		end
		refresh(theme)
	else
		refresh(nil)
	end
end

------------------------------------------------------------------
-- MAIN: attach once menu exists, then watch NPC folder for changes
------------------------------------------------------------------
local attached = false

local function tryAttach(): boolean
	local refs = resolveMenu()
	if not refs then
		return false
	end

	if attached then
		return true
	end
	attached = true

	npcList = collectNpcModels()
	buildCard(refs)

	-- Initial default selection: first NPC if exists
	if #npcList > 0 then
		setSelected(1)
	else
		setSelected(nil)
	end

	-- Watch changes (safe: if folder doesn’t exist, we also poll lightly)
	local folder = getNpcFolder()
	if folder then
		folder.ChildAdded:Connect(function()
			refresh(refs.Theme)
		end)
		folder.ChildRemoved:Connect(function()
			refresh(refs.Theme)
		end)
	else
		task.spawn(function()
			while attached do
				task.wait(1.0)
				local nowFolder = getNpcFolder()
				if nowFolder then
					nowFolder.ChildAdded:Connect(function()
						local newRefs = resolveMenu()
						if newRefs then refresh(newRefs.Theme) end
					end)
					nowFolder.ChildRemoved:Connect(function()
						local newRefs = resolveMenu()
						if newRefs then refresh(newRefs.Theme) end
					end)
					local newRefs = resolveMenu()
					if newRefs then refresh(newRefs.Theme) end
					break
				end
			end
		end)
	end

	-- Close dropdown if you click off the card area
	game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if ui and ui.IsOpen then
			-- if user clicks outside popup, close
			local mouse = LocalPlayer:GetMouse()
			local x, y = mouse.X, mouse.Y

			local function inBounds(g: GuiObject): boolean
				local absPos = g.AbsolutePosition
				local absSize = g.AbsoluteSize
				return x >= absPos.X and x <= absPos.X + absSize.X and y >= absPos.Y and y <= absPos.Y + absSize.Y
			end

			if not inBounds(ui.Popup) and not inBounds(ui.Button) then
				closeDropdown()
			end
		end
	end)

	return true
end

local start = os.clock()
while os.clock() - start < 8 do
	if tryAttach() then
		break
	end
	RunService.Heartbeat:Wait()
end
