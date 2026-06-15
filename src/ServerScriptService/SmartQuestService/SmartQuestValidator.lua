--!strict
-- SmartQuestValidator
-- Runtime validation for quest config and tagged Studio setup.

local CollectionService = game:GetService("CollectionService")

local Validator = {}

local function push(messages, level, text)
	table.insert(messages, {
		Level = level,
		Text = text,
	})
end

local function stepExists(quest, stepId: string): boolean
	for _, step in ipairs(quest.Steps or {}) do
		if step.Id == stepId then
			return true
		end
	end
	return false
end

function Validator.Validate(quests, arcs, settings)
	local messages = {}
	local questIds = {}

	for questId, quest in pairs(quests or {}) do
		if questIds[questId] then
			push(messages, "Error", `Duplicate quest id: {questId}`)
		end
		questIds[questId] = true

		if quest.Id ~= questId then
			push(messages, "Warning", `Quest key {questId} does not match quest.Id {tostring(quest.Id)}`)
		end

		if type(quest.Steps) ~= "table" or #quest.Steps == 0 then
			push(messages, "Error", `Quest {questId} has no steps.`)
		else
			local stepIds = {}
			for _, step in ipairs(quest.Steps) do
				if type(step.Id) ~= "string" or step.Id == "" then
					push(messages, "Error", `Quest {questId} has a step with missing Id.`)
				elseif stepIds[step.Id] then
					push(messages, "Error", `Quest {questId} has duplicate step Id {step.Id}.`)
				end
				stepIds[step.Id] = true

				if step.Marker and not (step.TargetTag or step.TargetName or step.Target) then
					push(messages, "Warning", `Quest {questId}.{step.Id} has Marker enabled but no target field.`)
				end

				if step.Type == "Timer" and not step.Duration then
					push(messages, "Warning", `Quest {questId}.{step.Id} is Timer but has no Duration.`)
				end

				if step.Type == "Group" and type(step.Targets) ~= "table" then
					push(messages, "Warning", `Quest {questId}.{step.Id} is Group but has no Targets table.`)
				end
			end
		end

		if type(quest.Prerequisites) == "table" and type(quest.Prerequisites.CompletedQuests) == "table" then
			for _, prereqQuestId in ipairs(quest.Prerequisites.CompletedQuests) do
				if not quests[prereqQuestId] then
					push(messages, "Warning", `Quest {questId} requires missing quest {prereqQuestId}.`)
				end
			end
		end

		if type(quest.Completion) == "table" and quest.Completion.Mode == "ReturnToGiver" and not quest.Completion.GiverTag then
			push(messages, "Warning", `Quest {questId} uses ReturnToGiver but has no Completion.GiverTag.`)
		end
	end

	for arcId, arc in pairs(arcs or {}) do
		if type(arc.Quests) ~= "table" or #arc.Quests == 0 then
			push(messages, "Warning", `Quest arc {arcId} has no quests.`)
		else
			for _, questId in ipairs(arc.Quests) do
				if not quests[questId] then
					push(messages, "Warning", `Quest arc {arcId} references missing quest {questId}.`)
				end
			end
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged("SmartQuestGiver")) do
		local questId = instance:GetAttribute("QuestId")
		if type(questId) ~= "string" or not quests[questId] then
			push(messages, "Warning", `SmartQuestGiver {instance:GetFullName()} references missing QuestId {tostring(questId)}.`)
		end
	end

	for _, tagName in ipairs({"SmartQuestInteract", "SmartQuestZone"}) do
		for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
			local questId = instance:GetAttribute("QuestId")
			local stepId = instance:GetAttribute("StepId")
			local quest = type(questId) == "string" and quests[questId] or nil

			if not quest then
				push(messages, "Warning", `{tagName} {instance:GetFullName()} references missing QuestId {tostring(questId)}.`)
			elseif type(stepId) ~= "string" or not stepExists(quest, stepId) then
				push(messages, "Warning", `{tagName} {instance:GetFullName()} references missing StepId {tostring(stepId)} in quest {questId}.`)
			end
		end
	end

	return messages
end

function Validator.Print(messages)
	for _, message in ipairs(messages or {}) do
		if message.Level == "Error" then
			warn("[SmartQuestValidator][Error] " .. message.Text)
		else
			warn("[SmartQuestValidator][Warning] " .. message.Text)
		end
	end
end

return Validator
