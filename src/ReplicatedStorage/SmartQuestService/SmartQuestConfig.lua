--!strict
-- SmartQuestConfig
-- Replace or expand these quests per project.

local SmartQuestConfig = {}

SmartQuestConfig.Settings = {
	AutoCreatePrompts = true,
	AutoBindQuestGivers = true,
	AutoBindInteractables = true,
	AutoBindZones = true,
	EnableStartupValidation = true,
	DefaultPromptDistance = 10,
	DefaultPromptHoldDuration = 0,
	JournalKeyCodeName = "J",
}

SmartQuestConfig.Quests = {
	TrainingObjectives = {
		Id = "TrainingObjectives",
		Title = "Training",
		Description = "A polished sample quest showing count progress, a timed step, and completion rewards.",
		Repeatable = true,
		RepeatCooldown = 30,
		Steps = {
			{
				Id = "CollectParts",
				Text = "Collect 3 parts",
				Type = "Collect",
				Target = "Part",
				Required = 3,
				Marker = false,
			},
			{
				Id = "HoldPosition",
				Text = "Hold position for 10 seconds",
				Type = "Timer",
				Duration = 10,
				TimeLimit = 20,
				Required = 1,
			},
			{
				Id = "FinishTraining",
				Text = "Use the training console",
				Type = "Interact",
				Target = "TrainingConsole",
				TargetTag = "TrainingConsole",
				Marker = true,
				MarkerText = "Training Console",
				Required = 1,
			},
		},
		Rewards = {
			Currency = {
				Coins = 25,
			},
		},
	},

	RepairPower = {
		Id = "RepairPower",
		Title = "Restore the Power",
		Description = "Find the missing fuse, repair the generator, then return to the main room.",
		Prerequisites = {
			CompletedQuests = {"TrainingObjectives"},
		},
		Steps = {
			{
				Id = "FindFuse",
				Text = "Find the missing fuse",
				Type = "Interact",
				Target = "FuseBox",
				TargetTag = "FuseBox",
				Marker = true,
				MarkerText = "Fuse Box",
				Required = 1,
			},
			{
				Id = "RepairGenerator",
				Text = "Repair the generator before the backup battery dies",
				Type = "Interact",
				Target = "Generator",
				TargetTag = "Generator",
				Marker = true,
				MarkerText = "Generator",
				Required = 1,
				TimeLimit = 120,
				FailQuestOnTimeout = true,
			},
			{
				Id = "ReturnToMainRoom",
				Text = "Return to the main room",
				Type = "ReachZone",
				Target = "MainRoom",
				TargetTag = "MainRoomZone",
				Marker = true,
				MarkerText = "Main Room",
				Required = 1,
			},
		},
		Rewards = {
			Currency = {
				Coins = 100,
			},
			Stats = {
				PowerRestored = 1,
			},
		},
	},

	DailyErrand = {
		Id = "DailyErrand",
		Title = "Daily Errand",
		Description = "A repeatable quest example with a cooldown.",
		Repeatable = true,
		RepeatCooldown = 300,
		Steps = {
			{
				Id = "VisitNoticeBoard",
				Text = "Check the notice board",
				Type = "Interact",
				TargetTag = "NoticeBoard",
				Marker = true,
				Required = 1,
			},
		},
		Rewards = {
			Currency = {
				Coins = 10,
			},
		},
	},
}

return SmartQuestConfig
