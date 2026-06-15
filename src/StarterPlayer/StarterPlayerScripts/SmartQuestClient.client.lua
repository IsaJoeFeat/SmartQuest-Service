--!strict
-- SmartQuestClient v3
-- Tracker, toast messages, objective markers, and interactive quest journal.
-- Server remains authoritative.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local sharedFolder = ReplicatedStorage:WaitForChild("SmartQuestService")
local SmartQuestShared = require(sharedFolder:WaitForChild("SmartQuestShared"))
local SmartQuestConfig = require(sharedFolder:WaitForChild("SmartQuestConfig"))
local settings = SmartQuestConfig.Settings or {}

local remoteFolder = ReplicatedStorage:WaitForChild(SmartQuestShared.RemoteFolderName)
local smartQuestUpdate = remoteFolder:WaitForChild(SmartQuestShared.UpdateRemoteName) :: RemoteEvent
local smartQuestToast = remoteFolder:WaitForChild(SmartQuestShared.ToastRemoteName) :: RemoteEvent
local smartQuestJournal = remoteFolder:WaitForChild(SmartQuestShared.JournalRemoteName) :: RemoteEvent
local requestJournal = remoteFolder:WaitForChild(SmartQuestShared.RequestJournalRemoteName) :: RemoteFunction
local smartQuestAction = remoteFolder:WaitForChild(SmartQuestShared.ActionRemoteName) :: RemoteFunction

local gui = Instance.new("ScreenGui")
gui.Name = "SmartQuestGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local tracker = Instance.new("Frame")
tracker.Name = "Tracker"
tracker.AnchorPoint = Vector2.new(1, 0)
tracker.Position = UDim2.fromScale(0.985, 0.14)
tracker.Size = UDim2.fromOffset(380, 140)
tracker.BackgroundTransparency = 0.18
tracker.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
tracker.BorderSizePixel = 0
tracker.Visible = false
tracker.Parent = gui

local trackerCorner = Instance.new("UICorner")
trackerCorner.CornerRadius = UDim.new(0, 10)
trackerCorner.Parent = tracker

local trackerPadding = Instance.new("UIPadding")
trackerPadding.PaddingTop = UDim.new(0, 12)
trackerPadding.PaddingBottom = UDim.new(0, 12)
trackerPadding.PaddingLeft = UDim.new(0, 14)
trackerPadding.PaddingRight = UDim.new(0, 14)
trackerPadding.Parent = tracker

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 24)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Quest"
title.Parent = tracker

local stepText = Instance.new("TextLabel")
stepText.BackgroundTransparency = 1
stepText.Position = UDim2.fromOffset(0, 34)
stepText.Size = UDim2.new(1, 0, 0, 48)
stepText.Font = Enum.Font.Gotham
stepText.TextSize = 15
stepText.TextWrapped = true
stepText.TextXAlignment = Enum.TextXAlignment.Left
stepText.TextYAlignment = Enum.TextYAlignment.Top
stepText.TextColor3 = Color3.fromRGB(230, 230, 230)
stepText.Text = ""
stepText.Parent = tracker

local progress = Instance.new("TextLabel")
progress.BackgroundTransparency = 1
progress.Position = UDim2.fromOffset(0, 86)
progress.Size = UDim2.new(1, 0, 0, 22)
progress.Font = Enum.Font.GothamMedium
progress.TextSize = 14
progress.TextXAlignment = Enum.TextXAlignment.Left
progress.TextColor3 = Color3.fromRGB(190, 190, 190)
progress.Text = ""
progress.Parent = tracker

local timerText = Instance.new("TextLabel")
timerText.BackgroundTransparency = 1
timerText.Position = UDim2.fromOffset(0, 110)
timerText.Size = UDim2.new(1, 0, 0, 18)
timerText.Font = Enum.Font.GothamBold
timerText.TextSize = 13
timerText.TextXAlignment = Enum.TextXAlignment.Left
timerText.TextColor3 = Color3.fromRGB(255, 210, 160)
timerText.Text = ""
timerText.Parent = tracker

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.08)
toast.Size = UDim2.fromOffset(460, 44)
toast.BackgroundTransparency = 1
toast.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
toast.BorderSizePixel = 0
toast.Font = Enum.Font.GothamBold
toast.TextSize = 17
toast.TextColor3 = Color3.fromRGB(255, 255, 255)
toast.Text = ""
toast.Visible = false
toast.Parent = gui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toast

local journal = Instance.new("Frame")
journal.Name = "Journal"
journal.AnchorPoint = Vector2.new(0.5, 0.5)
journal.Position = UDim2.fromScale(0.5, 0.5)
journal.Size = UDim2.fromOffset(700, 500)
journal.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
journal.BackgroundTransparency = 0.08
journal.BorderSizePixel = 0
journal.Visible = false
journal.Parent = gui

local journalCorner = Instance.new("UICorner")
journalCorner.CornerRadius = UDim.new(0, 12)
journalCorner.Parent = journal

