--!strict
-- SmartQuestService v3
-- Final reusable server-authoritative quest/objective runtime.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local SharedFolder = ReplicatedStorage:WaitForChild("SmartQuestService")
local SmartQuestShared = require(SharedFolder:WaitForChild("SmartQuestShared"))
local SmartQuestConfig = require(SharedFolder:WaitForChild("SmartQuestConfig"))
local RewardFormatter = require(SharedFolder:WaitForChild("SmartQuestRewardFormatter"))
local SmartQuestValidator = require(script.Parent:WaitForChild("SmartQuestValidator"))

local SmartQuestService = {}

SmartQuestService._quests = {}
SmartQuestService._arcs = SmartQuestConfig.QuestArcs or {}
SmartQuestService._settings = SmartQuestConfig.Settings or {}
SmartQuestService._playerData = {}
SmartQuestService._connections = {}
SmartQuestService._zoneDebounce = {}
SmartQuestService._timerTokens = {}
SmartQuestService._rewardHandler = nil
SmartQuestService._conditionHandlers = {}
SmartQuestService._prerequisiteHandlers = {}
SmartQuestService._persistenceAdapter = nil
SmartQuestService._initialized = false

SmartQuestService.QuestStarted = SmartQuestShared.NewSignal("QuestStarted")
SmartQuestService.QuestCompleted = SmartQuestShared.NewSignal("QuestCompleted")
SmartQuestService.QuestFailed = SmartQuestShared.NewSignal("QuestFailed")
SmartQuestService.QuestAbandoned = SmartQuestShared.NewSignal("QuestAbandoned")
SmartQuestService.QuestReadyToTurnIn = SmartQuestShared.NewSignal("QuestReadyToTurnIn")
SmartQuestService.StepStarted = SmartQuestShared.NewSignal("StepStarted")
SmartQuestService.StepProgressed = SmartQuestShared.NewSignal("StepProgressed")
SmartQuestService.StepCompleted = SmartQuestShared.NewSignal("StepCompleted")
SmartQuestService.RewardGranted = SmartQuestShared.NewSignal("RewardGranted")
SmartQuestService.TrackedQuestChanged = SmartQuestShared.NewSignal("TrackedQuestChanged")

local function now(): number
	return SmartQuestShared.GetServerNow()
end

local function remoteFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(SmartQuestShared.RemoteFolderName)
	if folder and folder:IsA("Folder") then return folder end
	folder = Instance.new("Folder")
	folder.Name = SmartQuestShared.RemoteFolderName
	folder.Parent = ReplicatedStorage
	return folder
end

local function remoteEvent(name: string): RemoteEvent
	local folder = remoteFolder()
	local remote = folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then return remote end
	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function remoteFunction(name: string): RemoteFunction
	local folder = remoteFolder()
	local remote = folder:FindFirstChild(name)
	if remote and remote:IsA("RemoteFunction") then return remote end
	remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	return remote
end

function SmartQuestService:_getPlayerData(player: Player)
	local data = self._playerData[player]
	if not data then
		data = {
			Quests = {},
			TrackedQuestId = nil,
			ActiveArcId = nil,
			ArcIndex = 0,
			Loaded = false,
		}
		self._playerData[player] = data
	end
	return data
end

function SmartQuestService:SetRewardHandler(handler)
	assert(type(handler) == "function", "Reward handler must be a function.")
	self._rewardHandler = handler
end

function SmartQuestService:SetPersistenceAdapter(adapter)
	assert(type(adapter) == "table", "Persistence adapter must be a table.")
	assert(type(adapter.Load) == "function", "Persistence adapter needs Load(player).")
	assert(type(adapter.Save) == "function", "Persistence adapter needs Save(player, data).")
	self._persistenceAdapter = adapter
end

function SmartQuestService:SetConditionHandler(name: string, handler)
	assert(type(handler) == "function", "Condition handler must be a function.")
	self._conditionHandlers[name] = handler
end

