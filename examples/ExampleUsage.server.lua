-- ExampleUsage.server.lua
-- Put this under ServerScriptService to test SmartQuest v2 manually.

local Players = game:GetService("Players")
local SmartQuestService = require(game.ServerScriptService.SmartQuestService.SmartQuestService)

-- Example: connect SmartQuest to your own project systems.
SmartQuestService:SetRewardHandler(function(player, rewards, quest, state)
	print("Reward handler fired for", player.Name, quest.Id)
	print(rewards)
end)

SmartQuestService.QuestStarted:Connect(function(player, questId)
	print(player.Name .. " started quest " .. questId)
end)

SmartQuestService.StepCompleted:Connect(function(player, questId, stepId)
	print(player.Name .. " completed step " .. questId .. "." .. stepId)
end)

SmartQuestService.QuestCompleted:Connect(function(player, questId)
	print(player.Name .. " completed quest " .. questId)
end)

Players.PlayerAdded:Connect(function(player)
	task.wait(3)

	-- Starts a repeatable sample quest.
	SmartQuestService:StartQuest(player, "TrainingObjectives")

	task.wait(2)
	SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)

	task.wait(1)
	SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)

	task.wait(1)
	SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)

	-- The next step is a Timer step. SmartQuest completes it automatically after Duration seconds.
	-- After that, use a tagged SmartQuestInteract object or manually progress FinishTraining.
	task.wait(12)
	SmartQuestService:Progress(player, "TrainingObjectives", "FinishTraining", 1)
end)