local journalPadding = Instance.new("UIPadding")
journalPadding.PaddingTop = UDim.new(0, 16)
journalPadding.PaddingBottom = UDim.new(0, 16)
journalPadding.PaddingLeft = UDim.new(0, 18)
journalPadding.PaddingRight = UDim.new(0, 18)
journalPadding.Parent = journal

local journalTitle = Instance.new("TextLabel")
journalTitle.BackgroundTransparency = 1
journalTitle.Size = UDim2.new(1, -40, 0, 28)
journalTitle.Font = Enum.Font.GothamBold
journalTitle.TextSize = 22
journalTitle.TextXAlignment = Enum.TextXAlignment.Left
journalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
journalTitle.Text = "Quest Journal"
journalTitle.Parent = journal

local closeJournal = Instance.new("TextButton")
closeJournal.AnchorPoint = Vector2.new(1, 0)
closeJournal.Position = UDim2.new(1, 0, 0, 0)
closeJournal.Size = UDim2.fromOffset(32, 28)
closeJournal.BackgroundTransparency = 1
closeJournal.Font = Enum.Font.GothamBold
closeJournal.TextSize = 22
closeJournal.TextColor3 = Color3.fromRGB(220, 220, 220)
closeJournal.Text = "×"
closeJournal.Parent = journal

local questList = Instance.new("ScrollingFrame")
questList.Position = UDim2.fromOffset(0, 42)
questList.Size = UDim2.new(1, 0, 1, -42)
questList.BackgroundTransparency = 1
questList.BorderSizePixel = 0
questList.ScrollBarThickness = 6
questList.CanvasSize = UDim2.fromOffset(0, 0)
questList.Parent = journal

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = questList

local currentPayload = nil
local markerGuis = {}
local activeToastTween: Tween? = nil

local function invokeAction(action, questId)
	local ok, result = pcall(function()
		return smartQuestAction:InvokeServer(action, questId)
	end)
	return ok and result
end

local function getCurrentStep(quest, state)
	if not quest or not state then return nil end
	return quest.Steps[state.CurrentStepIndex]
end

local function getActiveStepSummary(quest, state): string
	if not quest or not state then return "" end
	if state.Status == "ReadyToTurnIn" then return "Ready to turn in." end
	if state.Status ~= "Active" then return state.Status end
	if quest.ProgressionMode == "Parallel" then
		local lines = {}
		for _, step in ipairs(quest.Steps) do
			local stepState = state.Steps[step.Id]
			if stepState and not stepState.Completed then
				table.insert(lines, step.Required > 1 and `{step.Text} ({stepState.Progress}/{stepState.Required})` or step.Text)
			end
		end
		return table.concat(lines, "\n")
	end
	local step = getCurrentStep(quest, state)
	if not step then return "" end
	local stepState = state.Steps[step.Id]
	if stepState and stepState.Required > 1 then return `{step.Text} ({stepState.Progress}/{stepState.Required})` end
	return step.Text
end

local function getAdornee(instance: Instance?): BasePart?
	if not instance then return nil end
	if instance:IsA("BasePart") then return instance end
	if instance:IsA("Model") then return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end

local function clearMarkers()
	for _, marker in pairs(markerGuis) do marker:Destroy() end
	markerGuis = {}
end

local function setMarkers(markers)
	clearMarkers()
	if type(markers) ~= "table" then return end
	for _, marker in ipairs(markers) do
		local adornee = getAdornee(marker.Target)
		if adornee then
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "SmartQuestMarker"
			billboard.Adornee = adornee
			billboard.AlwaysOnTop = true
			billboard.Size = UDim2.fromOffset(210, 54)
			billboard.StudsOffset = Vector3.new(0, 4, 0)
			billboard.Parent = gui

			local label = Instance.new("TextLabel")
			label.Name = "Label"
			label.BackgroundTransparency = 0.18
			label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			label.BorderSizePixel = 0
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GothamBold
			label.TextSize = 14
			label.TextColor3 = Color3.fromRGB(255, 240, 180)
			label.TextStrokeTransparency = 0.45
			label.Text = marker.Text or "Objective"
			label.Parent = billboard

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = label

			table.insert(markerGuis, billboard)
		end
	end
end

local function updateTracker(payload)
	currentPayload = payload
	local quest = payload.Quest
	local state = payload.State
	if not quest or not state or payload.TrackedQuestId ~= quest.Id then
		if payload.TrackedQuestId and quest and payload.TrackedQuestId ~= quest.Id then return end
	end
	if not quest or not state or (state.Status ~= "Active" and state.Status ~= "ReadyToTurnIn") then
		tracker.Visible = false
		clearMarkers()
		return
	end
	title.Text = quest.Title
	stepText.Text = getActiveStepSummary(quest, state)
	progress.Text = state.Status == "ReadyToTurnIn" and "Return to the quest giver" or `Status: {state.Status}`
	tracker.Visible = true
	setMarkers(payload.Markers)
end

