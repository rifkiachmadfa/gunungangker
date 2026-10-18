--!strict
--[[
	SurvivalHud (CLIENT) — bar Lapar & Haus di pojok kiri bawah.

	- Hanya presentasi: membaca Attribute "Hunger"/"Thirst" pada Player (ditulis server).
	- Dibuat penuh lewat kode (tanpa aset di Studio) agar dikelola Rojo.
	- Responsif: UIScale mengikuti sisi pendek viewport, ScreenInsets = DeviceSafeInsets
	  (aman untuk notch/safe area), ukuran panel tetap kecil.
	- Mobile: thumbstick bawaan Roblox berada di kiri bawah, jadi pada perangkat touch
	  panel dinaikkan (TOUCH_BOTTOM_OFFSET) agar tidak menumpuk dengan joystick.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SurvivalConfig") :: ModuleScript) :: any

-- Layout (satuan px sebelum UIScale)
local PANEL_WIDTH = 230
local PANEL_PADDING = 10
local ROW_HEIGHT = 24
local ROW_GAP = 6
local LABEL_WIDTH = 52
local PERCENT_WIDTH = 44
local BAR_HEIGHT = 12
local MARGIN_LEFT = 16
local DESKTOP_BOTTOM_OFFSET = 20
local TOUCH_BOTTOM_OFFSET = 150 -- di atas area thumbstick bawaan
local TEXT_SIZE = 15

local STAT_LABEL: { [string]: string } = {
	Hunger = "LAPAR",
	Thirst = "HAUS",
}

local STAT_COLOR: { [string]: Color3 } = {
	Hunger = Color3.fromRGB(214, 140, 60),
	Thirst = Color3.fromRGB(70, 150, 214),
}
local LOW_COLOR = Color3.fromRGB(200, 50, 50)
local PANEL_COLOR = Color3.fromRGB(15, 15, 18)
local BAR_BACK_COLOR = Color3.fromRGB(45, 45, 50)
local TEXT_COLOR = Color3.fromRGB(235, 235, 235)

local FILL_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local SurvivalHud = {}

local function isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function computeScale(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	return math.clamp(math.min(viewport.X, viewport.Y) / 600, 0.9, 1.25)
end

local function makeLabel(name: string, text: string, alignment: Enum.TextXAlignment): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = TEXT_SIZE
	label.TextColor3 = TEXT_COLOR
	label.TextXAlignment = alignment
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = text
	return label
end

type Row = {
	Fill: Frame,
	Percent: TextLabel,
}

local function buildRow(parent: Frame, statName: string, order: number): Row
	local row = Instance.new("Frame")
	row.Name = statName
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.Parent = parent

	local label = makeLabel("Label", STAT_LABEL[statName] or statName, Enum.TextXAlignment.Left)
	label.Size = UDim2.new(0, LABEL_WIDTH, 1, 0)
	label.Parent = row

	local percent = makeLabel("Percent", "0%", Enum.TextXAlignment.Right)
	percent.AnchorPoint = Vector2.new(1, 0)
	percent.Position = UDim2.new(1, 0, 0, 0)
	percent.Size = UDim2.new(0, PERCENT_WIDTH, 1, 0)
	percent.Parent = row

	local back = Instance.new("Frame")
	back.Name = "BarBack"
	back.AnchorPoint = Vector2.new(0, 0.5)
	back.Position = UDim2.new(0, LABEL_WIDTH + 4, 0.5, 0)
	back.Size = UDim2.new(1, -(LABEL_WIDTH + PERCENT_WIDTH + 8), 0, BAR_HEIGHT)
	back.BackgroundColor3 = BAR_BACK_COLOR
	back.BorderSizePixel = 0
	back.ClipsDescendants = true
	back.Parent = row

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0.5, 0)
	backCorner.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = STAT_COLOR[statName] or Color3.fromRGB(200, 200, 200)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = back

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill

	return { Fill = fill, Percent = percent }
end

local function render(row: Row, statName: string, value: number, animate: boolean)
	local def = Config.Stats[statName]
	local fraction = math.clamp(value / def.Max, 0, 1)
	local percent = fraction * 100

	row.Percent.Text = string.format("%d%%", math.floor(percent + 0.5))

	local isLow = percent < Config.LowThreshold
	row.Fill.BackgroundColor3 = if isLow then LOW_COLOR else (STAT_COLOR[statName] or row.Fill.BackgroundColor3)

	local target = UDim2.fromScale(fraction, 1)
	if animate then
		TweenService:Create(row.Fill, FILL_TWEEN, { Size = target }):Play()
	else
		row.Fill.Size = target
	end
end

function SurvivalHud.Mount(player: Player)
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "SurvivalHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, MARGIN_LEFT, 1, -(if isTouchOnly() then TOUCH_BOTTOM_OFFSET else DESKTOP_BOTTOM_OFFSET))
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.35
	panel.BorderSizePixel = 0
	panel.Active = false -- jangan menyerap input (joystick/kamera tetap jalan)
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, PANEL_PADDING)
	padding.PaddingBottom = UDim.new(0, PANEL_PADDING)
	padding.PaddingLeft = UDim.new(0, PANEL_PADDING)
	padding.PaddingRight = UDim.new(0, PANEL_PADDING)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.Parent = panel

	local scale = Instance.new("UIScale")
	scale.Scale = computeScale()
	scale.Parent = panel

	-- Skala ikut perubahan ukuran viewport (rotasi layar, resize jendela).
	local function bindCamera(camera: Camera?)
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				scale.Scale = computeScale()
			end)
		end
	end
	bindCamera(Workspace.CurrentCamera)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bindCamera(Workspace.CurrentCamera)
		scale.Scale = computeScale()
	end)

	-- Baris per stat + binding ke Attribute dari server.
	for index, statName in Config.StatOrder do
		local def = Config.Stats[statName]
		local row = buildRow(panel, statName, index)

		local initial = player:GetAttribute(statName)
		render(row, statName, if type(initial) == "number" then initial else def.Start, false)

		player:GetAttributeChangedSignal(statName):Connect(function()
			local value = player:GetAttribute(statName)
			if type(value) == "number" then
				render(row, statName, value, true)
			end
		end)
	end

	gui.Parent = playerGui
end

return SurvivalHud
