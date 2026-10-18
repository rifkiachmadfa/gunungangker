--!strict
--[[
	Interaction (SERVER util) — helper kecil untuk sistem berbasis ProximityPrompt.

	GetAliveRoot(player)          -> HumanoidRootPart pemain bila karakter hidup, selain itu nil.
	GetPromptPosition(prompt)     -> posisi dunia prompt (Part / Attachment / Model pivot), atau nil.
	FindOrCreatePrompt(target, o) -> (prompt, dibuatServer). Memakai ProximityPrompt yang SUDAH ada
	                                 di target (rekursif); hanya membuat bila tidak ada dan target
	                                 adalah Model/Part. Tidak membuat Part atau aset lain.
]]

local Interaction = {}

export type PromptOptions = {
	Name: string,
	ActionText: string,
	ObjectText: string,
	MaxActivationDistance: number,
}

function Interaction.GetAliveRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

function Interaction.GetPromptPosition(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent == nil then
		return nil
	end
	if parent:IsA("BasePart") then
		return parent.Position
	elseif parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return nil
end

function Interaction.FindOrCreatePrompt(target: Instance, options: PromptOptions): (ProximityPrompt?, boolean)
	if target:IsA("ProximityPrompt") then
		return target, false
	end
	local existing = target:FindFirstChildWhichIsA("ProximityPrompt", true)
	if existing ~= nil then
		return existing, false
	end

	local host: Instance? = nil
	if target:IsA("BasePart") then
		host = target
	elseif target:IsA("Model") then
		host = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	if host == nil then
		return nil, false
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = options.Name
	prompt.ActionText = options.ActionText
	prompt.ObjectText = options.ObjectText
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = options.MaxActivationDistance
	prompt.Parent = host
	return prompt, true
end

return Interaction
