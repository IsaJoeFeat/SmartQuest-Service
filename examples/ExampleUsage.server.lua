-- ExampleUsage.server.lua
-- Put this under ServerScriptService to test SmartQuest v3 manually.

local Players = game:GetService("Players")
local SmartQuestService = require(game.ServerScriptService.SmartQuestService.SmartQuestService)

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

SmartQuestService.QuestReadyToTurnIn:Connect(function(player, questId)
	print(player.Name .. " is ready to turn in " .. questId)
end)

SmartQuestService.QuestCompleted:Connect(function(player, questId)
	print(player.Name .. " completed quest " .. questId)
end)

Players.PlayerAdded:Connect(function(player)
	task.wait(3)

	-- Start a full arc. It starts TrainingObjectives first.
	SmartQuestService:StartQuestArc(player, "PowerRestorationArc")

	task.wait(2)
	SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)
	SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)
	SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)

	-- Timer step completes automatically after its Duration.
	task.wait(12)
	SmartQuestService:Progress(player, "TrainingObjectives", "FinishTraining", 1)

	-- RepairPower starts automatically through the arc after TrainingObjectives completes.
	-- In real use, the tagged SmartQuestInteract objects would progress these steps.
	task.wait(2)
	SmartQuestService:Progress(player, "RepairPower", "FindFuse", 1)
	SmartQuestService:Progress(player, "RepairPower", "RepairGenerator", 1)
	SmartQuestService:Progress(player, "RepairPower", "ReturnToMainRoom", 1)

	-- RepairPower uses ReturnToGiver, so it must be turned in.
	task.wait(2)
	SmartQuestService:TurnInQuest(player, "RepairPower")

	-- DefendGenerator is a parallel quest from the arc.
	task.wait(2)
	SmartQuestService:Progress(player, "DefendGenerator", "KillEnemies", 5)
	SmartQuestService:Progress(player, "DefendGenerator", "RepairRelays", 1, "RelayA")
	SmartQuestService:Progress(player, "DefendGenerator", "RepairRelays", 1, "RelayB")
	SmartQuestService:Progress(player, "DefendGenerator", "RepairRelays", 1, "RelayC")
	-- Survive timer completes automatically.
end)
