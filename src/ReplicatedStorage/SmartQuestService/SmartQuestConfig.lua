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
	MaxActiveQuests = 5,
}

SmartQuestConfig.QuestArcs = {
	PowerRestorationArc = {
		Id = "PowerRestorationArc",
		Title = "Power Restoration Arc",
		Quests = {
			"TrainingObjectives",
			"RepairPower",
			"DefendGenerator",
		},
	},
}

SmartQuestConfig.Quests = {
	TrainingObjectives = {
		Id = "TrainingObjectives",
		Title = "Training",
		Description = "A repeatable sample quest showing count progress, a timed step, and completion rewards.",
		Repeatable = true,
		RepeatCooldown = 30,
		ProgressionMode = "Sequential",
		Completion = {Mode = "Auto"},
		Steps = {
			{
				Id = "CollectParts",
				Text = "Collect 3 parts",
				Type = "Collect",
				Target = "Part",
				Required = 3,
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
				TargetTag = "TrainingConsole",
				Marker = true,
				MarkerText = "Training Console",
				ShowDistance = true,
				HideWithin = 8,
				Required = 1,
			},
		},
		Rewards = {
			Currency = {Coins = 25},
			XP = 10,
		},
	},

	RepairPower = {
		Id = "RepairPower",
		Title = "Restore the Power",
		Description = "Find the missing fuse, repair the generator, then return to the quest giver.",
		Prerequisites = {
			CompletedQuests = {"TrainingObjectives"},
		},
		ProgressionMode = "Sequential",
		Completion = {
			Mode = "ReturnToGiver",
			GiverTag = "PowerQuestGiver",
		},
		Steps = {
			{
				Id = "FindFuse",
				Text = "Find the missing fuse",
				Type = "Interact",
				TargetTag = "FuseBox",
				Marker = true,
				MarkerText = "Fuse Box",
				ShowDistance = true,
				HideWithin = 8,
				Required = 1,
			},
			{
				Id = "RepairGenerator",
				Text = "Repair the generator before the backup battery dies",
				Type = "Interact",
				TargetTag = "Generator",
				Marker = true,
				MarkerText = "Generator",
				ShowDistance = true,
				HideWithin = 8,
				Required = 1,
				TimeLimit = 120,
				FailQuestOnTimeout = true,
				Conditions = {
					CompletedQuests = {"TrainingObjectives"},
				},
			},
			{
				Id = "ReturnToMainRoom",
				Text = "Return to the main room",
				Type = "ReachZone",
				TargetTag = "MainRoomZone",
				Marker = true,
				MarkerText = "Main Room",
				ShowDistance = true,
				HideWithin = 10,
				Required = 1,
			},
		},
		Rewards = {
			Currency = {Coins = 100},
			Stats = {PowerRestored = 1},
			Items = {GeneratorKey = 1},
		},
	},

	DefendGenerator = {
		Id = "DefendGenerator",
		Title = "Defend the Generator",
		Description = "A parallel objective quest. Complete the defense tasks in any order.",
		Prerequisites = {
			CompletedQuests = {"RepairPower"},
		},
		ProgressionMode = "Parallel",
		Completion = {Mode = "Auto"},
		Steps = {
			{
				Id = "KillEnemies",
				Text = "Defeat 5 enemies near the generator",
				Type = "Kill",
				Target = "Enemy",
				Required = 5,
			},
			{
				Id = "RepairRelays",
				Text = "Repair any 3 relay boxes",
				Type = "Group",
				Targets = {"RelayA", "RelayB", "RelayC", "RelayD", "RelayE"},
				TargetTag = "RelayBox",
				Marker = true,
				MarkerText = "Relay Box",
				Required = 3,
			},
			{
				Id = "Survive",
				Text = "Survive the defense timer",
				Type = "Timer",
				Duration = 30,
				TimeLimit = 45,
				Required = 1,
			},
		},
		Rewards = {
			Currency = {Coins = 250},
			XP = 50,
		},
	},

	DailyErrand = {
		Id = "DailyErrand",
		Title = "Daily Errand",
		Description = "A repeatable daily-style quest example with a cooldown.",
		Repeatable = true,
		RepeatCooldown = 300,
		ProgressionMode = "Sequential",
		Completion = {Mode = "Auto"},
		Steps = {
			{
				Id = "VisitNoticeBoard",
				Text = "Check the notice board",
				Type = "Interact",
				TargetTag = "NoticeBoard",
				Marker = true,
				MarkerText = "Notice Board",
				Required = 1,
			},
		},
		Rewards = {
			Currency = {Coins = 10},
		},
	},
}

return SmartQuestConfig
