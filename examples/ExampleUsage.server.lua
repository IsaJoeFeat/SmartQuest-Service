-- ExampleUsage.server.lua
-- Put this under ServerScriptService to test manual objective progress.

local Players = game:GetService("Players")
local SmartQuestService = require(game.ServerScriptService.SmartQuestService.SmartQuestService)

Players.PlayerAdded:Connect(function(player)
	task.wait(3)

	SmartQuestService:StartQuest(player, "TrainingObjectives")

	task.wait(2)
	SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)

	task.wait(1)
	SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)

	task.wait(1)
	SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)

	task.wait(1)
	SmartQuestService:Progress(player, "TrainingObjectives", "FinishTraining", 1)
end)
