--!strict
--[[
	QuestNotify — logika murni notifikasi quest (tanpa Roblox API, mudah diuji).

	Dipakai NotificationController (client). Sumber data HANYA Player attribute
	Quest_<id>_State / Quest_<id>_Progress yang ditulis server (QuestService); client tidak
	pernah menentukan progres.

	QuestNotify.Format(text, vars) -> string
	    Mengganti {Count} {Target} {Npc}. Placeholder tak dikenal dibiarkan apa adanya.

	QuestNotify.Evaluate(lastProgress, state, progress) -> { ShowObjective, ShowPickupToast }
	    ShowObjective   : true bila state Active atau ReadyToTurnIn (tujuan terlihat).
	                      None dan Completed = false (tujuan hilang; Completed = sudah bicara + serah).
	    ShowPickupToast : true hanya bila progres NAIK dibanding nilai terakhir yang dilihat client
	                      dan quest sedang Active/ReadyToTurnIn. Mulai quest (0), reset (turun), dan
	                      nilai awal saat join tidak memicu toast.
]]

export type Result = {
	ShowObjective: boolean,
	ShowPickupToast: boolean,
}

local QuestNotify = {}

function QuestNotify.Format(text: string, vars: { [string]: string | number }): string
	local result = string.gsub(text, "{(%w+)}", function(key: string): string?
		local value = vars[key]
		if value == nil then
			return nil
		end
		return tostring(value)
	end)
	return result
end

function QuestNotify.Evaluate(lastProgress: number, state: string, progress: number): Result
	local active = state == "Active" or state == "ReadyToTurnIn"
	return {
		ShowObjective = active,
		ShowPickupToast = active and progress > lastProgress,
	}
end

return QuestNotify
