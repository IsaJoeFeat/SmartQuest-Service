# SmartQuest Service

SmartQuest Service is a reusable, server-authoritative quest and objective system for Roblox Studio.

It is built as a drop-in toolkit service that can be imported into multiple projects instead of rewriting quest logic every time. It is intentionally game-agnostic, so it can support RP jobs, zombie Easter egg steps, tutorials, story missions, simulator tasks, dungeon objectives, daily errands, or minigame task chains.

## Version

`v2.0.0`

This version upgrades SmartQuest from a basic objective tracker into a fuller reusable quest service.

## Core Rule

**The server owns quest progress.**

Clients show trackers, journal entries, markers, and toast messages. They do not decide when objectives complete.

## Feature List

SmartQuest v2 includes:

- Config-based quests
- Server-authoritative quest state
- Quest prerequisites
- Tagged quest givers
- Objective markers
- Quest journal UI
- Repeatable quests
- Repeat cooldowns
- Reward handler hook
- Quest and step signals
- Step conditions
- Timed objective steps
- Time limits that can fail quests
- Tagged interactables
- Tagged objective zones
- Startup validation warnings
- Basic client tracker UI
- Basic toast UI

## Roblox Studio Layout

Place the files like this:

```txt
ReplicatedStorage
└── SmartQuestService
    ├── SmartQuestConfig.lua
    └── SmartQuestShared.lua

ServerScriptService
└── SmartQuestService
    ├── SmartQuestService.lua
    └── SmartQuestServerMain.server.lua

StarterPlayer
└── StarterPlayerScripts
    └── SmartQuestClient.client.lua
```

At runtime, the server creates:

```txt
ReplicatedStorage
└── SmartQuestRemotes
    ├── SmartQuestUpdate
    ├── SmartQuestToast
    ├── SmartQuestJournal
    └── SmartQuestRequestJournal
```

## Quick Start

### Start a quest

```lua
local SmartQuestService = require(game.ServerScriptService.SmartQuestService.SmartQuestService)

SmartQuestService:StartQuest(player, "TrainingObjectives")
```

### Progress an objective

```lua
SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)
```

Only the current active step can progress. If a player tries to progress a future step, SmartQuest ignores it.

## Quest Definition Example

```lua
TrainingObjectives = {
    Id = "TrainingObjectives",
    Title = "Training",
    Description = "A sample quest showing count progress, a timer, and rewards.",
    Repeatable = true,
    RepeatCooldown = 30,
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
            Required = 1,
        },
    },
    Rewards = {
        Currency = {
            Coins = 25,
        },
    },
}
```

## Step Types

| Type | Purpose |
|---|---|
| `Interact` | Player uses an object, NPC, machine, console, or similar object. |
| `Collect` | Player collects one or more objects/items. |
| `Kill` | Player defeats enemies. |
| `ReachZone` | Player enters a quest area. |
| `Timer` | Step completes automatically after `Duration` seconds. |
| `Custom` | Any project-specific objective. |

## Quest Prerequisites

Prerequisites prevent a quest from starting until requirements are met.

```lua
Prerequisites = {
    CompletedQuests = {"TrainingObjectives"},
    NotCompletedQuests = {"BadEnding"},
    Custom = {
        HasItem = "Fuse",
    },
}
```

Built-in checks:

- `CompletedQuests`
- `ActiveQuests`
- `NotCompletedQuests`

Custom checks are registered from the server:

```lua
SmartQuestService:SetPrerequisiteHandler("HasItem", function(player, itemId, quest)
    return InventoryService:HasItem(player, itemId), "You need " .. itemId
end)
```

## Step Conditions

Conditions block a specific step from progressing until requirements are met.

```lua
Conditions = {
    CompletedQuests = {"TrainingObjectives"},
    Custom = {
        HasItem = "Fuse",
    },
}
```

Register custom condition handlers:

```lua
SmartQuestService:SetConditionHandler("HasItem", function(player, itemId, quest, step)
    return InventoryService:HasItem(player, itemId), "You need " .. itemId
end)
```

## Tagged Quest Givers

Tag an NPC, part, or model with:

```txt
SmartQuestGiver
```

Attributes:

```txt
QuestId: string = RepairPower
PromptText: string = Start Quest
ObjectText: string = Quest
HoldDuration: number = 0
MaxActivationDistance: number = 10
```

SmartQuest creates a ProximityPrompt and calls `StartQuest()` when triggered.

## Tagged Interactables

Tag an object with:

```txt
SmartQuestInteract
```

Attributes:

```txt
QuestId: string = RepairPower
StepId: string = FindFuse
PromptText: string = Pick up Fuse
Amount: number = 1
```

SmartQuest creates a prompt and calls `Progress()` when triggered.

## Tagged Zones

Tag a BasePart with:

```txt
SmartQuestZone
```

Attributes:

```txt
QuestId: string = RepairPower
StepId: string = ReturnToMainRoom
Amount: number = 1
```

Touching the zone progresses the active step.

## Objective Markers

Quest steps can show a world-space marker.

```lua
{
    Id = "RepairGenerator",
    Text = "Repair the generator",
    Type = "Interact",
    TargetTag = "Generator",
    Marker = true,
    MarkerText = "Generator",
    Required = 1,
}
```

