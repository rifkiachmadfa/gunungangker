--!strict
-- Bootstrap client. Setiap controller/UI dimulai di sini.

local Players = game:GetService("Players")

local UI = script:WaitForChild("UI")

local SurvivalHud = require(UI:WaitForChild("SurvivalHud") :: ModuleScript) :: any
SurvivalHud.Mount(Players.LocalPlayer)
