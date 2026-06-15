--!strict
-- SmartQuestConfig
-- Put reusable/demo quests here, or replace this file per-project.

local SmartQuestConfig = {}

SmartQuestConfig.Quests = {
	RepairPower = {
		Id = "RepairPower",
		Title = "Restore the Power",
		Description = "Find the missing fuse, repair the generator, then return to the main room.",
		Steps = {
			{
				Id = "FindFuse",
				Text = "Find the missing fuse",
				Type = "Interact",
				Target = "FuseBox",
				Required = 1,
			},
			{
				Id = "RepairGenerator",
				Text = "Repair the generator",
				Type = "Interact",
				Target = "Generator",
				Required = 1,
			},
			{
				Id = "ReturnToMainRoom",
				Text = "Return to the main room",
				Type = "ReachZone",
				Target = "MainRoom",
				Required = 1,
			},
		},
		Rewards = {
			Currency = {
				Coins = 100,
			},
		},
	},

	TrainingObjectives = {
		Id = "TrainingObjectives",
		Title = "Training",
		Description = "A tiny example quest showing count-based progress.",
		Steps = {
			{
				Id = "CollectParts",
				Text = "Collect 3 parts",
				Type = "Collect",
				Target = "Part",
				Required = 3,
			},
			{
				Id = "FinishTraining",
				Text = "Use the training console",
				Type = "Interact",
				Target = "TrainingConsole",
				Required = 1,
			},
		},
		Rewards = {
			Currency = {
				Coins = 25,
			},
		},
	},
}

return SmartQuestConfig
