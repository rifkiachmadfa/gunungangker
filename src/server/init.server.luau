--!strict
-- Bootstrap server. Setiap service dimulai di sini agar urutan start terlihat jelas.

local Services = script:WaitForChild("Services")

local SurvivalService = require(Services:WaitForChild("SurvivalService") :: ModuleScript) :: any
SurvivalService.Start()
