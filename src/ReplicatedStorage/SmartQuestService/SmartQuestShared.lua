--!strict
-- SmartQuestShared
-- Small shared helpers/types for SmartQuestService.
-- Keep this game-agnostic.

local SmartQuestShared = {}

export type StepDefinition = {
	Id: string,
	Text: string,
	Type: string?,
	Target: string?,
	Required: number?,
	Optional: boolean?,
}

export type QuestDefinition = {
	Id: string,
	Title: string,
	Description: string?,
	AutoStart: boolean?,
	Steps: {StepDefinition},
	Rewards: {[string]: any}?,
}

export type StepState = {
	Id: string,
	Progress: number,
	Required: number,
	Completed: boolean,
}

export type QuestState = {
	Id: string,
	Status: string, -- NotStarted | Active | Completed | Failed
	CurrentStepIndex: number,
	Steps: {[string]: StepState},
}

SmartQuestShared.Status = {
	NotStarted = "NotStarted",
	Active = "Active",
	Completed = "Completed",
	Failed = "Failed",
}

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

return SmartQuestShared