local function updateTimerText()
	if not currentPayload then timerText.Text = "" return end
	local quest = currentPayload.Quest
	local state = currentPayload.State
	if not quest or not state or state.Status ~= "Active" then timerText.Text = "" return end
	local nearest = nil
	for _, step in ipairs(quest.Steps) do
		local stepState = state.Steps[step.Id]
		if stepState and not stepState.Completed and stepState.ExpiresAt then
			local remaining = stepState.ExpiresAt - workspace:GetServerTimeNow()
			if not nearest or remaining < nearest then nearest = remaining end
		end
	end
	timerText.Text = nearest and ("Time left: " .. SmartQuestShared.FormatClock(nearest)) or ""
end

local function showToast(payload)
	local text = payload.Text
	if type(text) ~= "string" or text == "" then return end
	if activeToastTween then activeToastTween:Cancel() end
	toast.Text = text
	toast.Visible = true
	toast.BackgroundTransparency = 0.2
	toast.TextTransparency = 0
	toast.Position = UDim2.fromScale(0.5, 0.08)
	TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.fromScale(0.5, 0.095)}):Play()
	task.delay(2.35, function()
		if not toast.Visible then return end
		activeToastTween = TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1, TextTransparency = 1})
		activeToastTween:Play()
		activeToastTween.Completed:Wait()
		toast.Visible = false
	end)
end

local function clearQuestCards()
	for _, child in ipairs(questList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
end

local function addButton(parent, text, positionX, action, questId)
	local button = Instance.new("TextButton")
	button.Position = UDim2.fromOffset(positionX, 84)
	button.Size = UDim2.fromOffset(92, 24)
	button.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	button.MouseButton1Click:Connect(function()
		invokeAction(action, questId)
	end)
end

local function makeQuestCard(entry, index)
	local quest = entry.Quest
	local state = entry.State
	local status = state and state.Status or (entry.CanStart and "Available" or "Locked")
	local card = Instance.new("Frame")
	card.Name = quest.Id
	card.LayoutOrder = index
	card.Size = UDim2.new(1, -8, 0, 122)
	card.BackgroundColor3 = entry.Tracked and Color3.fromRGB(38, 34, 22) or Color3.fromRGB(28, 28, 28)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = questList
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = card
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 22)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 17
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.Text = quest.Title .. "  [" .. status .. "]"
	name.Parent = card
	local desc = Instance.new("TextLabel")
	desc.BackgroundTransparency = 1
	desc.Position = UDim2.fromOffset(0, 26)
	desc.Size = UDim2.new(0.66, 0, 0, 50)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextWrapped = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextColor3 = Color3.fromRGB(205, 205, 205)
	desc.Text = state and getActiveStepSummary(quest, state) or (quest.Description or "")
	desc.Parent = card
	local reward = Instance.new("TextLabel")
	reward.BackgroundTransparency = 1
	reward.Position = UDim2.new(0.68, 0, 0, 26)
	reward.Size = UDim2.new(0.32, 0, 0, 50)
	reward.Font = Enum.Font.GothamMedium
	reward.TextSize = 12
	reward.TextWrapped = true
	reward.TextXAlignment = Enum.TextXAlignment.Left
	reward.TextYAlignment = Enum.TextYAlignment.Top
	reward.TextColor3 = Color3.fromRGB(230, 220, 170)
	reward.Text = entry.RewardPreview and table.concat(entry.RewardPreview, "\n") or ""
	reward.Parent = card
	if status == "Available" then addButton(card, "Start", 0, "Start", quest.Id) end
	if status == "Active" then addButton(card, entry.Tracked and "Untrack" or "Track", 0, entry.Tracked and "Untrack" or "Track", quest.Id) addButton(card, "Abandon", 100, "Abandon", quest.Id) end
	if status == "ReadyToTurnIn" then addButton(card, "Track", 0, "Track", quest.Id) addButton(card, "Turn In", 100, "TurnIn", quest.Id) end
end

local function renderJournal(snapshot)
	clearQuestCards()
	if not snapshot or type(snapshot.Quests) ~= "table" then return end
	for index, entry in ipairs(snapshot.Quests) do makeQuestCard(entry, index) end
	questList.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 12)
end

local function refreshJournal()
	local ok, snapshot = pcall(function() return requestJournal:InvokeServer() end)
	if ok then renderJournal(snapshot) end
end

local function toggleJournal()
	journal.Visible = not journal.Visible
	if journal.Visible then refreshJournal() end
end

closeJournal.MouseButton1Click:Connect(function() journal.Visible = false end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local keyCode = Enum.KeyCode[settings.JournalKeyCodeName or "J"]
	if keyCode and input.KeyCode == keyCode then toggleJournal() end
end)

RunService.RenderStepped:Connect(updateTimerText)
smartQuestUpdate.OnClientEvent:Connect(updateTracker)
smartQuestToast.OnClientEvent:Connect(showToast)
smartQuestJournal.OnClientEvent:Connect(function(snapshot)
	renderJournal(snapshot)
	if journal.Visible then renderJournal(snapshot) end
end)

task.defer(refreshJournal)
