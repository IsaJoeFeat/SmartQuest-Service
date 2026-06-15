--!strict
-- SmartQuestService v2
-- Server-authoritative quest/objective runtime.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local SharedFolder = ReplicatedStorage:WaitForChild("SmartQuestService")
local SmartQuestShared = require(SharedFolder:WaitForChild("SmartQuestShared"))
local SmartQuestConfig = require(SharedFolder:WaitForChild("SmartQuestConfig"))

local SmartQuestService = {}

SmartQuestService._quests = {}
SmartQuestService._playerStates = {}
SmartQuestService._connections = {}
SmartQuestService._zoneDebounce = {}
SmartQuestService._timerTokens = {}
SmartQuestService._rewardHandler = nil
SmartQuestService._conditionHandlers = {}
SmartQuestService._prerequisiteHandlers = {}
SmartQuestService._settings = SmartQuestConfig.Settings or {}
SmartQuestService._initialized = false

SmartQuestService.QuestStarted = SmartQuestShared.NewSignal("QuestStarted")
SmartQuestService.QuestCompleted = SmartQuestShared.NewSignal("QuestCompleted")
SmartQuestService.QuestFailed = SmartQuestShared.NewSignal("QuestFailed")
SmartQuestService.QuestAbandoned = SmartQuestShared.NewSignal("QuestAbandoned")
SmartQuestService.StepStarted = SmartQuestShared.NewSignal("StepStarted")
SmartQuestService.StepProgressed = SmartQuestShared.NewSignal("StepProgressed")
SmartQuestService.StepCompleted = SmartQuestShared.NewSignal("StepCompleted")
SmartQuestService.RewardGranted = SmartQuestShared.NewSignal("RewardGranted")

local function now(): number
	return SmartQuestShared.GetServerNow()
end

local function getOrCreateRemoteFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(SmartQuestShared.RemoteFolderName)
	if folder and folder:IsA("Folder") then
		return folder
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = SmartQuestShared.RemoteFolderName
	newFolder.Parent = ReplicatedStorage
	return newFolder
end

local function getOrCreateRemoteEvent(folder: Folder, name: string): RemoteEvent
	local remote = folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = name
	newRemote.Parent = folder
	return newRemote
end

local function getOrCreateRemoteFunction(folder: Folder, name: string): RemoteFunction
	local remote = folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end

	local newRemote = Instance.new("RemoteFunction")
	newRemote.Name = name
	newRemote.Parent = folder
	return newRemote
end

function SmartQuestService:_getRemoteEvent(name: string): RemoteEvent
	return getOrCreateRemoteEvent(getOrCreateRemoteFolder(), name)
end

function SmartQuestService:_getRemoteFunction(name: string): RemoteFunction
	return getOrCreateRemoteFunction(getOrCreateRemoteFolder(), name)
end

function SmartQuestService:SetRewardHandler(handler)
	assert(type(handler) == "function", "Reward handler must be a function.")
	self._rewardHandler = handler
end

function SmartQuestService:SetConditionHandler(name: string, handler)
	assert(type(name) == "string" and name ~= "", "Condition handler name must be a non-empty string.")
	assert(type(handler) == "function", "Condition handler must be a function.")
	self._conditionHandlers[name] = handler
end

function SmartQuestService:SetPrerequisiteHandler(name: string, handler)
	assert(type(name) == "string" and name ~= "", "Prerequisite handler name must be a non-empty string.")
	assert(type(handler) == "function", "Prerequisite handler must be a function.")
	self._prerequisiteHandlers[name] = handler
end

