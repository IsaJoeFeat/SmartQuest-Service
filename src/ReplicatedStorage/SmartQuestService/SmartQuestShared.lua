--!strict
-- SmartQuestShared
-- Shared constants and helpers for SmartQuestService.

local SmartQuestShared = {}

SmartQuestShared.Version = "2.0.0"

SmartQuestShared.Status = {
	NotStarted = "NotStarted",
	Active = "Active",
	Completed = "Completed",
	Failed = "Failed",
	Abandoned = "Abandoned",
}

SmartQuestShared.StepType = {
	Interact = "Interact",
	Collect = "Collect",
	Kill = "Kill",
	ReachZone = "ReachZone",
	Timer = "Timer",
	Custom = "Custom",
}

SmartQuestShared.RemoteFolderName = "SmartQuestRemotes"
SmartQuestShared.UpdateRemoteName = "SmartQuestUpdate"
SmartQuestShared.ToastRemoteName = "SmartQuestToast"
SmartQuestShared.JournalRemoteName = "SmartQuestJournal"
SmartQuestShared.RequestJournalRemoteName = "SmartQuestRequestJournal"

export type StepDefinition = {
	Id: string,
	Text: string,
	Type: string?,
	Target: string?,
	TargetName: string?,
	TargetTag: string?,
	Required: number?,
	Optional: boolean?,
	Marker: boolean?,
	MarkerText: string?,
	Duration: number?,
	TimeLimit: number?,
	FailQuestOnTimeout: boolean?,
	Conditions: {[string]: any}?,
}

export type QuestDefinition = {
	Id: string,
	Title: string,
	Description: string?,
	AutoStart: boolean?,
	Repeatable: boolean?,
	RepeatCooldown: number?,
	Prerequisites: {[string]: any}?,
	Steps: {StepDefinition},
	Rewards: {[string]: any}?,
	Metadata: {[string]: any}?,
}

export type StepState = {
	Id: string,
	Progress: number,
	Required: number,
	Completed: boolean,
	StartedAt: number?,
	CompletedAt: number?,
	ExpiresAt: number?,
}

export type QuestState = {
	Id: string,
	Status: string,
	CurrentStepIndex: number,
	Steps: {[string]: StepState},
	StartedAt: number?,
	CompletedAt: number?,
	FailedAt: number?,
	RepeatAvailableAt: number?,
	FailReason: string?,
}

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

return SmartQuestShared
