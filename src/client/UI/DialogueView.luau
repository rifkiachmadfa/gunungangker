--!strict
--[[
	DialogueView (CLIENT) — tampilan dialog NPC. Presentasi saja, tanpa logika gameplay.

	- Dibuat penuh lewat kode (tanpa aset di Studio) agar dikelola Rojo.
	- Panel di tengah-bawah layar, lebar maks 560 px, tinggi menyesuaikan isi.
	- Teks tampil bertahap (typewriter, DialogueConfig.UI.CharsPerSecond). Ketuk/klik teks = langsung tampil penuh.
	- Pilihan / tombol Lanjut baru muncul setelah teks selesai tampil.
	- Mobile: tombol minimal 44 px, ScreenInsets = DeviceSafeInsets, skala mengikuti sisi pendek viewport.

	API: DialogueView.new(player, callbacks) -> View
	  View.Show(payload)       payload dari DialogueShow
	  View.Hide()
	  View.IsVisible()         -> boolean
	  View.HasChoices()        -> boolean
	  View.ChoiceCount()       -> number
	  View.CompleteTyping()    -> true bila saat itu teks masih mengetik (dan kini dipercepat), selain itu false
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DialogueConfig") :: ModuleScript) :: any

-- Layout (px sebelum UIScale)
local PANEL_MAX_WIDTH = 560
local PANEL_MIN_WIDTH = 240
local PANEL_WIDTH_FRACTION = 0.9 -- bagian lebar layar yang dipakai (setelah UIScale)
local PANEL_PADDING = 14
local PANEL_GAP = 8
local BOTTOM_OFFSET = 20
local HEADER_HEIGHT = 24
local CLOSE_SIZE = 28
local BUTTON_HEIGHT = 44
local CHOICE_GAP = 6
local SPEAKER_TEXT_SIZE = 18
local BODY_TEXT_SIZE = 17
local BUTTON_TEXT_SIZE = 16
local HINT_TEXT_SIZE = 13

local PANEL_COLOR = Color3.fromRGB(12, 12, 15)
local SPEAKER_COLOR = Color3.fromRGB(232, 190, 110)
local TEXT_COLOR = Color3.fromRGB(235, 235, 235)
local HINT_COLOR = Color3.fromRGB(150, 150, 158)
local BUTTON_COLOR = Color3.fromRGB(44, 44, 54)
local CLOSE_COLOR = Color3.fromRGB(70, 40, 40)

export type Payload = {
	SessionId: number,
	Speaker: string,
	Text: string,
	Choices: { string }?,
	IsLast: boolean,
}

export type Callbacks = {
	OnAdvance: () -> (),
	OnChoose: (index: number) -> (),
	OnClose: () -> (),
}

export type View = {
	Show: (payload: Payload) -> (),
	Hide: () -> (),
	IsVisible: () -> boolean,
	HasChoices: () -> boolean,
	ChoiceCount: () -> number,
	CompleteTyping: () -> boolean,
}

local DialogueView = {}

local function computeScale(): number
	local camera = Workspace.CurrentCamera
	if not camera then
		return 1
	end
	local viewport = camera.ViewportSize
	return math.clamp(math.min(viewport.X, viewport.Y) / 600, 0.9, 1.25)
end

local function isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function makeButton(name: string, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamMedium
	button.TextSize = BUTTON_TEXT_SIZE
	button.TextColor3 = TEXT_COLOR
	button.TextWrapped = true
	button.Text = text

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

function DialogueView.new(player: Player, callbacks: Callbacks): View
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "DialogueUi"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET)
	panel.Size = UDim2.new(PANEL_WIDTH_FRACTION, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Active = true -- serap input agar klik/ketuk tidak tembus ke dunia
	panel.Parent = gui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = panel

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(PANEL_MIN_WIDTH, 0)
	sizeConstraint.MaxSize = Vector2.new(PANEL_MAX_WIDTH, math.huge)
	sizeConstraint.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, PANEL_PADDING)
	padding.PaddingBottom = UDim.new(0, PANEL_PADDING)
	padding.PaddingLeft = UDim.new(0, PANEL_PADDING)
	padding.PaddingRight = UDim.new(0, PANEL_PADDING)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, PANEL_GAP)
	layout.Parent = panel

	local scale = Instance.new("UIScale")
	scale.Parent = panel

	local function applyScale()
		scale.Scale = computeScale()
		-- Lebar efektif (setelah UIScale) = PANEL_WIDTH_FRACTION dari layar.
		panel.Size = UDim2.new(PANEL_WIDTH_FRACTION / scale.Scale, 0, 0, 0)
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

	-- Header: nama pembicara + tombol tutup.
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.LayoutOrder = 1
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	header.Parent = panel

	local speakerLabel = Instance.new("TextLabel")
	speakerLabel.Name = "Speaker"
	speakerLabel.BackgroundTransparency = 1
	speakerLabel.Font = Enum.Font.GothamBold
	speakerLabel.TextSize = SPEAKER_TEXT_SIZE
	speakerLabel.TextColor3 = SPEAKER_COLOR
	speakerLabel.TextXAlignment = Enum.TextXAlignment.Left
	speakerLabel.TextYAlignment = Enum.TextYAlignment.Center
	speakerLabel.TextTruncate = Enum.TextTruncate.AtEnd
	speakerLabel.Size = UDim2.new(1, -(CLOSE_SIZE + 8), 1, 0)
	speakerLabel.Text = ""
	speakerLabel.Parent = header

	local closeButton = makeButton("Close", "X", CLOSE_COLOR)
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, 0, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE)
	closeButton.Parent = header
	closeButton.Activated:Connect(function()
		callbacks.OnClose()
	end)

	-- Teks dialog. TextButton agar ketuk/klik bisa mempercepat typewriter.
	local bodyText = Instance.new("TextButton")
	bodyText.Name = "Body"
	bodyText.LayoutOrder = 2
	bodyText.AutoButtonColor = false
	bodyText.BackgroundTransparency = 1
	bodyText.BorderSizePixel = 0
	bodyText.Font = Enum.Font.Gotham
	bodyText.TextSize = BODY_TEXT_SIZE
	bodyText.TextColor3 = TEXT_COLOR
	bodyText.TextWrapped = true
	bodyText.RichText = false
	bodyText.TextXAlignment = Enum.TextXAlignment.Left
	bodyText.TextYAlignment = Enum.TextYAlignment.Top
	bodyText.Size = UDim2.new(1, 0, 0, 0)
	bodyText.AutomaticSize = Enum.AutomaticSize.Y
	bodyText.Text = ""
	bodyText.Parent = panel

	-- Wadah pilihan.
	local choicesFrame = Instance.new("Frame")
	choicesFrame.Name = "Choices"
	choicesFrame.LayoutOrder = 3
	choicesFrame.BackgroundTransparency = 1
	choicesFrame.Size = UDim2.new(1, 0, 0, 0)
	choicesFrame.AutomaticSize = Enum.AutomaticSize.Y
	choicesFrame.Visible = false
	choicesFrame.Parent = panel

	local choicesLayout = Instance.new("UIListLayout")
	choicesLayout.FillDirection = Enum.FillDirection.Vertical
	choicesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	choicesLayout.Padding = UDim.new(0, CHOICE_GAP)
	choicesLayout.Parent = choicesFrame

	-- Tombol Lanjut / Tutup untuk node tanpa pilihan.
	local continueButton = makeButton("Continue", "Lanjut", BUTTON_COLOR)
	continueButton.LayoutOrder = 4
	continueButton.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
	continueButton.Visible = false
	continueButton.Parent = panel
	continueButton.Activated:Connect(function()
		callbacks.OnAdvance()
	end)

	-- Petunjuk keyboard (disembunyikan di perangkat touch-only).
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.LayoutOrder = 5
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = HINT_TEXT_SIZE
	hint.TextColor3 = HINT_COLOR
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.Size = UDim2.new(1, 0, 0, HINT_TEXT_SIZE + 2)
	hint.Text = "E / Spasi: lanjut    1-4: pilih"
	hint.Visible = not isTouchOnly()
	hint.Parent = panel

	gui.Parent = playerGui

	-- State tampilan
	local visible = false
	local currentChoices: { string } = {}
	local currentIsLast = false
	local choiceButtons: { TextButton } = {}
	local typing = false
	local typingToken = 0

	local function clearChoices()
		for _, button in choiceButtons do
			button:Destroy()
		end
		table.clear(choiceButtons)
	end

	local function reveal()
		if #currentChoices > 0 then
			choicesFrame.Visible = true
		else
			continueButton.Text = if currentIsLast then "Tutup" else "Lanjut"
			continueButton.Visible = true
		end
	end

	local function finishTyping()
		typing = false
		bodyText.MaxVisibleGraphemes = -1
		reveal()
	end

	local function startTyping(text: string)
		typingToken += 1
		local token = typingToken
		local charsPerSecond: number = Config.UI.CharsPerSecond
		if charsPerSecond <= 0 then
			finishTyping()
			return
		end

		local total = utf8.len(text) or #text
		typing = true
		bodyText.MaxVisibleGraphemes = 0
		task.spawn(function()
			local startedAt = os.clock()
			while typingToken == token do
				local shown = math.floor((os.clock() - startedAt) * charsPerSecond)
				if shown >= total then
					break
				end
				bodyText.MaxVisibleGraphemes = shown
				task.wait()
			end
			if typingToken == token then
				finishTyping()
			end
		end)
	end

	local function completeTyping(): boolean
		if not typing then
			return false
		end
		typingToken += 1 -- batalkan loop typewriter
		finishTyping()
		return true
	end

	bodyText.Activated:Connect(function()
		completeTyping()
	end)

	local function show(payload: Payload)
		-- Reset tampilan node sebelumnya.
		typingToken += 1
		typing = false
		clearChoices()
		choicesFrame.Visible = false
		continueButton.Visible = false

		currentChoices = {}
		if type(payload.Choices) == "table" then
			for _, choiceText in payload.Choices do
				if type(choiceText) == "string" then
					table.insert(currentChoices, choiceText)
				end
			end
		end
		currentIsLast = payload.IsLast == true

		speakerLabel.Text = payload.Speaker
		bodyText.Text = payload.Text

		for index, choiceText in currentChoices do
			local button = makeButton(`Choice{index}`, `{index}.  {choiceText}`, BUTTON_COLOR)
			button.LayoutOrder = index
			button.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
			button.AutomaticSize = Enum.AutomaticSize.Y -- Size = tinggi minimum; tumbuh bila teks panjang
			button.TextXAlignment = Enum.TextXAlignment.Left
			local buttonPadding = Instance.new("UIPadding")
			buttonPadding.PaddingLeft = UDim.new(0, 12)
			buttonPadding.PaddingRight = UDim.new(0, 12)
			buttonPadding.PaddingTop = UDim.new(0, 8)
			buttonPadding.PaddingBottom = UDim.new(0, 8)
			buttonPadding.Parent = button
			button.Parent = choicesFrame
			button.Activated:Connect(function()
				callbacks.OnChoose(index)
			end)
			table.insert(choiceButtons, button)
		end

		visible = true
		gui.Enabled = true
		startTyping(payload.Text)
	end

	local function hide()
		typingToken += 1
		typing = false
		visible = false
		gui.Enabled = false
		clearChoices()
		choicesFrame.Visible = false
		continueButton.Visible = false
		currentChoices = {}
	end

	return {
		Show = show,
		Hide = hide,
		IsVisible = function()
			return visible
		end,
		HasChoices = function()
			return #currentChoices > 0
		end,
		ChoiceCount = function()
			return #currentChoices
		end,
		CompleteTyping = completeTyping,
	}
end

return DialogueView
