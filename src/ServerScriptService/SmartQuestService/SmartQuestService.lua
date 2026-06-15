--!strict
-- SmartQuestService
-- Server-authoritative quest/objective runtime.
-- Put under ServerScriptService/SmartQuestService/SmartQuestService.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local SharedFolder = ReplicatedStorage:WaitForChild("SmartQuestService")
local SmartQuestShared = require(SharedFolder:WaitForChild("SmartQuestShared"))
local SmartQuestConfig = require(SharedFolder:WaitForChild("SmartQuestConfig"))

type QuestDefinition = SmartQuestShared.QuestDefinition
type QuestState = SmartQuestShared.QuestState

local SmartQuestService = {}

SmartQuestService._quests = {} :: {[string]: QuestDefinition}
SmartQuestService._playerStates = {} :: {[Player]: {[string]: QuestState}}
SmartQuestService._connections = {} :: {[Instance]: RBXScriptConnection}
SmartQuestService._zoneDebounce = {} :: {[Instance]: {[Player]: number}}

local REMOTE_FOLDER_NAME = "SmartQuestRemotes"
local UPDATE_REMOTE_NAME = "SmartQuestUpdate"
local TOAST_REMOTE_NAME = "SmartQuestToast"

local function getOrCreateRemoteFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		return folder
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = REMOTE_FOLDER_NAME
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

function SmartQuestService:_getUpdateRemote(): RemoteEvent
	local folder = getOrCreateRemoteFolder()
	return getOrCreateRemoteEvent(folder, UPDATE_REMOTE_NAME)
end

function SmartQuestService:_getToastRemote(): RemoteEvent
	local folder = getOrCreateRemoteFolder()
	return getOrCreateRemoteEvent(folder, TOAST_REMOTE_NAME)
end

function SmartQuestService:RegisterQuest(quest: QuestDefinition)
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
		step.Required = math.max(1, step.Required or 1)
	end

	self._quests[quest.Id] = SmartQuestShared.DeepCopy(quest)
end

function SmartQuestService:RegisterQuests(quests: {[string]: QuestDefinition})
	for _, quest in pairs(quests) do
		self:RegisterQuest(quest)
	end
end

function SmartQuestService:GetQuestDefinition(questId: string): QuestDefinition?
	return self._quests[questId]
end

function SmartQuestService:_getPlayerQuestTable(player: Player): {[string]: QuestState}
	local states = self._playerStates[player]
	if not states then
		states = {}
		self._playerStates[player] = states
	end
	return states
end

function SmartQuestService:GetQuestState(player: Player, questId: string): QuestState?
	local playerStates = self:_getPlayerQuestTable(player)
	return playerStates[questId]
end

function SmartQuestService:_buildInitialState(quest: QuestDefinition): QuestState
	local stepStates = {}

	for _, step in ipairs(quest.Steps) do
		stepStates[step.Id] = {
			Id = step.Id,
			Progress = 0,
			Required = step.Required or 1,
			Completed = false,
		}
	end

	return {
		Id = quest.Id,
		Status = SmartQuestShared.Status.Active,
		CurrentStepIndex = 1,
		Steps = stepStates,
	}
end

function SmartQuestService:_getCurrentStep(quest: QuestDefinition, state: QuestState)
	return quest.Steps[state.CurrentStepIndex]
end

function SmartQuestService:_sendUpdate(player: Player, questId: string)
	local quest = self:GetQuestDefinition(questId)
	local state = self:GetQuestState(player, questId)
	if not quest or not state then
		return
	end

	self:_getUpdateRemote():FireClient(player, {
		Quest = quest,
		State = state,
	})
end

function SmartQuestService:_toast(player: Player, text: string, toastType: string?)
	self:_getToastRemote():FireClient(player, {
		Text = text,
		Type = toastType or "Info",
	})
end

function SmartQuestService:StartQuest(player: Player, questId: string): boolean
	local quest = self:GetQuestDefinition(questId)
	if not quest then
		warn(`[SmartQuestService] Cannot start unknown quest: {questId}`)
		return false
	end

	local playerStates = self:_getPlayerQuestTable(player)
	local existing = playerStates[questId]

	if existing and existing.Status == SmartQuestShared.Status.Active then
		self:_sendUpdate(player, questId)
		return true
	end

	if existing and existing.Status == SmartQuestShared.Status.Completed then
		return false
	end

	playerStates[questId] = self:_buildInitialState(quest)
	self:_toast(player, `Quest started: {quest.Title}`, "QuestStarted")
	self:_sendUpdate(player, questId)
	return true
end

function SmartQuestService:FailQuest(player: Player, questId: string): boolean
	local state = self:GetQuestState(player, questId)
	if not state or state.Status ~= SmartQuestShared.Status.Active then
		return false
	end

	state.Status = SmartQuestShared.Status.Failed
	self:_sendUpdate(player, questId)
	self:_toast(player, "Quest failed", "QuestFailed")
	return true
end

