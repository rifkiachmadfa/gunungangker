--!strict
--[[
	NotificationView (CLIENT) — tampilan notifikasi: toast singkat dan panel tujuan (objective).

	- Hanya presentasi. Tidak membaca state gameplay dan tidak mengirim Remote.
	- Dibuat penuh lewat kode (tanpa aset di Studio) agar dikelola Rojo.
	- Toast  : tengah-atas, muncul (fade in), tahan sebentar, hilang sendiri. Maksimal MAX_TOASTS sekaligus.
	- Tujuan : kanan-atas, satu kartu per quest aktif ("Judul" + teks progres), tetap tampil sampai dihapus.
	- Responsif: UIScale mengikuti sisi pendek viewport, ScreenInsets = DeviceSafeInsets, tidak menyerap input.
	- DisplayOrder di bawah DialogueView (20) agar dialog tetap di atas notifikasi.

	API: NotificationView.new(player) -> View
	  View.Toast(text)                         tampilkan toast
	  View.SetObjective(id, title, text)       buat atau perbarui kartu tujuan
	  View.ClearObjective(id)                  hapus kartu tujuan (aman bila tidak ada)
	  View.HasObjective(id) -> boolean
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Layout (px sebelum UIScale)
local OBJECTIVE_WIDTH = 250
local OBJECTIVE_PADDING = 10
local OBJECTIVE_GAP = 6
local MARGIN = 16
local TOAST_PADDING_X = 16
local TOAST_PADDING_Y = 8
local TOAST_GAP = 6
local TOAST_MAX_WIDTH = 360
local TITLE_TEXT_SIZE = 13
local BODY_TEXT_SIZE = 16
local TOAST_TEXT_SIZE = 17

local TOAST_HOLD = 2.5 -- detik tampil penuh
local TOAST_FADE = 0.25
local MAX_TOASTS = 4

local PANEL_COLOR = Color3.fromRGB(15, 15, 18)
local TITLE_COLOR = Color3.fromRGB(232, 190, 110)
local TEXT_COLOR = Color3.fromRGB(235, 235, 235)
local PANEL_TRANSPARENCY = 0.3

local FADE_INFO = TweenInfo.new(TOAST_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local NotificationView = {}

export type View = {
	Toast: (text: string) -> (),
	SetObjective: (id: string, title: string, text: string) -> (),
	ClearObjective: (id: string) -> (),
	HasObjective: (id: string) -> boolean,
}

local function computeScale(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	return math.clamp(math.min(viewport.X, viewport.Y) / 600, 0.9, 1.25)
end

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeText(name: string, size: number, font: Enum.Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.RichText = false
	label.Text = ""
	return label
end

function NotificationView.new(player: Player): View
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "Notifications"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Kartu tujuan (kanan-atas).
	local objectives = Instance.new("Frame")
	objectives.Name = "Objectives"
	objectives.AnchorPoint = Vector2.new(1, 0)
	objectives.Position = UDim2.new(1, -MARGIN, 0, MARGIN)
	objectives.Size = UDim2.fromOffset(OBJECTIVE_WIDTH, 0)
	objectives.AutomaticSize = Enum.AutomaticSize.Y
	objectives.BackgroundTransparency = 1
	objectives.Active = false
	objectives.Parent = gui

	local objectivesLayout = Instance.new("UIListLayout")
	objectivesLayout.FillDirection = Enum.FillDirection.Vertical
	objectivesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	objectivesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	objectivesLayout.Padding = UDim.new(0, OBJECTIVE_GAP)
	objectivesLayout.Parent = objectives

	local objectivesScale = Instance.new("UIScale")
	objectivesScale.Parent = objectives

	-- Toast (tengah-atas).
	local toasts = Instance.new("Frame")
	toasts.Name = "Toasts"
	toasts.AnchorPoint = Vector2.new(0.5, 0)
	toasts.Position = UDim2.new(0.5, 0, 0, MARGIN)
	toasts.Size = UDim2.fromOffset(TOAST_MAX_WIDTH, 0)
	toasts.AutomaticSize = Enum.AutomaticSize.Y
	toasts.BackgroundTransparency = 1
	toasts.Active = false
	toasts.Parent = gui

	local toastsLayout = Instance.new("UIListLayout")
	toastsLayout.FillDirection = Enum.FillDirection.Vertical
	toastsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toastsLayout.Padding = UDim.new(0, TOAST_GAP)
	toastsLayout.Parent = toasts

	local toastsScale = Instance.new("UIScale")
	toastsScale.Parent = toasts

	local function applyScale()
		local scale = computeScale()
		objectivesScale.Scale = scale
		toastsScale.Scale = scale
	end
	applyScale()

	local function bindCamera(camera: Camera?)
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
		end
	end
	bindCamera(Workspace.CurrentCamera)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		bindCamera(Workspace.CurrentCamera)
		applyScale()
	end)

	gui.Parent = playerGui

	----------------------------------------------------------------------------
	-- Tujuan
	----------------------------------------------------------------------------

	local objectiveCards: { [string]: Frame } = {}
	local nextOrder = 0

	local function SetObjective(id: string, title: string, text: string)
		local card = objectiveCards[id]
		if card == nil then
			nextOrder += 1

			card = Instance.new("Frame")
			card.Name = "Objective_" .. id
			card.LayoutOrder = nextOrder
			card.Size = UDim2.fromOffset(OBJECTIVE_WIDTH, 0)
			card.AutomaticSize = Enum.AutomaticSize.Y
			card.BackgroundColor3 = PANEL_COLOR
			card.BackgroundTransparency = PANEL_TRANSPARENCY
			card.BorderSizePixel = 0
			card.Active = false
			addCorner(card, 8)

			local padding = Instance.new("UIPadding")
			padding.PaddingTop = UDim.new(0, OBJECTIVE_PADDING)
			padding.PaddingBottom = UDim.new(0, OBJECTIVE_PADDING)
			padding.PaddingLeft = UDim.new(0, OBJECTIVE_PADDING)
			padding.PaddingRight = UDim.new(0, OBJECTIVE_PADDING)
			padding.Parent = card

			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Vertical
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Padding = UDim.new(0, 4)
			layout.Parent = card

			local titleLabel = makeText("Title", TITLE_TEXT_SIZE, Enum.Font.GothamBold, TITLE_COLOR)
			titleLabel.LayoutOrder = 1
			titleLabel.Size = UDim2.new(1, 0, 0, 0)
			titleLabel.AutomaticSize = Enum.AutomaticSize.Y
			titleLabel.Parent = card

			local bodyLabel = makeText("Body", BODY_TEXT_SIZE, Enum.Font.GothamMedium, TEXT_COLOR)
			bodyLabel.LayoutOrder = 2
			bodyLabel.Size = UDim2.new(1, 0, 0, 0)
			bodyLabel.AutomaticSize = Enum.AutomaticSize.Y
			bodyLabel.Parent = card

			card.Parent = objectives
			objectiveCards[id] = card
		end

		local titleLabel = (card :: Frame):FindFirstChild("Title") :: TextLabel?
		local bodyLabel = (card :: Frame):FindFirstChild("Body") :: TextLabel?
		if titleLabel ~= nil then
			titleLabel.Text = string.upper(title)
		end
		if bodyLabel ~= nil then
			bodyLabel.Text = text
		end
	end

	local function ClearObjective(id: string)
		local card = objectiveCards[id]
		if card == nil then
			return
		end
		objectiveCards[id] = nil
		card:Destroy()
	end

	local function HasObjective(id: string): boolean
		return objectiveCards[id] ~= nil
	end

	----------------------------------------------------------------------------
	-- Toast
	----------------------------------------------------------------------------

	local liveToasts: { TextLabel } = {}
	local toastOrder = 0

	local function removeToast(toast: TextLabel)
		local index = table.find(liveToasts, toast)
		if index ~= nil then
			table.remove(liveToasts, index)
		end
		if toast.Parent ~= nil then
			toast:Destroy()
		end
	end

	local function Toast(text: string)
		-- Batasi jumlah: buang yang paling lama bila penuh.
		while #liveToasts >= MAX_TOASTS do
			removeToast(liveToasts[1])
		end

		toastOrder += 1

		local toast = Instance.new("TextLabel")
		toast.Name = "Toast"
		toast.LayoutOrder = toastOrder
		toast.AutomaticSize = Enum.AutomaticSize.XY
		toast.Size = UDim2.fromOffset(0, 0)
		toast.BackgroundColor3 = PANEL_COLOR
		toast.BackgroundTransparency = 1
		toast.BorderSizePixel = 0
		toast.Font = Enum.Font.GothamMedium
		toast.TextSize = TOAST_TEXT_SIZE
		toast.TextColor3 = TEXT_COLOR
		toast.TextTransparency = 1
		toast.TextWrapped = true
		toast.RichText = false
		toast.Text = text
		toast.Active = false
		addCorner(toast, 8)

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, TOAST_PADDING_Y)
		padding.PaddingBottom = UDim.new(0, TOAST_PADDING_Y)
		padding.PaddingLeft = UDim.new(0, TOAST_PADDING_X)
		padding.PaddingRight = UDim.new(0, TOAST_PADDING_X)
		padding.Parent = toast

		-- Batas lebar agar teks panjang membungkus, bukan melebar keluar layar.
		local sizeLimit = Instance.new("UISizeConstraint")
		sizeLimit.MaxSize = Vector2.new(TOAST_MAX_WIDTH, math.huge)
		sizeLimit.Parent = toast

		toast.Parent = toasts
		table.insert(liveToasts, toast)

		TweenService:Create(toast, FADE_INFO, {
			BackgroundTransparency = PANEL_TRANSPARENCY,
			TextTransparency = 0,
		}):Play()

		task.delay(TOAST_FADE + TOAST_HOLD, function()
			if toast.Parent == nil then
				return -- sudah dibuang
			end
			local fadeOut = TweenService:Create(toast, FADE_INFO, {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			})
			fadeOut.Completed:Once(function()
				removeToast(toast)
			end)
			fadeOut:Play()
		end)
	end

	return {
		Toast = Toast,
		SetObjective = SetObjective,
		ClearObjective = ClearObjective,
		HasObjective = HasObjective,
	}
end

return NotificationView