function SmartQuestService:RegisterQuest(quest)
	assert(type(quest) == "table", "Quest must be a table.")
	assert(type(quest.Id) == "string" and quest.Id ~= "", "Quest.Id must be a non-empty string.")
	assert(type(quest.Title) == "string" and quest.Title ~= "", "Quest.Title must be a non-empty string.")
	assert(type(quest.Steps) == "table" and #quest.Steps > 0, "Quest.Steps must be a non-empty array.")

	local seenSteps = {}
	for index, step in ipairs(quest.Steps) do
		assert(type(step.Id) == "string" and step.Id ~= "", `Quest {quest.Id} step #{index} needs a non-empty Id.`)
		assert(not seenSteps[step.Id], `Quest {quest.Id} has duplicate step Id: {step.Id}`)
		assert(type(step.Text) == "string" and step.Text ~= "", `Quest {quest.Id} step {step.Id} needs Text.`)
		seenSteps[step.Id] = true
		step.Required = math.max(1, tonumber(step.Required) or 1)
	end

	self._quests[quest.Id] = SmartQuestShared.DeepCopy(quest)
end

function SmartQuestService:RegisterQuests(quests)
	for _, quest in pairs(quests) do
		self:RegisterQuest(quest)
	end
end

function SmartQuestService:GetQuestDefinition(questId: string)
	return self._quests[questId]
end

function SmartQuestService:_getPlayerQuestTable(player: Player)
	local states = self._playerStates[player]
	if not states then
		states = {}
		self._playerStates[player] = states
	end
	return states
end

function SmartQuestService:GetQuestState(player: Player, questId: string)
	return self:_getPlayerQuestTable(player)[questId]
end

function SmartQuestService:IsQuestCompleted(player: Player, questId: string): boolean
	local state = self:GetQuestState(player, questId)
	return state ~= nil and state.Status == SmartQuestShared.Status.Completed
end

function SmartQuestService:IsQuestActive(player: Player, questId: string): boolean
	local state = self:GetQuestState(player, questId)
	return state ~= nil and state.Status == SmartQuestShared.Status.Active
end

function SmartQuestService:_buildInitialState(quest)
	local stepStates = {}

	for _, step in ipairs(quest.Steps) do
		stepStates[step.Id] = {
			Id = step.Id,
			Progress = 0,
			Required = step.Required or 1,
			Completed = false,
			StartedAt = nil,
			CompletedAt = nil,
			ExpiresAt = nil,
		}
	end

	return {
		Id = quest.Id,
		Status = SmartQuestShared.Status.Active,
		CurrentStepIndex = 1,
		Steps = stepStates,
		StartedAt = now(),
		CompletedAt = nil,
		FailedAt = nil,
		RepeatAvailableAt = nil,
		FailReason = nil,
	}
end

function SmartQuestService:_getCurrentStep(quest, state)
	return quest.Steps[state.CurrentStepIndex]
end

function SmartQuestService:_getStepState(state, stepId: string)
	return state.Steps[stepId]
end

function SmartQuestService:_makeTimerKey(player: Player, questId: string, stepId: string): string
	return tostring(player.UserId) .. ":" .. questId .. ":" .. stepId
end

function SmartQuestService:_newTimerToken(player: Player, questId: string, stepId: string): number
	local key = self:_makeTimerKey(player, questId, stepId)
	local token = (self._timerTokens[key] or 0) + 1
	self._timerTokens[key] = token
	return token
end

function SmartQuestService:_isTimerTokenValid(player: Player, questId: string, stepId: string, token: number): boolean
	return self._timerTokens[self:_makeTimerKey(player, questId, stepId)] == token
end

function SmartQuestService:_resolveTarget(step)
	if step.TargetTag then
		local tagged = CollectionService:GetTagged(step.TargetTag)
		for _, instance in ipairs(tagged) do
			if instance:IsDescendantOf(game) then
				return instance
			end
		end
	end

	if step.TargetName then
		local found = workspace:FindFirstChild(step.TargetName, true)
		if found then
			return found
		end
	end

	if step.Target then
		local found = workspace:FindFirstChild(step.Target, true)
		if found then
			return found
		end
	end

	return nil
end

function SmartQuestService:_buildMarkerPayload(quest, state)
	local step = self:_getCurrentStep(quest, state)
	if not step or not step.Marker then
		return nil
	end

	local target = self:_resolveTarget(step)
	if not target then
		return nil
	end

	return {
		QuestId = quest.Id,
		StepId = step.Id,
		Text = step.MarkerText or step.Text,
		Target = target,
	}
end

function SmartQuestService:_buildClientPayload(player: Player, questId: string)
	local quest = self:GetQuestDefinition(questId)
	local state = self:GetQuestState(player, questId)
	if not quest or not state then
		return nil
	end

	return {
		Quest = quest,
		State = state,
		Marker = self:_buildMarkerPayload(quest, state),
		ServerNow = now(),
	}
end

function SmartQuestService:_sendUpdate(player: Player, questId: string)
	local payload = self:_buildClientPayload(player, questId)
	if not payload then
		return
	end

	self:_getRemoteEvent(SmartQuestShared.UpdateRemoteName):FireClient(player, payload)
	self:_sendJournal(player)
end

function SmartQuestService:_toast(player: Player, text: string, toastType: string?)
	self:_getRemoteEvent(SmartQuestShared.ToastRemoteName):FireClient(player, {
		Text = text,
		Type = toastType or "Info",
	})
end

function SmartQuestService:_sendJournal(player: Player)
	self:_getRemoteEvent(SmartQuestShared.JournalRemoteName):FireClient(player, self:GetJournalSnapshot(player))
end

function SmartQuestService:GetJournalSnapshot(player: Player)
	local states = self:_getPlayerQuestTable(player)
	local quests = {}

	for questId, quest in pairs(self._quests) do
		table.insert(quests, {
			Quest = quest,
			State = states[questId],
			CanStart = self:CanStartQuest(player, questId),
		})
	end

	table.sort(quests, function(a, b)
		return a.Quest.Title < b.Quest.Title
	end)

	return {
		Version = SmartQuestShared.Version,
		Quests = quests,
		ServerNow = now(),
	}
end

function SmartQuestService:_checkQuestList(player: Player, questIds, expectedStatus: string): (boolean, string?)
	if type(questIds) ~= "table" then
		return true, nil
	end

	for _, requiredQuestId in ipairs(questIds) do
		local state = self:GetQuestState(player, requiredQuestId)
		if not state or state.Status ~= expectedStatus then
			return false, `Requires quest {requiredQuestId} to be {expectedStatus}.`
		end
	end

	return true, nil
end

function SmartQuestService:_passesCustomChecks(player: Player, checks, handlers, quest, step)
	if type(checks) ~= "table" then
		return true, nil
	end

	for checkName, checkValue in pairs(checks) do
		local handler = handlers[checkName]
		if not handler then
			return false, `Missing SmartQuest handler: {checkName}`
		end

		local ok, reason = handler(player, checkValue, quest, step)
		if not ok then
			return false, reason or `Custom check failed: {checkName}`
		end
	end

	return true, nil
end

function SmartQuestService:MeetsPrerequisites(player: Player, questId: string): (boolean, string?)
	local quest = self:GetQuestDefinition(questId)
	if not quest then
		return false, "Unknown quest."
	end

	local prereq = quest.Prerequisites
	if type(prereq) ~= "table" then
		return true, nil
	end

	local ok, reason = self:_checkQuestList(player, prereq.CompletedQuests, SmartQuestShared.Status.Completed)
	if not ok then return false, reason end

	ok, reason = self:_checkQuestList(player, prereq.ActiveQuests, SmartQuestShared.Status.Active)
	if not ok then return false, reason end

	if type(prereq.NotCompletedQuests) == "table" then
		for _, blockedQuestId in ipairs(prereq.NotCompletedQuests) do
			if self:IsQuestCompleted(player, blockedQuestId) then
				return false, `Quest {blockedQuestId} must not be completed.`
			end
		end
	end

	return self:_passesCustomChecks(player, prereq.Custom, self._prerequisiteHandlers, quest, nil)
end

function SmartQuestService:MeetsStepConditions(player: Player, questId: string, stepId: string): (boolean, string?)
	local quest = self:GetQuestDefinition(questId)
	if not quest then
		return false, "Unknown quest."
	end

	local step = nil
	for _, candidate in ipairs(quest.Steps) do
		if candidate.Id == stepId then
			step = candidate
			break
		end
	end

	if not step or type(step.Conditions) ~= "table" then
		return true, nil
	end

	local ok, reason = self:_checkQuestList(player, step.Conditions.CompletedQuests, SmartQuestShared.Status.Completed)
	if not ok then return false, reason end

	return self:_passesCustomChecks(player, step.Conditions.Custom, self._conditionHandlers, quest, step)
end

function SmartQuestService:CanStartQuest(player: Player, questId: string): (boolean, string?)
	local quest = self:GetQuestDefinition(questId)
	if not quest then
		return false, "Unknown quest."
	end

	local existing = self:GetQuestState(player, questId)
	if existing then
		if existing.Status == SmartQuestShared.Status.Active then
			return false, "Quest already active."
		end

		if existing.Status == SmartQuestShared.Status.Completed and not quest.Repeatable then
			return false, "Quest already completed."
		end

		if quest.Repeatable and existing.RepeatAvailableAt and now() < existing.RepeatAvailableAt then
			return false, `Quest is on cooldown for {math.ceil(existing.RepeatAvailableAt - now())} seconds.`
		end
	end

	return self:MeetsPrerequisites(player, questId)
end

function SmartQuestService:_activateCurrentStep(player: Player, questId: string)
	local quest = self:GetQuestDefinition(questId)
	local state = self:GetQuestState(player, questId)
	if not quest or not state or state.Status ~= SmartQuestShared.Status.Active then
		return
	end

	local step = self:_getCurrentStep(quest, state)
	if not step then
		return
	end

	local stepState = self:_getStepState(state, step.Id)
	if not stepState then
		return
	end

	local currentTime = now()
	stepState.StartedAt = currentTime
	stepState.ExpiresAt = step.TimeLimit and (currentTime + step.TimeLimit) or nil

	self.StepStarted:Fire(player, questId, step.Id, quest, step)

	local token = self:_newTimerToken(player, questId, step.Id)

	if step.Type == SmartQuestShared.StepType.Timer and step.Duration and step.Duration > 0 then
		task.delay(step.Duration, function()
			if self:_isTimerTokenValid(player, questId, step.Id, token) then
				self:Progress(player, questId, step.Id, step.Required or 1)
			end
		end)
	end

	if step.TimeLimit and step.TimeLimit > 0 then
		task.delay(step.TimeLimit, function()
			if not self:_isTimerTokenValid(player, questId, step.Id, token) then
				return
			end

			local latestState = self:GetQuestState(player, questId)
			local latestQuest = self:GetQuestDefinition(questId)
			if not latestState or not latestQuest or latestState.Status ~= SmartQuestShared.Status.Active then
				return
			end

			local activeStep = self:_getCurrentStep(latestQuest, latestState)
			if activeStep and activeStep.Id == step.Id then
				if step.FailQuestOnTimeout then
					self:FailQuest(player, questId, "Time limit expired.")
				else
					self:_toast(player, "Objective time limit expired", "Warning")
				end
			end
		end)
	end

	self:_sendUpdate(player, questId)
end

function SmartQuestService:StartQuest(player: Player, questId: string): boolean
	local quest = self:GetQuestDefinition(questId)
	if not quest then
		warn(`[SmartQuestService] Cannot start unknown quest: {questId}`)
		return false
	end

	local canStart, reason = self:CanStartQuest(player, questId)
	if not canStart then
		self:_toast(player, reason or "Cannot start quest.", "Error")
		return false
	end

	local states = self:_getPlayerQuestTable(player)
	states[questId] = self:_buildInitialState(quest)

	self:_toast(player, `Quest started: {quest.Title}`, "QuestStarted")
	self.QuestStarted:Fire(player, questId, quest)
	self:_activateCurrentStep(player, questId)
	return true
end

function SmartQuestService:AbandonQuest(player: Player, questId: string): boolean
	local state = self:GetQuestState(player, questId)
	if not state or state.Status ~= SmartQuestShared.Status.Active then
		return false
	end

	state.Status = SmartQuestShared.Status.Abandoned
	state.FailReason = "Abandoned"
	self.QuestAbandoned:Fire(player, questId)
	self:_sendUpdate(player, questId)
	self:_toast(player, "Quest abandoned", "Warning")
	return true
end

function SmartQuestService:FailQuest(player: Player, questId: string, reason: string?): boolean
	local state = self:GetQuestState(player, questId)
	if not state or state.Status ~= SmartQuestShared.Status.Active then
		return false
	end

	state.Status = SmartQuestShared.Status.Failed
	state.FailedAt = now()
	state.FailReason = reason
	self.QuestFailed:Fire(player, questId, reason)
	self:_sendUpdate(player, questId)
	self:_toast(player, reason or "Quest failed", "QuestFailed")
	return true
end

function SmartQuestService:CompleteQuest(player: Player, questId: string): boolean
	local quest = self:GetQuestDefinition(questId)
	local state = self:GetQuestState(player, questId)

	if not quest or not state or state.Status ~= SmartQuestShared.Status.Active then
		return false
	end

	state.Status = SmartQuestShared.Status.Completed
	state.CompletedAt = now()

	if quest.Repeatable then
		state.RepeatAvailableAt = now() + (quest.RepeatCooldown or 0)
	end

	if self._rewardHandler and quest.Rewards then
		local ok, err = pcall(function()
			self._rewardHandler(player, quest.Rewards, quest, state)
		end)
		if not ok then
			warn(`[SmartQuestService] RewardHandler error for {questId}: {err}`)
		else
			self.RewardGranted:Fire(player, questId, quest.Rewards)
		end
	end

	self.QuestCompleted:Fire(player, questId, quest, quest.Rewards)
	self:_sendUpdate(player, questId)
	self:_toast(player, `Quest completed: {quest.Title}`, "QuestCompleted")
	return true
end

function SmartQuestService:Progress(player: Player, questId: string, stepId: string, amount: number?): boolean
	local quest = self:GetQuestDefinition(questId)
	if not quest then
		warn(`[SmartQuestService] Unknown quest: {questId}`)
		return false
	end

	local state = self:GetQuestState(player, questId)
	if not state then
		if not self:StartQuest(player, questId) then
			return false
		end
		state = self:GetQuestState(player, questId)
	end

	if not state or state.Status ~= SmartQuestShared.Status.Active then
		return false
	end

	local currentStep = self:_getCurrentStep(quest, state)
	if not currentStep or currentStep.Id ~= stepId then
		return false
	end

	local conditionsOk, reason = self:MeetsStepConditions(player, questId, stepId)
	if not conditionsOk then
		self:_toast(player, reason or "Objective conditions not met.", "Error")
		return false
	end

	local stepState = self:_getStepState(state, stepId)
	if not stepState or stepState.Completed then
		return false
	end

	local delta = amount or 1
	stepState.Progress = SmartQuestShared.ClampProgress(stepState.Progress + delta, stepState.Required)
	self.StepProgressed:Fire(player, questId, stepId, stepState.Progress, stepState.Required)

	if stepState.Progress >= stepState.Required then
		stepState.Completed = true
		stepState.CompletedAt = now()
		self.StepCompleted:Fire(player, questId, stepId, quest, currentStep)
		self:_toast(player, currentStep.Text, "StepCompleted")

		if state.CurrentStepIndex >= #quest.Steps then
			self:CompleteQuest(player, questId)
			return true
		else
			state.CurrentStepIndex += 1
			self:_activateCurrentStep(player, questId)
			return true
		end
	end

	self:_sendUpdate(player, questId)
	return true
end

function SmartQuestService:ResetQuest(player: Player, questId: string): boolean
	local states = self:_getPlayerQuestTable(player)
	if not states[questId] then
		return false
	end

	states[questId] = nil
	self:_sendJournal(player)
	return true
end

function SmartQuestService:ResetPlayer(player: Player)
	self._playerStates[player] = {}
	self:_sendJournal(player)
end

function SmartQuestService:GetAllStates(player: Player)
	return self:_getPlayerQuestTable(player)
end

function SmartQuestService:_findPromptParent(instance: Instance): Instance?
	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		if instance.PrimaryPart then
			return instance.PrimaryPart
		end

		return instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

function SmartQuestService:_readQuestStepAttributes(instance: Instance)
	local questId = instance:GetAttribute("QuestId")
	local stepId = instance:GetAttribute("StepId")

	if type(questId) ~= "string" or questId == "" then
		return nil, nil, "Missing QuestId attribute."
	end

	if type(stepId) ~= "string" or stepId == "" then
		return nil, nil, "Missing StepId attribute."
	end

	return questId, stepId, nil
end

function SmartQuestService:_setupQuestGiver(instance: Instance)
	if self._connections[instance] then return end

	local questId = instance:GetAttribute("QuestId")
	if type(questId) ~= "string" or questId == "" then
		warn(`[SmartQuestService] SmartQuestGiver missing QuestId: {instance:GetFullName()}`)
		return
	end

	local promptParent = self:_findPromptParent(instance)
	if not promptParent then
		warn(`[SmartQuestService] SmartQuestGiver has no BasePart: {instance:GetFullName()}`)
		return
	end

	local prompt = promptParent:FindFirstChild("SmartQuestGiverPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SmartQuestGiverPrompt"
		prompt.Parent = promptParent
	end

	prompt.ActionText = tostring(instance:GetAttribute("PromptText") or "Start Quest")
	prompt.ObjectText = tostring(instance:GetAttribute("ObjectText") or "Quest")
	prompt.HoldDuration = tonumber(instance:GetAttribute("HoldDuration")) or self._settings.DefaultPromptHoldDuration or 0
	prompt.MaxActivationDistance = tonumber(instance:GetAttribute("MaxActivationDistance")) or self._settings.DefaultPromptDistance or 10
	prompt.RequiresLineOfSight = false

	self._connections[instance] = prompt.Triggered:Connect(function(player)
		self:StartQuest(player, questId)
	end)
end

function SmartQuestService:_setupInteract(instance: Instance)
	if self._connections[instance] then return end

	local questId, stepId, err = self:_readQuestStepAttributes(instance)
	if err then
		warn(`[SmartQuestService] SmartQuestInteract {instance:GetFullName()}: {err}`)
		return
	end

	local promptParent = self:_findPromptParent(instance)
	if not promptParent then
		warn(`[SmartQuestService] SmartQuestInteract has no BasePart: {instance:GetFullName()}`)
		return
	end

	local prompt = promptParent:FindFirstChild("SmartQuestPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SmartQuestPrompt"
		prompt.Parent = promptParent
	end

	prompt.ActionText = tostring(instance:GetAttribute("PromptText") or "Interact")
	prompt.ObjectText = tostring(instance:GetAttribute("ObjectText") or "")
	prompt.HoldDuration = tonumber(instance:GetAttribute("HoldDuration")) or self._settings.DefaultPromptHoldDuration or 0
	prompt.MaxActivationDistance = tonumber(instance:GetAttribute("MaxActivationDistance")) or self._settings.DefaultPromptDistance or 10
	prompt.RequiresLineOfSight = false

	self._connections[instance] = prompt.Triggered:Connect(function(player)
		self:Progress(player, questId, stepId, tonumber(instance:GetAttribute("Amount")) or 1)
	end)
end

function SmartQuestService:_setupZone(instance: Instance)
	if self._connections[instance] then return end
	if not instance:IsA("BasePart") then
		warn(`[SmartQuestService] SmartQuestZone must be a BasePart: {instance:GetFullName()}`)
		return
	end

	local questId, stepId, err = self:_readQuestStepAttributes(instance)
	if err then
		warn(`[SmartQuestService] SmartQuestZone {instance:GetFullName()}: {err}`)
		return
	end

	self._zoneDebounce[instance] = {}
	self._connections[instance] = instance.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		local lastTouch = self._zoneDebounce[instance][player]
		if lastTouch and os.clock() - lastTouch < 1 then return end
		self._zoneDebounce[instance][player] = os.clock()

		self:Progress(player, questId, stepId, tonumber(instance:GetAttribute("Amount")) or 1)
	end)
end

function SmartQuestService:SetupTaggedObjects()
	if self._settings.AutoBindQuestGivers ~= false then
		for _, instance in ipairs(CollectionService:GetTagged("SmartQuestGiver")) do self:_setupQuestGiver(instance) end
		CollectionService:GetInstanceAddedSignal("SmartQuestGiver"):Connect(function(instance) self:_setupQuestGiver(instance) end)
	end

	if self._settings.AutoBindInteractables ~= false then
		for _, instance in ipairs(CollectionService:GetTagged("SmartQuestInteract")) do self:_setupInteract(instance) end
		CollectionService:GetInstanceAddedSignal("SmartQuestInteract"):Connect(function(instance) self:_setupInteract(instance) end)
	end

	if self._settings.AutoBindZones ~= false then
		for _, instance in ipairs(CollectionService:GetTagged("SmartQuestZone")) do self:_setupZone(instance) end
		CollectionService:GetInstanceAddedSignal("SmartQuestZone"):Connect(function(instance) self:_setupZone(instance) end)
	end
end

function SmartQuestService:ValidateSetup()
	local seen = {}
	for questId, quest in pairs(self._quests) do
		if seen[questId] then warn(`[SmartQuestService] Duplicate quest id: {questId}`) end
		seen[questId] = true

		local stepIds = {}
		for _, step in ipairs(quest.Steps) do
			if stepIds[step.Id] then warn(`[SmartQuestService] Duplicate step {step.Id} in quest {questId}`) end
			stepIds[step.Id] = true
			if step.Marker and not (step.TargetTag or step.TargetName or step.Target) then
				warn(`[SmartQuestService] Marker step {questId}.{step.Id} has no target field.`)
			end
		end
	end

	for _, tagName in ipairs({"SmartQuestGiver", "SmartQuestInteract", "SmartQuestZone"}) do
		for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
			if type(instance:GetAttribute("QuestId")) ~= "string" then
				warn(`[SmartQuestService] {tagName} missing QuestId: {instance:GetFullName()}`)
			end
			if tagName ~= "SmartQuestGiver" and type(instance:GetAttribute("StepId")) ~= "string" then
				warn(`[SmartQuestService] {tagName} missing StepId: {instance:GetFullName()}`)
			end
		end
	end
end

function SmartQuestService:Init()
	if self._initialized then return end
	self._initialized = true

	self:_getRemoteEvent(SmartQuestShared.UpdateRemoteName)
	self:_getRemoteEvent(SmartQuestShared.ToastRemoteName)
	self:_getRemoteEvent(SmartQuestShared.JournalRemoteName)
	self:_getRemoteFunction(SmartQuestShared.RequestJournalRemoteName).OnServerInvoke = function(player)
		return self:GetJournalSnapshot(player)
	end

	self:RegisterQuests(SmartQuestConfig.Quests)

	if self._settings.EnableStartupValidation ~= false then
		self:ValidateSetup()
	end

	self:SetupTaggedObjects()

	Players.PlayerRemoving:Connect(function(player)
		self._playerStates[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		for _, quest in pairs(self._quests) do
			if quest.AutoStart then
				self:StartQuest(player, quest.Id)
			end
		end
		task.defer(function()
			self:_sendJournal(player)
		end)
	end)
end

return SmartQuestService
