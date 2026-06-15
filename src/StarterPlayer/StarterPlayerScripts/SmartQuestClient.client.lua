--!strict
-- SmartQuestClient
-- Basic client tracker UI for SmartQuestService.
-- Replace visuals freely. Server remains authoritative.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteFolder = ReplicatedStorage:WaitForChild("SmartQuestRemotes")
local smartQuestUpdate = remoteFolder:WaitForChild("SmartQuestUpdate") :: RemoteEvent
local smartQuestToast = remoteFolder:WaitForChild("SmartQuestToast") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "SmartQuestTrackerGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local tracker = Instance.new("Frame")
tracker.Name = "Tracker"
tracker.AnchorPoint = Vector2.new(1, 0)
tracker.Position = UDim2.fromScale(0.985, 0.14)
tracker.Size = UDim2.fromOffset(340, 120)
tracker.BackgroundTransparency = 0.25
tracker.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
tracker.BorderSizePixel = 0
tracker.Visible = false
tracker.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = tracker

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 14)
padding.PaddingRight = UDim.new(0, 14)
padding.Parent = tracker

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 24)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Quest"
title.Parent = tracker

local stepText = Instance.new("TextLabel")
stepText.Name = "StepText"
stepText.BackgroundTransparency = 1
stepText.Position = UDim2.fromOffset(0, 34)
stepText.Size = UDim2.new(1, 0, 0, 42)
stepText.Font = Enum.Font.Gotham
stepText.TextSize = 15
stepText.TextWrapped = true
stepText.TextXAlignment = Enum.TextXAlignment.Left
stepText.TextYAlignment = Enum.TextYAlignment.Top
stepText.TextColor3 = Color3.fromRGB(230, 230, 230)
stepText.Text = ""
stepText.Parent = tracker

local progress = Instance.new("TextLabel")
progress.Name = "Progress"
progress.BackgroundTransparency = 1
progress.Position = UDim2.fromOffset(0, 80)
progress.Size = UDim2.new(1, 0, 0, 24)
progress.Font = Enum.Font.GothamMedium
progress.TextSize = 14
progress.TextXAlignment = Enum.TextXAlignment.Left
progress.TextColor3 = Color3.fromRGB(190, 190, 190)
progress.Text = ""
progress.Parent = tracker

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.08)
toast.Size = UDim2.fromOffset(420, 44)
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

local function getCurrentStep(quest, state)
	return quest.Steps[state.CurrentStepIndex]
end

local function updateTracker(payload)
	local quest = payload.Quest
	local state = payload.State

	if not quest or not state then
		return
	end

	if state.Status == "Completed" then
		tracker.Visible = false
		return
	end

	local currentStep = getCurrentStep(quest, state)
	if not currentStep then
		tracker.Visible = false
		return
	end

	local stepState = state.Steps[currentStep.Id]
	local currentProgress = stepState and stepState.Progress or 0
	local required = stepState and stepState.Required or currentStep.Required or 1

	title.Text = quest.Title
	stepText.Text = currentStep.Text

	if required > 1 then
		progress.Text = `{currentProgress}/{required}`
	else
		progress.Text = `Step {state.CurrentStepIndex}/{#quest.Steps}`
	end

	tracker.Visible = true
end

local activeToastTween: Tween? = nil

local function showToast(payload)
	local text = payload.Text
	if type(text) ~= "string" or text == "" then
		return
	end

	if activeToastTween then
		activeToastTween:Cancel()
	end

	toast.Text = text
	toast.Visible = true
	toast.BackgroundTransparency = 0.25
	toast.TextTransparency = 0
	toast.Position = UDim2.fromScale(0.5, 0.08)

	local tweenIn = TweenService:Create(
		toast,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = UDim2.fromScale(0.5, 0.095)}
	)

	tweenIn:Play()

	task.delay(2.2, function()
		if not toast.Visible then
			return
		end

		activeToastTween = TweenService:Create(
			toast,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{BackgroundTransparency = 1, TextTransparency = 1}
		)

		activeToastTween:Play()
		activeToastTween.Completed:Wait()
		toast.Visible = false
	end)
end

smartQuestUpdate.OnClientEvent:Connect(updateTracker)
smartQuestToast.OnClientEvent:Connect(showToast)