function SmartQuestService:SetPrerequisiteHandler(name: string, handler)
	assert(type(handler) == "function", "Prerequisite handler must be a function.")
	self._prerequisiteHandlers[name] = handler
end

function SmartQuestService:RegisterQuest(quest)
	assert(type(quest) == "table", "Quest must be a table.")
	assert(type(quest.Id) == "string" and quest.Id ~= "", "Quest.Id must be a non-empty string.")
	assert(type(quest.Title) == "string" and quest.Title ~= "", "Quest.Title must be a non-empty string.")
	assert(type(quest.Steps) == "table" and #quest.Steps > 0, "Quest.Steps must be a non-empty array.")

	for _, step in ipairs(quest.Steps) do
		step.Required = math.max(1, tonumber(step.Required) or 1)
	end

	quest.ProgressionMode = quest.ProgressionMode or SmartQuestShared.ProgressionMode.Sequential
	quest.Completion = quest.Completion or {Mode = SmartQuestShared.CompletionMode.Auto}
	self._quests[quest.Id] = SmartQuestShared.DeepCopy(quest)
end

function SmartQuestService:RegisterQuests(quests)
	for _, quest in pairs(quests or {}) do self:RegisterQuest(quest) end
end

function SmartQuestService:GetQuestDefinition(questId: string)
	return self._quests[questId]
end

function SmartQuestService:GetQuestState(player: Player, questId: string)
	return self:_getPlayerData(player).Quests[questId]
end

function SmartQuestService:GetAllStates(player: Player)
	return self:_getPlayerData(player).Quests
end

function SmartQuestService:_save(player: Player)
	if not self._persistenceAdapter then return end
	local data = self:_getPlayerData(player)
	local packed = {
		Quests = data.Quests,
		TrackedQuestId = data.TrackedQuestId,
		ActiveArcId = data.ActiveArcId,
		ArcIndex = data.ArcIndex,
	}
	local ok, err = pcall(function()
		self._persistenceAdapter.Save(player, SmartQuestShared.DeepCopy(packed))
	end)
	if not ok then warn(`[SmartQuestService] Save failed for {player.Name}: {err}`) end
end

function SmartQuestService:_load(player: Player)
	local data = self:_getPlayerData(player)
	if not self._persistenceAdapter then
		data.Loaded = true
		return
	end
	local ok, result = pcall(function()
		return self._persistenceAdapter.Load(player)
	end)
	if ok and type(result) == "table" then
		data.Quests = type(result.Quests) == "table" and result.Quests or {}
		data.TrackedQuestId = result.TrackedQuestId
		data.ActiveArcId = result.ActiveArcId
		data.ArcIndex = result.ArcIndex or 0
	elseif not ok then
		warn(`[SmartQuestService] Load failed for {player.Name}: {result}`)
	end
	data.Loaded = true
end

function SmartQuestService:_stepById(quest, stepId: string)
	for index, step in ipairs(quest.Steps) do
		if step.Id == stepId then return step, index end
	end
	return nil, nil
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
			GroupCompleted = {},
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

function SmartQuestService:_currentStep(quest, state)
	return quest.Steps[state.CurrentStepIndex]
end

function SmartQuestService:_allStepsCompleted(quest, state): boolean
	for _, step in ipairs(quest.Steps) do
		local stepState = state.Steps[step.Id]
		if not stepState or not stepState.Completed then return false end
	end
	return true
end

function SmartQuestService:_activeSteps(quest, state)
	if quest.ProgressionMode == SmartQuestShared.ProgressionMode.Parallel then
		local steps = {}
		for _, step in ipairs(quest.Steps) do
			local stepState = state.Steps[step.Id]
			if stepState and not stepState.Completed then table.insert(steps, step) end
		end
		return steps
	end
	local step = self:_currentStep(quest, state)
	return step and {step} or {}
end

function SmartQuestService:_resolveTarget(step)
	if step.TargetTag then
		for _, instance in ipairs(CollectionService:GetTagged(step.TargetTag)) do
			if instance:IsDescendantOf(game) then return instance end
		end
	end
	if step.TargetName then
		local found = workspace:FindFirstChild(step.TargetName, true)
		if found then return found end
	end
	if step.Target then
		local found = workspace:FindFirstChild(step.Target, true)
		if found then return found end
	end
	return nil
end

function SmartQuestService:_markerPayload(quest, state)
	local markers = {}
	for _, step in ipairs(self:_activeSteps(quest, state)) do
		if step.Marker then
			local target = self:_resolveTarget(step)
			if target then
				table.insert(markers, {
					QuestId = quest.Id,
					StepId = step.Id,
					Text = step.MarkerText or step.Text,
					Target = target,
					ShowDistance = step.ShowDistance ~= false,
					HideWithin = step.HideWithin or 8,
				})
			end
		end
	end
	return markers
end

function SmartQuestService:_rewardPreview(quest)
	return RewardFormatter.Format(quest.Rewards)
end

function SmartQuestService:_clientQuestPayload(player: Player, questId: string)
	local quest = self:GetQuestDefinition(questId)
	local state = self:GetQuestState(player, questId)
	if not quest or not state then return nil end
	return {
		Quest = quest,
		State = state,
		Markers = self:_markerPayload(quest, state),
		RewardPreview = self:_rewardPreview(quest),
		TrackedQuestId = self:_getPlayerData(player).TrackedQuestId,
		ServerNow = now(),
	}
end

function SmartQuestService:_sendUpdate(player: Player, questId: string)
	local payload = self:_clientQuestPayload(player, questId)
	if payload then remoteEvent(SmartQuestShared.UpdateRemoteName):FireClient(player, payload) end
	self:_sendJournal(player)
end

function SmartQuestService:_sendJournal(player: Player)
	remoteEvent(SmartQuestShared.JournalRemoteName):FireClient(player, self:GetJournalSnapshot(player))
end

function SmartQuestService:_toast(player: Player, text: string, toastType: string?)
	remoteEvent(SmartQuestShared.ToastRemoteName):FireClient(player, {Text = text, Type = toastType or "Info"})
end

function SmartQuestService:_checkQuestList(player: Player, questIds, status: string)
	if type(questIds) ~= "table" then return true, nil end
	for _, questId in ipairs(questIds) do
		local state = self:GetQuestState(player, questId)
		if not state or state.Status ~= status then
			return false, `Requires {questId} to be {status}.`
		end
	end
	return true, nil
end

function SmartQuestService:_runCustomChecks(player: Player, checks, handlers, quest, step)
	if type(checks) ~= "table" then return true, nil end
	for checkName, value in pairs(checks) do
		local handler = handlers[checkName]
		if not handler then return false, `Missing SmartQuest handler: {checkName}` end
		local ok, reason = handler(player, value, quest, step)
		if not ok then return false, reason or `Check failed: {checkName}` end
	end
	return true, nil
end

function SmartQuestService:MeetsPrerequisites(player: Player, questId: string)
	local quest = self:GetQuestDefinition(questId)
	if not quest then return false, "Unknown quest." end
	local prereq = quest.Prerequisites
	if type(prereq) ~= "table" then return true, nil end
	local ok, reason = self:_checkQuestList(player, prereq.CompletedQuests, SmartQuestShared.Status.Completed)
	if not ok then return false, reason end
	ok, reason = self:_checkQuestList(player, prereq.ActiveQuests, SmartQuestShared.Status.Active)
	if not ok then return false, reason end
	if type(prereq.NotCompletedQuests) == "table" then
		for _, blockedId in ipairs(prereq.NotCompletedQuests) do
			if self:IsQuestCompleted(player, blockedId) then return false, `Quest {blockedId} must not be completed.` end
		end
	end
	return self:_runCustomChecks(player, prereq.Custom, self._prerequisiteHandlers, quest, nil)
end

function SmartQuestService:MeetsStepConditions(player: Player, questId: string, stepId: string)
	local quest = self:GetQuestDefinition(questId)
	if not quest then return false, "Unknown quest." end
	local step = self:_stepById(quest, stepId)
	if not step or type(step.Conditions) ~= "table" then return true, nil end
	local ok, reason = self:_checkQuestList(player, step.Conditions.CompletedQuests, SmartQuestShared.Status.Completed)
	if not ok then return false, reason end
	return self:_runCustomChecks(player, step.Conditions.Custom, self._conditionHandlers, quest, step)
end

function SmartQuestService:IsQuestCompleted(player: Player, questId: string): boolean
	local state = self:GetQuestState(player, questId)
	return state and state.Status == SmartQuestShared.Status.Completed or false
end

function SmartQuestService:IsQuestActive(player: Player, questId: string): boolean
	local state = self:GetQuestState(player, questId)
	return state and state.Status == SmartQuestShared.Status.Active or false
end

function SmartQuestService:CanStartQuest(player: Player, questId: string)
	local quest = self:GetQuestDefinition(questId)
	if not quest then return false, "Unknown quest." end
	local state = self:GetQuestState(player, questId)
	if state then
		if state.Status == SmartQuestShared.Status.Active or state.Status == SmartQuestShared.Status.ReadyToTurnIn then return false, "Quest already active." end
		if state.Status == SmartQuestShared.Status.Completed and not quest.Repeatable then return false, "Quest already completed." end
		if quest.Repeatable and state.RepeatAvailableAt and now() < state.RepeatAvailableAt then
			return false, `Quest is on cooldown for {math.ceil(state.RepeatAvailableAt - now())} seconds.`
		end
	end
	return self:MeetsPrerequisites(player, questId)
end

function SmartQuestService:_timerKey(player: Player, questId: string, stepId: string): string
	return tostring(player.UserId) .. ":" .. questId .. ":" .. stepId
end

function SmartQuestService:_newTimerToken(player: Player, questId: string, stepId: string): number
	local key = self:_timerKey(player, questId, stepId)
	local token = (self._timerTokens[key] or 0) + 1
	self._timerTokens[key] = token
	return token
end

function SmartQuestService:_tokenValid(player: Player, questId: string, stepId: string, token: number): boolean
	return self._timerTokens[self:_timerKey(player, questId, stepId)] == token
end

function SmartQuestService:_activateStep(player: Player, questId: string, step)
	local quest = self:GetQuestDefinition(questId)
	local state = self:GetQuestState(player, questId)
	if not quest or not state or not step then return end
	local stepState = state.Steps[step.Id]
	if not stepState or stepState.Completed then return end
	if stepState.StartedAt then return end
	stepState.StartedAt = now()
	stepState.ExpiresAt = step.TimeLimit and (now() + step.TimeLimit) or nil
	self.StepStarted:Fire(player, questId, step.Id, quest, step)
	local token = self:_newTimerToken(player, questId, step.Id)
	if step.Type == SmartQuestShared.StepType.Timer and step.Duration then
		task.delay(step.Duration, function()
			if self:_tokenValid(player, questId, step.Id, token) then self:Progress(player, questId, step.Id, step.Required or 1) end
		end)
	end
	if step.TimeLimit then
		task.delay(step.TimeLimit, function()
			if not self:_tokenValid(player, questId, step.Id, token) then return end
			local latest = self:GetQuestState(player, questId)
			if latest and latest.Status == SmartQuestShared.Status.Active and not latest.Steps[step.Id].Completed then
				if step.FailQuestOnTimeout then self:FailQuest(player, questId, "Time limit expired.") else self:_toast(player, "Objective time limit expired", "Warning") end
			end
		end)
	end
end

function SmartQuestService:_activateSteps(player: Player, questId: string)
	local quest = self:GetQuestDefinition(questId)
	local state = self:GetQuestState(player, questId)
	if not quest or not state then return end
	for _, step in ipairs(self:_activeSteps(quest, state)) do self:_activateStep(player, questId, step) end
	self:_sendUpdate(player, questId)
end

function SmartQuestService:StartQuest(player: Player, questId: string): boolean
	local quest = self:GetQuestDefinition(questId)
	if not quest then return false end
	local canStart, reason = self:CanStartQuest(player, questId)
	if not canStart then self:_toast(player, reason or "Cannot start quest.", "Error") return false end
	local data = self:_getPlayerData(player)
	data.Quests[questId] = self:_buildInitialState(quest)
	if not data.TrackedQuestId then data.TrackedQuestId = questId end
	self.QuestStarted:Fire(player, questId, quest)
	self:_toast(player, `Quest started: {quest.Title}`, "QuestStarted")
	self:_activateSteps(player, questId)
	self:_save(player)
	return true
end

function SmartQuestService:_advanceSequential(player: Player, quest, state)
	state.CurrentStepIndex += 1
	self:_activateSteps(player, quest.Id)
end

function SmartQuestService:_finishObjectives(player: Player, quest, state)
	local mode = quest.Completion and quest.Completion.Mode or SmartQuestShared.CompletionMode.Auto
	if mode == SmartQuestShared.CompletionMode.ReturnToGiver then
		state.Status = SmartQuestShared.Status.ReadyToTurnIn
		self.QuestReadyToTurnIn:Fire(player, quest.Id, quest)
		self:_toast(player, `Return to turn in: {quest.Title}`, "ReadyToTurnIn")
		self:_sendUpdate(player, quest.Id)
		self:_save(player)
	elseif mode == SmartQuestShared.CompletionMode.Manual then
		state.Status = SmartQuestShared.Status.ReadyToTurnIn
		self.QuestReadyToTurnIn:Fire(player, quest.Id, quest)
		self:_sendUpdate(player, quest.Id)
		self:_save(player)
	else
		self:CompleteQuest(player, quest.Id)
	end
end

function SmartQuestService:Progress(player: Player, questId: string, stepId: string, amount: number?, progressKey: string?): boolean
	local quest = self:GetQuestDefinition(questId)
	if not quest then return false end
	local state = self:GetQuestState(player, questId)
	if not state then if not self:StartQuest(player, questId) then return false end state = self:GetQuestState(player, questId) end
	if not state or state.Status ~= SmartQuestShared.Status.Active then return false end
	local step = self:_stepById(quest, stepId)
	if not step then return false end
	if quest.ProgressionMode ~= SmartQuestShared.ProgressionMode.Parallel then
		local current = self:_currentStep(quest, state)
		if not current or current.Id ~= stepId then return false end
	end
	local ok, reason = self:MeetsStepConditions(player, questId, stepId)
	if not ok then self:_toast(player, reason or "Objective conditions not met.", "Error") return false end
	local stepState = state.Steps[stepId]
	if not stepState or stepState.Completed then return false end
	if step.Type == SmartQuestShared.StepType.Group and progressKey then
		if stepState.GroupCompleted[progressKey] then return false end
		stepState.GroupCompleted[progressKey] = true
	end
	local delta = amount or 1
	stepState.Progress = SmartQuestShared.ClampProgress(stepState.Progress + delta, stepState.Required)
	self.StepProgressed:Fire(player, questId, stepId, stepState.Progress, stepState.Required)
	if stepState.Progress >= stepState.Required then
		stepState.Completed = true
		stepState.CompletedAt = now()
		self.StepCompleted:Fire(player, questId, stepId, quest, step)
		self:_toast(player, step.Text, "StepCompleted")
		if self:_allStepsCompleted(quest, state) then
			self:_finishObjectives(player, quest, state)
		elseif quest.ProgressionMode ~= SmartQuestShared.ProgressionMode.Parallel then
			self:_advanceSequential(player, quest, state)
		end
	end
	self:_sendUpdate(player, questId)
	self:_save(player)
	return true
end

function SmartQuestService:CompleteQuest(player: Player, questId: string): boolean
	local quest = self:GetQuestDefinition(questId)
	local state = self:GetQuestState(player, questId)
	if not quest or not state then return false end
	if state.Status ~= SmartQuestShared.Status.Active and state.Status ~= SmartQuestShared.Status.ReadyToTurnIn then return false end
	state.Status = SmartQuestShared.Status.Completed
	state.CompletedAt = now()
	if quest.Repeatable then state.RepeatAvailableAt = now() + (quest.RepeatCooldown or 0) end
	if self._rewardHandler and quest.Rewards then
		local success, err = pcall(function() self._rewardHandler(player, quest.Rewards, quest, state) end)
		if success then self.RewardGranted:Fire(player, questId, quest.Rewards) else warn(`[SmartQuestService] Reward handler error: {err}`) end
	end
	self.QuestCompleted:Fire(player, questId, quest, quest.Rewards)
	self:_toast(player, `Quest completed: {quest.Title}`, "QuestCompleted")
	self:_advanceArcIfNeeded(player, questId)
	self:_sendUpdate(player, questId)
	self:_save(player)
	return true
end

function SmartQuestService:TurnInQuest(player: Player, questId: string): boolean
	local state = self:GetQuestState(player, questId)
	if not state or state.Status ~= SmartQuestShared.Status.ReadyToTurnIn then return false end
	return self:CompleteQuest(player, questId)
end

function SmartQuestService:FailQuest(player: Player, questId: string, reason: string?): boolean
	local state = self:GetQuestState(player, questId)
	if not state or state.Status ~= SmartQuestShared.Status.Active then return false end
	state.Status = SmartQuestShared.Status.Failed
	state.FailedAt = now()
	state.FailReason = reason
	self.QuestFailed:Fire(player, questId, reason)
	self:_toast(player, reason or "Quest failed", "QuestFailed")
	self:_sendUpdate(player, questId)
	self:_save(player)
	return true
end

function SmartQuestService:AbandonQuest(player: Player, questId: string): boolean
	local state = self:GetQuestState(player, questId)
	if not state or state.Status ~= SmartQuestShared.Status.Active then return false end
	state.Status = SmartQuestShared.Status.Abandoned
	state.FailReason = "Abandoned"
	self.QuestAbandoned:Fire(player, questId)
	self:_toast(player, "Quest abandoned", "Warning")
	self:_sendUpdate(player, questId)
	self:_save(player)
	return true
end

function SmartQuestService:SetTrackedQuest(player: Player, questId: string?)
	local data = self:_getPlayerData(player)
	if questId and not self:GetQuestState(player, questId) then return false end
	data.TrackedQuestId = questId
	self.TrackedQuestChanged:Fire(player, questId)
	if questId then self:_sendUpdate(player, questId) else self:_sendJournal(player) end
	self:_save(player)
	return true
end

function SmartQuestService:StartQuestArc(player: Player, arcId: string): boolean
	local arc = self._arcs[arcId]
	if not arc or type(arc.Quests) ~= "table" or #arc.Quests == 0 then return false end
	local data = self:_getPlayerData(player)
	data.ActiveArcId = arcId
	data.ArcIndex = 1
	local started = self:StartQuest(player, arc.Quests[1])
	self:_save(player)
	return started
end

function SmartQuestService:_advanceArcIfNeeded(player: Player, completedQuestId: string)
	local data = self:_getPlayerData(player)
	local arcId = data.ActiveArcId
	if not arcId then return end
	local arc = self._arcs[arcId]
	if not arc then return end
	if arc.Quests[data.ArcIndex] ~= completedQuestId then return end
	data.ArcIndex += 1
	local nextQuestId = arc.Quests[data.ArcIndex]
	if nextQuestId then self:StartQuest(player, nextQuestId) else data.ActiveArcId = nil data.ArcIndex = 0 end
end

function SmartQuestService:ResetQuest(player: Player, questId: string): boolean
	local data = self:_getPlayerData(player)
	if not data.Quests[questId] then return false end
	data.Quests[questId] = nil
	if data.TrackedQuestId == questId then data.TrackedQuestId = nil end
	self:_sendJournal(player)
	self:_save(player)
	return true
end

function SmartQuestService:ResetPlayer(player: Player)
	self._playerData[player] = nil
	self:_getPlayerData(player)
	self:_sendJournal(player)
	self:_save(player)
end

function SmartQuestService:DebugStart(player: Player, questId: string) return self:StartQuest(player, questId) end
function SmartQuestService:DebugCompleteQuest(player: Player, questId: string) return self:CompleteQuest(player, questId) end
function SmartQuestService:DebugReset(player: Player) self:ResetPlayer(player) end
function SmartQuestService:DebugPrintState(player: Player) print(self:_getPlayerData(player)) end
function SmartQuestService:DebugCompleteCurrentStep(player: Player, questId: string)
	local quest = self:GetQuestDefinition(questId)
	local state = self:GetQuestState(player, questId)
	if not quest or not state then return false end
	local step = self:_currentStep(quest, state)
	if not step then return false end
	return self:Progress(player, questId, step.Id, step.Required or 1)
end

function SmartQuestService:GetJournalSnapshot(player: Player)
	local data = self:_getPlayerData(player)
	local entries = {}
	for questId, quest in pairs(self._quests) do
		local state = data.Quests[questId]
		local canStart, reason = self:CanStartQuest(player, questId)
		table.insert(entries, {
			Quest = quest,
			State = state,
			CanStart = canStart,
			UnavailableReason = reason,
			RewardPreview = self:_rewardPreview(quest),
			Tracked = data.TrackedQuestId == questId,
		})
	end
	table.sort(entries, function(a, b) return a.Quest.Title < b.Quest.Title end)
	return {Version = SmartQuestShared.Version, Quests = entries, TrackedQuestId = data.TrackedQuestId, ActiveArcId = data.ActiveArcId, ServerNow = now()}
end

function SmartQuestService:_handleAction(player: Player, action, questId)
	if action == "Start" then return self:StartQuest(player, questId) end
	if action == "Track" then return self:SetTrackedQuest(player, questId) end
	if action == "Untrack" then return self:SetTrackedQuest(player, nil) end
	if action == "Abandon" then return self:AbandonQuest(player, questId) end
	if action == "TurnIn" then return self:TurnInQuest(player, questId) end
	return false
end

function SmartQuestService:_findPromptParent(instance: Instance): Instance?
	if instance:IsA("BasePart") then return instance end
	if instance:IsA("Model") then return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end

function SmartQuestService:_setupQuestGiver(instance: Instance)
	if self._connections[instance] then return end
	local questId = instance:GetAttribute("QuestId")
	if type(questId) ~= "string" then return end
	local part = self:_findPromptParent(instance)
	if not part then return end
	local prompt = part:FindFirstChild("SmartQuestGiverPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then prompt = Instance.new("ProximityPrompt") prompt.Name = "SmartQuestGiverPrompt" prompt.Parent = part end
	prompt.ActionText = tostring(instance:GetAttribute("PromptText") or "Quest")
	prompt.ObjectText = tostring(instance:GetAttribute("ObjectText") or "Quest")
	prompt.HoldDuration = tonumber(instance:GetAttribute("HoldDuration")) or self._settings.DefaultPromptHoldDuration or 0
	prompt.MaxActivationDistance = tonumber(instance:GetAttribute("MaxActivationDistance")) or self._settings.DefaultPromptDistance or 10
	prompt.RequiresLineOfSight = false
	self._connections[instance] = prompt.Triggered:Connect(function(player)
		local state = self:GetQuestState(player, questId)
		if state and state.Status == SmartQuestShared.Status.ReadyToTurnIn then self:TurnInQuest(player, questId) else self:StartQuest(player, questId) end
	end)
end

function SmartQuestService:_setupInteract(instance: Instance)
	if self._connections[instance] then return end
	local questId = instance:GetAttribute("QuestId")
	local stepId = instance:GetAttribute("StepId")
	if type(questId) ~= "string" or type(stepId) ~= "string" then return end
	local part = self:_findPromptParent(instance)
	if not part then return end
	local prompt = part:FindFirstChild("SmartQuestPrompt")
	if not prompt or not prompt:IsA("ProximityPrompt") then prompt = Instance.new("ProximityPrompt") prompt.Name = "SmartQuestPrompt" prompt.Parent = part end
	prompt.ActionText = tostring(instance:GetAttribute("PromptText") or "Interact")
	prompt.ObjectText = tostring(instance:GetAttribute("ObjectText") or "")
	prompt.HoldDuration = tonumber(instance:GetAttribute("HoldDuration")) or self._settings.DefaultPromptHoldDuration or 0
	prompt.MaxActivationDistance = tonumber(instance:GetAttribute("MaxActivationDistance")) or self._settings.DefaultPromptDistance or 10
	prompt.RequiresLineOfSight = false
	self._connections[instance] = prompt.Triggered:Connect(function(player)
		local key = instance:GetAttribute("ProgressKey") or instance.Name
		self:Progress(player, questId, stepId, tonumber(instance:GetAttribute("Amount")) or 1, tostring(key))
	end)
end

function SmartQuestService:_setupZone(instance: Instance)
	if self._connections[instance] or not instance:IsA("BasePart") then return end
	local questId = instance:GetAttribute("QuestId")
	local stepId = instance:GetAttribute("StepId")
	if type(questId) ~= "string" or type(stepId) ~= "string" then return end
	self._zoneDebounce[instance] = {}
	self._connections[instance] = instance.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then return end
		local last = self._zoneDebounce[instance][player]
		if last and os.clock() - last < 1 then return end
		self._zoneDebounce[instance][player] = os.clock()
		self:Progress(player, questId, stepId, tonumber(instance:GetAttribute("Amount")) or 1, instance.Name)
	end)
end

function SmartQuestService:SetupTaggedObjects()
	for _, instance in ipairs(CollectionService:GetTagged("SmartQuestGiver")) do self:_setupQuestGiver(instance) end
	for _, instance in ipairs(CollectionService:GetTagged("SmartQuestInteract")) do self:_setupInteract(instance) end
	for _, instance in ipairs(CollectionService:GetTagged("SmartQuestZone")) do self:_setupZone(instance) end
	CollectionService:GetInstanceAddedSignal("SmartQuestGiver"):Connect(function(instance) self:_setupQuestGiver(instance) end)
	CollectionService:GetInstanceAddedSignal("SmartQuestInteract"):Connect(function(instance) self:_setupInteract(instance) end)
	CollectionService:GetInstanceAddedSignal("SmartQuestZone"):Connect(function(instance) self:_setupZone(instance) end)
end

function SmartQuestService:ValidateSetup()
	local messages = SmartQuestValidator.Validate(self._quests, self._arcs, self._settings)
	SmartQuestValidator.Print(messages)
	return messages
end

function SmartQuestService:Init()
	if self._initialized then return end
	self._initialized = true
	remoteEvent(SmartQuestShared.UpdateRemoteName)
	remoteEvent(SmartQuestShared.ToastRemoteName)
	remoteEvent(SmartQuestShared.JournalRemoteName)
	remoteFunction(SmartQuestShared.RequestJournalRemoteName).OnServerInvoke = function(player) return self:GetJournalSnapshot(player) end
	remoteFunction(SmartQuestShared.ActionRemoteName).OnServerInvoke = function(player, action, questId) return self:_handleAction(player, action, questId) end
	self:RegisterQuests(SmartQuestConfig.Quests)
	if self._settings.EnableStartupValidation ~= false then self:ValidateSetup() end
	self:SetupTaggedObjects()
	Players.PlayerAdded:Connect(function(player)
		self:_load(player)
		for _, quest in pairs(self._quests) do if quest.AutoStart then self:StartQuest(player, quest.Id) end end
		task.defer(function() self:_sendJournal(player) end)
	end)
	Players.PlayerRemoving:Connect(function(player) self:_save(player) self._playerData[player] = nil end)
end

return SmartQuestService
