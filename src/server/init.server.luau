--!strict
-- Bootstrap server. Setiap service dimulai di sini agar urutan start terlihat jelas.

local Services = script:WaitForChild("Services")

local SurvivalService = require(Services:WaitForChild("SurvivalService") :: ModuleScript) :: any
SurvivalService.Start()

local ConsumableService = require(Services:WaitForChild("ConsumableService") :: ModuleScript) :: any
ConsumableService.Start()

local DialogueService = require(Services:WaitForChild("DialogueService") :: ModuleScript) :: any
DialogueService.Start()

local ResourceService = require(Services:WaitForChild("ResourceService") :: ModuleScript) :: any
ResourceService.Start()

local QuestService = require(Services:WaitForChild("QuestService") :: ModuleScript) :: any
QuestService.Start()
