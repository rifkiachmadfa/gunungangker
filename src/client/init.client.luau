--!strict
-- Bootstrap client. Setiap controller/UI dimulai di sini.

local Players = game:GetService("Players")

local UI = script:WaitForChild("UI")

local Controllers = script:WaitForChild("Controllers")

local SurvivalHud = require(UI:WaitForChild("SurvivalHud") :: ModuleScript) :: any
SurvivalHud.Mount(Players.LocalPlayer)

local DialogueView = require(UI:WaitForChild("DialogueView") :: ModuleScript) :: any
local DialogueController = require(Controllers:WaitForChild("DialogueController") :: ModuleScript) :: any
DialogueController.Start(Players.LocalPlayer, DialogueView)

local ResourceRenderer = require(Controllers:WaitForChild("ResourceRenderer") :: ModuleScript) :: any
ResourceRenderer.Start(Players.LocalPlayer)
