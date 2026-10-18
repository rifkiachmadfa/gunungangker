--!strict
--[[
	DialogueController (CLIENT) — menghubungkan Remote dialog, input, dan DialogueView.

	- Menerima node dari server (DialogueShow) dan menampilkannya lewat view.
	- Mengirim INTENT saja ke server (DialogueRespond): "Advance", "Choose" + index, "Cancel".
	  Hasil/benar-salah ditentukan server; client tidak pernah memilih node berikutnya.
	- Selama dialog terbuka:
	    * ProximityPromptService.Enabled = false (lokal) agar prompt tidak bertumpuk.
	    * Input dibinding prioritas tinggi dan di-sink: E / Spasi / Enter / ButtonA = lanjut,
	      1-4 = pilih, ButtonB = tutup. Spasi tidak membuat karakter melompat selama dialog.
	- Karakter TIDAK dibekukan; server menutup dialog bila pemain menjauh atau mati.

	API: DialogueController.Start(player, DialogueViewModule)
]]

local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes") :: ModuleScript) :: any

local ACTION_ADVANCE = "DialogueAdvance"
local ACTION_CHOOSE = "DialogueChoose"
local ACTION_CLOSE = "DialogueClose"
local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value

local CHOICE_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
}

local DialogueController = {}

local started = false

function DialogueController.Start(player: Player, viewModule: any)
	if started then
		return
	end
	started = true

	local showRemote: RemoteEvent = Remotes.Get("DialogueShow")
	local endRemote: RemoteEvent = Remotes.Get("DialogueEnd")
	local respondRemote: RemoteEvent = Remotes.Get("DialogueRespond")

	local currentSessionId: number? = nil
	local inputBound = false

	local function respond(kind: string, index: number?)
		local sessionId = currentSessionId
		if sessionId == nil then
			return
		end
		respondRemote:FireServer(sessionId, kind, index)
	end

	local function unbindInput()
		if not inputBound then
			return
		end
		inputBound = false
		ContextActionService:UnbindAction(ACTION_ADVANCE)
		ContextActionService:UnbindAction(ACTION_CHOOSE)
		ContextActionService:UnbindAction(ACTION_CLOSE)
	end

	-- `view` dibuat setelah callback didefinisikan; dipakai lewat closure setelah itu.
	local view: any = nil

	local function hide()
		currentSessionId = nil
		view.Hide()
		unbindInput()
		ProximityPromptService.Enabled = true
	end

	local function close()
		if currentSessionId == nil then
			return
		end
		respond("Cancel", nil)
		hide()
	end

	local function advance()
		if currentSessionId == nil then
			return
		end
		if view.CompleteTyping() then
			return -- tekanan pertama hanya mempercepat teks
		end
		if view.HasChoices() then
			return -- node dengan pilihan tidak bisa di-advance
		end
		respond("Advance", nil)
	end

	local function choose(index: number)
		if currentSessionId == nil then
			return
		end
		if view.CompleteTyping() then
			return
		end
		if index < 1 or index > view.ChoiceCount() then
			return
		end
		respond("Choose", index)
	end

	local function onAdvanceAction(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			advance()
		end
		return Enum.ContextActionResult.Sink
	end

	local function onChooseAction(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			local index = CHOICE_KEYS[input.KeyCode]
			if index ~= nil then
				choose(index)
			end
		end
		return Enum.ContextActionResult.Sink
	end

	local function onCloseAction(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			close()
		end
		return Enum.ContextActionResult.Sink
	end

	local function bindInput()
		if inputBound then
			return
		end
		inputBound = true
		ContextActionService:BindActionAtPriority(
			ACTION_ADVANCE,
			onAdvanceAction,
			false,
			INPUT_PRIORITY,
			Enum.KeyCode.E,
			Enum.KeyCode.Space,
			Enum.KeyCode.Return,
			Enum.KeyCode.ButtonA
		)
		ContextActionService:BindActionAtPriority(
			ACTION_CHOOSE,
			onChooseAction,
			false,
			INPUT_PRIORITY,
			Enum.KeyCode.One,
			Enum.KeyCode.Two,
			Enum.KeyCode.Three,
			Enum.KeyCode.Four,
			Enum.KeyCode.KeypadOne,
			Enum.KeyCode.KeypadTwo,
			Enum.KeyCode.KeypadThree,
			Enum.KeyCode.KeypadFour
		)
		ContextActionService:BindActionAtPriority(ACTION_CLOSE, onCloseAction, false, INPUT_PRIORITY, Enum.KeyCode.ButtonB)
	end

	view = viewModule.new(player, {
		OnAdvance = advance,
		OnChoose = choose,
		OnClose = close,
	})

	showRemote.OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		if type(payload.SessionId) ~= "number" or type(payload.Text) ~= "string" or type(payload.Speaker) ~= "string" then
			return
		end
		currentSessionId = payload.SessionId
		ProximityPromptService.Enabled = false
		bindInput()
		view.Show(payload)
	end)

	endRemote.OnClientEvent:Connect(function(sessionId: any, _reason: any)
		if type(sessionId) == "number" and sessionId == currentSessionId then
			hide()
		end
	end)
end

return DialogueController