Target lookup order:

1. `TargetTag`
2. `TargetName`
3. `Target`

The client creates a BillboardGui marker over the resolved object.

## Quest Journal

The client includes a basic quest journal. By default, press `J`.

Change the key in `SmartQuestConfig.Settings`:

```lua
JournalKeyCodeName = "J"
```

The journal shows:

- Quest title
- Status
- Description
- Current active objective
- Progress count
- Availability state

## Repeatable Quests

```lua
Repeatable = true,
RepeatCooldown = 300,
```

A completed repeatable quest can be started again after the cooldown ends.

## Rewards

SmartQuest stores reward data but does not hardcode a money, item, badge, or XP system. Connect your own project systems with one hook:

```lua
SmartQuestService:SetRewardHandler(function(player, rewards, quest, state)
    if rewards.Currency and rewards.Currency.Coins then
        CurrencyService:Add(player, "Coins", rewards.Currency.Coins)
    end
end)
```

SmartQuest also fires `RewardGranted` after the reward handler runs successfully.

## Signals

SmartQuest exposes signals for integration with other systems:

```lua
SmartQuestService.QuestStarted
SmartQuestService.QuestCompleted
SmartQuestService.QuestFailed
SmartQuestService.QuestAbandoned
SmartQuestService.StepStarted
SmartQuestService.StepProgressed
SmartQuestService.StepCompleted
SmartQuestService.RewardGranted
```

Example:

```lua
SmartQuestService.QuestCompleted:Connect(function(player, questId, quest, rewards)
    print(player.Name .. " completed " .. questId)
end)
```

## Timed Objectives

A timer step completes itself after `Duration` seconds:

```lua
{
    Id = "HoldPosition",
    Text = "Hold position for 10 seconds",
    Type = "Timer",
    Duration = 10,
    Required = 1,
}
```

Any step can also have a `TimeLimit`:

```lua
{
    Id = "RepairGenerator",
    Text = "Repair the generator before time runs out",
    Type = "Interact",
    TimeLimit = 120,
    FailQuestOnTimeout = true,
}
```

The client tracker displays remaining time.

## Startup Validation

SmartQuest warns about common setup issues:

- Duplicate step IDs
- Marker steps with no target field
- Tagged objects missing `QuestId`
- Interact/zone objects missing `StepId`
- Tagged zone object not being a BasePart

Validation can be disabled in config:

```lua
EnableStartupValidation = false
```

## Public API

### `SmartQuestService:Init()`

Boots the system.

### `SmartQuestService:RegisterQuest(quest)`

Registers one quest.

### `SmartQuestService:RegisterQuests(quests)`

Registers multiple quests.

### `SmartQuestService:StartQuest(player, questId)`

Starts a quest if available.

### `SmartQuestService:Progress(player, questId, stepId, amount?)`

Progresses the active step.

### `SmartQuestService:CompleteQuest(player, questId)`

Force-completes an active quest.

### `SmartQuestService:FailQuest(player, questId, reason?)`

Fails an active quest.

### `SmartQuestService:AbandonQuest(player, questId)`

Marks an active quest abandoned.

### `SmartQuestService:ResetQuest(player, questId)`

Clears one quest state.

### `SmartQuestService:ResetPlayer(player)`

Clears all quest state for the player.

### `SmartQuestService:GetQuestState(player, questId)`

Returns one quest state.

### `SmartQuestService:GetAllStates(player)`

Returns all quest states for one player.

### `SmartQuestService:GetJournalSnapshot(player)`

Returns all quest data needed by the journal UI.

### `SmartQuestService:CanStartQuest(player, questId)`

Returns whether the player can start the quest and an optional reason.

### `SmartQuestService:SetRewardHandler(callback)`

Connects SmartQuest to your reward system.

### `SmartQuestService:SetPrerequisiteHandler(name, callback)`

Adds a custom prerequisite check.

### `SmartQuestService:SetConditionHandler(name, callback)`

Adds a custom step condition check.

## Import Checklist

- [ ] Move `src/ReplicatedStorage/SmartQuestService` into `ReplicatedStorage`
- [ ] Move `src/ServerScriptService/SmartQuestService` into `ServerScriptService`
- [ ] Move `src/StarterPlayer/StarterPlayerScripts/SmartQuestClient.client.lua` into `StarterPlayerScripts`
- [ ] Press Play
- [ ] Check output for `[SmartQuestService] v2 initialized.`
- [ ] Test `examples/ExampleUsage.server.lua`
- [ ] Create a tagged `SmartQuestGiver`
- [ ] Create a tagged `SmartQuestInteract`
- [ ] Create a tagged `SmartQuestZone`
- [ ] Press `J` in-game to test the journal

## Roadmap

Possible future additions:

- DataStore adapter
- Quest save/load profile integration
- Branching quest graphs
- Dialogue service integration
- Party/shared quest progress
- Generated quest cards with icons
- Better marker arrows at screen edge
- Studio validator plugin
- Rojo project file
- Wally package support

## License

Use this in your Roblox projects. Add a formal license if you want this repo to be public-facing for other developers.
