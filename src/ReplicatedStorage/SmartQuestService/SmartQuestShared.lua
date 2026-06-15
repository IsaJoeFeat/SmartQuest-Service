--!strict
-- SmartQuestShared
-- Shared constants and helpers for SmartQuestService.

local SmartQuestShared = {}

SmartQuestShared.Version = "3.0.0"

SmartQuestShared.Status = {
	NotStarted = "NotStarted",
	Locked = "Locked",
	Available = "Available",
	Active = "Active",
	ReadyToTurnIn = "ReadyToTurnIn",
	Completed = "Completed",
	Failed = "Failed",
	Abandoned = "Abandoned",
	Cooldown = "Cooldown",
}

SmartQuestShared.StepType = {
	Interact = "Interact",
	Collect = "Collect",
	Kill = "Kill",
	ReachZone = "ReachZone",
	Timer = "Timer",
	Group = "Group",
	Custom = "Custom",
}

SmartQuestShared.ProgressionMode = {
	Sequential = "Sequential",
	Parallel = "Parallel",
}

SmartQuestShared.CompletionMode = {
	Auto = "Auto",
	ReturnToGiver = "ReturnToGiver",
	Manual = "Manual",
}

SmartQuestShared.RemoteFolderName = "SmartQuestRemotes"
SmartQuestShared.UpdateRemoteName = "SmartQuestUpdate"
SmartQuestShared.ToastRemoteName = "SmartQuestToast"
SmartQuestShared.JournalRemoteName = "SmartQuestJournal"
SmartQuestShared.RequestJournalRemoteName = "SmartQuestRequestJournal"
SmartQuestShared.ActionRemoteName = "SmartQuestAction"

function SmartQuestShared.NewSignal(name: string?)
	local bindable = Instance.new("BindableEvent")
	bindable.Name = name or "SmartQuestSignal"

	local signal = {}

	function signal:Connect(callback)
		return bindable.Event:Connect(callback)
	end

	function signal:Fire(...)
		bindable:Fire(...)
	end

	function signal:Destroy()
		bindable:Destroy()
	end

	return signal
end

function SmartQuestShared.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for k, v in pairs(value :: any) do
		copy[SmartQuestShared.DeepCopy(k)] = SmartQuestShared.DeepCopy(v)
	end

	return copy :: any
end

function SmartQuestShared.ClampProgress(progress: number, required: number): number
	if required <= 0 then
		return 0
	end

	return math.clamp(progress, 0, required)
end

function SmartQuestShared.FormatClock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%d:%02d", minutes, remainder)
end

function SmartQuestShared.GetServerNow(): number
	return workspace:GetServerTimeNow()
end

function SmartQuestShared.CountArray(value): number
	if type(value) ~= "table" then
		return 0
	end

	local count = 0
	for _ in ipairs(value) do
		count += 1
	end
	return count
end

function SmartQuestShared.IsArray(value): boolean
	if type(value) ~= "table" then
		return false
	end

	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" then
			return false
		end
		count += 1
	end

	return count == #value
end

return SmartQuestShared
