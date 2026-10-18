--!strict
--[[
	DialogueService (SERVER) — pemilik tunggal sesi dialog NPC.

	Alur: pemain menekan ProximityPrompt NPC -> server validasi -> buat sesi -> kirim node ke client.
	Client hanya mengirim intent (Advance / Choose index / Cancel); server menentukan node berikutnya.
	Sesi bersifat personal (satu sesi per pemain). Tidak ada state quest di sini.

	Pengikatan NPC (tanpa membuat Part/model):
	  Config.Npcs[id].ModelName dicari rekursif di Workspace. ProximityPrompt yang sudah ada di NPC
	  dipakai apa adanya (prompt pertama yang ditemukan di dalam NPC). Bila tidak ada, server membuat
	  satu di Part NPC (ActionText dari DialogueConfig.Prompt).

	Validasi server:
	  - Mulai : karakter hidup, jarak ke prompt, StartCooldown.
	  - Respon: tipe argumen, sessionId cocok, rate limit (Advance/Choose), indeks pilihan valid,
	            tipe node sesuai (Advance hanya untuk node tanpa pilihan, Choose hanya dengan pilihan).
	  - Berjalan: tiap CheckInterval sesi ditutup bila pemain mati, menjauh, NPC hilang, atau idle.

	Remote (dibuat lewat Remotes.Get, kontrak lengkap di .ai/GAME_CONTEXT.md bagian 13):
	  DialogueShow    S->C  (payload: { SessionId, Speaker, Text, Choices: {string}?, IsLast })
	  DialogueEnd     S->C  (sessionId: number, reason: string)
	  DialogueRespond C->S  (sessionId: number, kind: "Advance"|"Choose"|"Cancel", index: number?)

	API server (untuk Quest System dan sistem lain):
	  DialogueService.RegisterAction(name, handler)       handler(player, { NpcId, NodeId })
	  DialogueService.RegisterEntryResolver(npcId, fn)    fn(player) -> nodeId?   (nil = pakai Npcs[npcId].Start)
	  DialogueService.RegisterTextVariable(name, fn)      fn(player) -> string | number; mengganti {name} pada teks node
	  DialogueService.IsInDialogue(player) -> boolean
	  DialogueService.End(player, reason?)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("DialogueConfig") :: ModuleScript) :: any
local Remotes = require(Shared:WaitForChild("Remotes") :: ModuleScript) :: any
local ServerRoot = (script.Parent :: Instance).Parent :: Instance
local Interaction = require(ServerRoot:WaitForChild("Util"):WaitForChild("Interaction") :: ModuleScript) :: any

local DialogueService = {}

type Session = {
	Id: number,
	NpcId: string,
	NodeId: string,
	LastActivity: number,
}

type Binding = {
	Prompt: ProximityPrompt,
	CreatedPrompt: boolean,
	Connection: RBXScriptConnection,
}

type ActionHandler = (player: Player, context: { NpcId: string, NodeId: string }) -> ()
type EntryResolver = (player: Player) -> string?

local sessions: { [Player]: Session } = {}
local bindings: { [string]: Binding } = {}
local lastStart: { [Player]: number } = {}
local lastRespond: { [Player]: number } = {}
local actionHandlers: { [string]: ActionHandler } = {}
local entryResolvers: { [string]: EntryResolver } = {}
local textVariables: { [string]: (player: Player) -> (string | number) } = {}
local warnedActions: { [string]: boolean } = {}
local nextSessionId = 0
local started = false

local showRemote: RemoteEvent
local endRemote: RemoteEvent
local respondRemote: RemoteEvent

local VALID_KINDS: { [string]: boolean } = {
	Advance = true,
	Choose = true,
	Cancel = true,
}

--------------------------------------------------------------------------------
-- Validasi config
--------------------------------------------------------------------------------

local function validateNpc(npcId: string, def: any): boolean
	local function fail(message: string): boolean
		warn(`[DialogueService] Config Npcs.{npcId}: {message}; NPC ini dilewati.`)
		return false
	end

	if type(def) ~= "table" then
		return fail("bukan table")
	end
	if type(def.DisplayName) ~= "string" or def.DisplayName == "" then
		return fail("DisplayName tidak valid")
	end
	if type(def.ModelName) ~= "string" or def.ModelName == "" then
		return fail("ModelName tidak valid")
	end
	if type(def.Nodes) ~= "table" or type(def.Start) ~= "string" or def.Nodes[def.Start] == nil then
		return fail("Start tidak menunjuk node yang ada")
	end

	for nodeId, node in def.Nodes do
		local where = `node '{nodeId}'`
		if type(node) ~= "table" then
			return fail(`{where} bukan table`)
		end
		if type(node.Text) ~= "string" or node.Text == "" or #node.Text > Config.MaxTextLength then
			return fail(`{where}: Text kosong atau lebih dari {Config.MaxTextLength} karakter`)
		end
		if node.Speaker ~= nil and (type(node.Speaker) ~= "string" or node.Speaker == "") then
			return fail(`{where}: Speaker tidak valid`)
		end
		if node.Action ~= nil and type(node.Action) ~= "string" then
			return fail(`{where}: Action harus string`)
		end
		if node.Next ~= nil and (type(node.Next) ~= "string" or def.Nodes[node.Next] == nil) then
			return fail(`{where}: Next menunjuk node yang tidak ada`)
		end
		if node.Choices ~= nil then
			if type(node.Choices) ~= "table" or #node.Choices == 0 or #node.Choices > Config.MaxChoices then
				return fail(`{where}: Choices harus 1..{Config.MaxChoices} item`)
			end
			if node.Next ~= nil then
				return fail(`{where}: tidak boleh punya Next dan Choices sekaligus`)
			end
			for index, choice in node.Choices do
				if type(choice) ~= "table" or type(choice.Text) ~= "string" or choice.Text == "" then
					return fail(`{where}: Choices[{index}].Text tidak valid`)
				end
				if choice.Action ~= nil and type(choice.Action) ~= "string" then
					return fail(`{where}: Choices[{index}].Action harus string`)
				end
				if choice.Next ~= nil and (type(choice.Next) ~= "string" or def.Nodes[choice.Next] == nil) then
					return fail(`{where}: Choices[{index}].Next menunjuk node yang tidak ada`)
				end
			end
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- Sesi
--------------------------------------------------------------------------------

local function endSession(player: Player, reason: string)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	if player.Parent ~= nil then
		endRemote:FireClient(player, session.Id, reason)
	end
end

local function runAction(player: Player, actionName: string, session: Session)
	local handler = actionHandlers[actionName]
	if handler == nil then
		if not warnedActions[actionName] then
			warnedActions[actionName] = true
			warn(`[DialogueService] Action '{actionName}' belum punya handler; dilewati.`)
		end
		return
	end
	local ok, err = pcall(handler, player, { NpcId = session.NpcId, NodeId = session.NodeId })
	if not ok then
		warn(`[DialogueService] Handler action '{actionName}' error: {tostring(err)}`)
	end
end

-- Ganti {Nama} dengan nilai variabel terdaftar; {Nama} tak dikenal dibiarkan apa adanya.
local function renderText(player: Player, text: string): string
	local rendered = string.gsub(text, "{(%w+)}", function(name: string): string?
		local resolve = textVariables[name]
		if resolve == nil then
			return nil
		end
		local ok, value = pcall(resolve, player)
		if ok and (type(value) == "string" or type(value) == "number") then
			return tostring(value)
		end
		return nil
	end)
	return rendered
end

local function buildPayload(player: Player, session: Session, npcDef: any, node: any): any
	local choiceTexts: { string } = {}
	local hasChoices = node.Choices ~= nil and #node.Choices > 0
	if hasChoices then
		for _, choice in node.Choices do
			table.insert(choiceTexts, choice.Text)
		end
	end
	return {
		SessionId = session.Id,
		Speaker = node.Speaker or npcDef.DisplayName,
		Text = renderText(player, node.Text),
		Choices = if hasChoices then choiceTexts else nil,
		IsLast = (not hasChoices) and node.Next == nil,
	}
end

local function enterNode(player: Player, session: Session, nodeId: string)
	local npcDef = Config.Npcs[session.NpcId]
	local node = if npcDef ~= nil then npcDef.Nodes[nodeId] else nil
	if node == nil then
		endSession(player, "InvalidNode")
		return
	end

	session.NodeId = nodeId
	session.LastActivity = os.clock()

	if node.Action ~= nil then
		runAction(player, node.Action, session)
		-- Handler boleh mengakhiri dialog (mis. lewat DialogueService.End).
		if sessions[player] ~= session then
			return
		end
	end

	showRemote:FireClient(player, buildPayload(player, session, npcDef, node))
end

-- nil = sesi masih valid; string = alasan sesi harus berakhir.
local function getInvalidReason(player: Player, session: Session): string?
	local root = Interaction.GetAliveRoot(player)
	if root == nil then
		return "Dead"
	end
	local binding = bindings[session.NpcId]
	if binding == nil or binding.Prompt.Parent == nil then
		return "NpcGone"
	end
	local promptPosition = Interaction.GetPromptPosition(binding.Prompt)
	if promptPosition == nil then
		return "NpcGone"
	end
	local maxDistance = binding.Prompt.MaxActivationDistance + Config.LeaveTolerance
	if (root.Position - promptPosition).Magnitude > maxDistance then
		return "TooFar"
	end
	return nil
end

local function onTriggered(npcId: string, player: Player)
	local last = lastStart[player]
	if last == nil then
		return -- pemain sudah keluar
	end
	local now = os.clock()
	if now - last < Config.StartCooldown then
		return
	end

	local binding = bindings[npcId]
	local npcDef = Config.Npcs[npcId]
	if binding == nil or npcDef == nil then
		return
	end

	-- Jangan percaya client: Triggered bisa dipanggil exploit dari jauh.
	local root = Interaction.GetAliveRoot(player)
	if root == nil then
		return
	end
	local promptPosition = Interaction.GetPromptPosition(binding.Prompt)
	if promptPosition == nil then
		return
	end
	local maxDistance = binding.Prompt.MaxActivationDistance + Config.StartTolerance
	if (root.Position - promptPosition).Magnitude > maxDistance then
		return
	end

	lastStart[player] = now

	-- Sesi lama (jika ada) diganti; client menerima DialogueEnd lalu DialogueShow.
	endSession(player, "Replaced")

	local startId: string = npcDef.Start
	local resolver = entryResolvers[npcId]
	if resolver ~= nil then
		local ok, result = pcall(resolver, player)
		if not ok then
			warn(`[DialogueService] EntryResolver '{npcId}' error: {tostring(result)}`)
		elseif type(result) == "string" and npcDef.Nodes[result] ~= nil then
			startId = result
		elseif result ~= nil then
			warn(`[DialogueService] EntryResolver '{npcId}' mengembalikan node tidak valid; memakai Start.`)
		end
	end

	nextSessionId += 1
	local session: Session = {
		Id = nextSessionId,
		NpcId = npcId,
		NodeId = startId,
		LastActivity = now,
	}
	sessions[player] = session
	enterNode(player, session, startId)
end

local function onRespond(player: Player, sessionId: any, kind: any, index: any)
	if type(sessionId) ~= "number" or type(kind) ~= "string" or VALID_KINDS[kind] ~= true then
		return
	end

	local session = sessions[player]
	if session == nil or session.Id ~= sessionId then
		return
	end

	-- Cancel selalu diizinkan (murah, dan mencegah sesi menggantung).
	if kind == "Cancel" then
		endSession(player, "Cancelled")
		return
	end

	-- Rate limit Advance/Choose.
	local now = os.clock()
	local last = lastRespond[player]
	if last == nil or now - last < Config.RespondInterval then
		return
	end
	lastRespond[player] = now

	local reason = getInvalidReason(player, session)
	if reason ~= nil then
		endSession(player, reason)
		return
	end

	local npcDef = Config.Npcs[session.NpcId]
	local node = if npcDef ~= nil then npcDef.Nodes[session.NodeId] else nil
	if node == nil then
		endSession(player, "InvalidNode")
		return
	end

	session.LastActivity = now
	local hasChoices = node.Choices ~= nil and #node.Choices > 0

	if kind == "Advance" then
		if hasChoices then
			return -- node ini butuh pilihan, bukan Advance
		end
		if node.Next ~= nil then
			enterNode(player, session, node.Next)
		else
			endSession(player, "Finished")
		end
		return
	end

	-- kind == "Choose"
	if not hasChoices then
		return
	end
	if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > #node.Choices then
		return
	end
	local choice = node.Choices[index]
	if choice.Action ~= nil then
		runAction(player, choice.Action, session)
		if sessions[player] ~= session then
			return
		end
	end
	if choice.Next ~= nil then
		enterNode(player, session, choice.Next)
	else
		endSession(player, "Finished")
	end
end

--------------------------------------------------------------------------------
-- Pengikatan NPC
--------------------------------------------------------------------------------

local function bindNpc(npcId: string, def: any, target: Instance): boolean
	if bindings[npcId] ~= nil then
		return true
	end
	local prompt, created = Interaction.FindOrCreatePrompt(target, {
		Name = "DialoguePrompt",
		ActionText = Config.Prompt.ActionText,
		ObjectText = def.DisplayName,
		MaxActivationDistance = Config.Prompt.Distance,
	})
	if prompt == nil then
		warn(`[DialogueService] {target:GetFullName()} tidak punya ProximityPrompt dan bukan Model/Part; dilewati.`)
		return false
	end

	bindings[npcId] = {
		Prompt = prompt,
		CreatedPrompt = created,
		Connection = prompt.Triggered:Connect(function(player: Player)
			onTriggered(npcId, player)
		end),
	}
	return true
end

local function tryBindByName(npcId: string, def: any): boolean
	local target = Workspace:FindFirstChild(def.ModelName, true)
	if target == nil then
		return false
	end
	return bindNpc(npcId, def, target)
end

--------------------------------------------------------------------------------
-- Siklus pemain
--------------------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	lastStart[player] = -math.huge
	lastRespond[player] = -math.huge
	player.CharacterRemoving:Connect(function()
		endSession(player, "Dead")
	end)
end

local function onPlayerRemoving(player: Player)
	sessions[player] = nil
	lastStart[player] = nil
	lastRespond[player] = nil
end

local function checkSessions()
	local now = os.clock()
	for player, session in sessions do
		local reason = getInvalidReason(player, session)
		if reason == nil and now - session.LastActivity > Config.IdleTimeout then
			reason = "Idle"
		end
		if reason ~= nil then
			endSession(player, reason)
		end
	end
end

--------------------------------------------------------------------------------
-- API publik
--------------------------------------------------------------------------------

function DialogueService.RegisterAction(name: string, handler: ActionHandler)
	if type(name) ~= "string" or name == "" or type(handler) ~= "function" then
		error("[DialogueService] RegisterAction butuh (name: string, handler: function)")
	end
	if actionHandlers[name] ~= nil then
		warn(`[DialogueService] Action '{name}' sudah terdaftar; handler lama ditimpa.`)
	end
	actionHandlers[name] = handler
end

function DialogueService.RegisterEntryResolver(npcId: string, resolver: EntryResolver)
	if Config.Npcs[npcId] == nil or type(resolver) ~= "function" then
		error("[DialogueService] RegisterEntryResolver butuh (npcId yang ada di config, resolver: function)")
	end
	entryResolvers[npcId] = resolver
end

function DialogueService.RegisterTextVariable(name: string, resolve: (player: Player) -> (string | number))
	if type(name) ~= "string" or string.match(name, "^%w+$") == nil or type(resolve) ~= "function" then
		error("[DialogueService] RegisterTextVariable butuh (name: huruf/angka saja, resolve: function)")
	end
	textVariables[name] = resolve
end

function DialogueService.IsInDialogue(player: Player): boolean
	return sessions[player] ~= nil
end

function DialogueService.End(player: Player, reason: string?)
	endSession(player, reason or "Ended")
end

function DialogueService.Start()
	if started then
		return
	end
	started = true

	showRemote = Remotes.Get("DialogueShow")
	endRemote = Remotes.Get("DialogueEnd")
	respondRemote = Remotes.Get("DialogueRespond")
	respondRemote.OnServerEvent:Connect(onRespond)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	for npcId, def in Config.Npcs do
		if not validateNpc(npcId, def) then
			continue
		end
		if not tryBindByName(npcId, def) then
			-- NPC belum ada saat start: tunggu sampai muncul di Workspace.
			local connection: RBXScriptConnection? = nil
			connection = Workspace.DescendantAdded:Connect(function(instance: Instance)
				if instance.Name == def.ModelName and tryBindByName(npcId, def) then
					if connection ~= nil then
						connection:Disconnect()
					end
				end
			end)
			task.delay(10, function()
				if bindings[npcId] == nil then
					warn(`[DialogueService] NPC '{def.ModelName}' (Npcs.{npcId}) belum ditemukan di Workspace setelah 10 detik.`)
				end
			end)
		end
	end

	task.spawn(function()
		while true do
			task.wait(Config.CheckInterval)
			checkSessions()
		end
	end)
end

return DialogueService