function SmartQuestService:CompleteQuest(player: Player, questId: string): boolean
	local quest = self:GetQuestDefinition(questId)
	local state = self:GetQuestState(player, questId)

	if not quest or not state or state.Status ~= SmartQuestShared.Status.Active then
		return false
	end

	state.Status = SmartQuestShared.Status.Completed
	self:_sendUpdate(player, questId)
	self:_toast(player, `Quest completed: {quest.Title}`, "QuestCompleted")

	-- Reward hook:
	-- Keep this generic. In a real project, connect this to CurrencyService, InventoryService, XPService, etc.
	-- Example:
	-- RewardService:Give(player, quest.Rewards)

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
		-- Convenience: interacting with a quest object starts the quest.
		self:StartQuest(player, questId)
		state = self:GetQuestState(player, questId)
	end

	if not state or state.Status ~= SmartQuestShared.Status.Active then
		return false
	end

	local currentStep = self:_getCurrentStep(quest, state)
	if not currentStep then
		return false
	end

	if currentStep.Id ~= stepId then
		-- Only the active step can progress in v1.
		return false
	end

	local stepState = state.Steps[stepId]
	if not stepState or stepState.Completed then
		return false
	end

	local delta = amount or 1
	stepState.Progress = SmartQuestShared.ClampProgress(stepState.Progress + delta, stepState.Required)

	if stepState.Progress >= stepState.Required then
		stepState.Completed = true
		self:_toast(player, currentStep.Text, "StepCompleted")

		if state.CurrentStepIndex >= #quest.Steps then
			self:CompleteQuest(player, questId)
			return true
		else
			state.CurrentStepIndex += 1
		end
	end

	self:_sendUpdate(player, questId)
	return true
end

function SmartQuestService:ResetPlayer(player: Player)
	self._playerStates[player] = {}
end

function SmartQuestService:GetAllStates(player: Player): {[string]: QuestState}
	return self:_getPlayerQuestTable(player)
end

function SmartQuestService:_findPromptParent(instance: Instance): Instance?
	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		local primary = instance.PrimaryPart
		if primary then
			return primary
		end

		local part = instance:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part
		end
	end

	return nil
end

function SmartQuestService:_setupSmartQuestInteract(instance: Instance)
	if self._connections[instance] then
		return
	end

	local promptParent = self:_findPromptParent(instance)
	if not promptParent then
		warn(`[SmartQuestService] SmartQuestInteract has no valid BasePart parent: {instance:GetFullName()}`)
		return
	end

	local questId = instance:GetAttribute("QuestId")
	local stepId = instance:GetAttribute("StepId")
	if type(questId) ~= "string" or type(stepId) ~= "string" then
		warn(`[SmartQuestService] SmartQuestInteract missing QuestId or StepId: {instance:GetFullName()}`)
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
	prompt.HoldDuration = tonumber(instance:GetAttribute("HoldDuration")) or 0
	prompt.MaxActivationDistance = tonumber(instance:GetAttribute("MaxActivationDistance")) or 10
	prompt.RequiresLineOfSight = false

	self._connections[instance] = prompt.Triggered:Connect(function(player: Player)
		local amount = tonumber(instance:GetAttribute("Amount")) or 1
		self:Progress(player, questId, stepId, amount)
	end)
end

function SmartQuestService:_setupSmartQuestZone(instance: Instance)
	if not instance:IsA("BasePart") then
		warn(`[SmartQuestService] SmartQuestZone must be a BasePart: {instance:GetFullName()}`)
		return
	end

	if self._connections[instance] then
		return
	end

	local questId = instance:GetAttribute("QuestId")
	local stepId = instance:GetAttribute("StepId")
	if type(questId) ~= "string" or type(stepId) ~= "string" then
		warn(`[SmartQuestService] SmartQuestZone missing QuestId or StepId: {instance:GetFullName()}`)
		return
	end

	self._zoneDebounce[instance] = {}

	self._connections[instance] = instance.Touched:Connect(function(hit: BasePart)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local now = os.clock()
		local playerDebounce = self._zoneDebounce[instance]
		if playerDebounce[player] and now - playerDebounce[player] < 1 then
			return
		end
		playerDebounce[player] = now

		local amount = tonumber(instance:GetAttribute("Amount")) or 1
		self:Progress(player, questId, stepId, amount)
	end)
end

function SmartQuestService:SetupTaggedObjects()
	for _, instance in ipairs(CollectionService:GetTagged("SmartQuestInteract")) do
		self:_setupSmartQuestInteract(instance)
	end

	for _, instance in ipairs(CollectionService:GetTagged("SmartQuestZone")) do
		self:_setupSmartQuestZone(instance)
	end

	CollectionService:GetInstanceAddedSignal("SmartQuestInteract"):Connect(function(instance)
		self:_setupSmartQuestInteract(instance)
	end)

	CollectionService:GetInstanceAddedSignal("SmartQuestZone"):Connect(function(instance)
		self:_setupSmartQuestZone(instance)
	end)
end

function SmartQuestService:Init()
	self:_getUpdateRemote()
	self:_getToastRemote()
	self:RegisterQuests(SmartQuestConfig.Quests)
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
	end)
end

return SmartQuestService
