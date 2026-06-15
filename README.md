# SmartQuest Service

SmartQuest Service is a reusable, server-authoritative quest and objective system for Roblox Studio.

It is built as a drop-in toolkit service that can be imported into multiple projects instead of rewriting quest logic every time. It is intentionally game-agnostic, so it can support RP jobs, zombie Easter egg steps, tutorials, story missions, simulator tasks, dungeon objectives, daily errands, and minigame task chains.

## Version

`v3.0.0` — long-term usable release.

This is the finalized full-service pass. The system now covers the core quest lifecycle, player-facing UI, map automation, saving hooks, validation, debugging, quest arcs, parallel objectives, objective groups, repeatable quests, and reward previews.

## Core Rule

**The server owns quest progress.**

Clients display trackers, journal entries, markers, timers, rewards, and buttons. Clients never decide when objectives complete.

## Included Features

SmartQuest v3 includes:

- Config-based quests
- Server-authoritative quest state
- Quest prerequisites
- Step conditions
- Tagged quest givers
- Tagged interactables
- Tagged objective zones
- Objective markers
- Distance-capable marker payloads
- Quest journal UI
- Journal actions: start, track, untrack, abandon, turn in
- Tracked quest selection
- Multiple active quests
- Repeatable quests
- Repeat cooldowns
- Reward handler hook
- Reward preview formatting
- Quest and step signals
- Timed objectives
- Time limits that can fail quests
- Ready-to-turn-in quest state
- Return-to-giver completion
- Parallel objectives
- Objective group progress
- Quest arcs/chains
- Persistence adapter hook
- Debug helper methods
- Startup validator module

Skipped intentionally per project direction:

- Rojo project setup
- Dialogue service integration

## Roblox Studio Layout

Place the files like this:

```txt
ReplicatedStorage
└── SmartQuestService
    ├── SmartQuestConfig.lua
    ├── SmartQuestRewardFormatter.lua
    └── SmartQuestShared.lua

ServerScriptService
└── SmartQuestService
    ├── SmartQuestService.lua
    ├── SmartQuestServerMain.server.lua
    └── SmartQuestValidator.lua

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
    ├── SmartQuestRequestJournal
    └── SmartQuestAction
```

## Quick Start

```lua
local SmartQuestService = require(game.ServerScriptService.SmartQuestService.SmartQuestService)

SmartQuestService:StartQuest(player, "TrainingObjectives")
SmartQuestService:Progress(player, "TrainingObjectives", "CollectParts", 1)
```

Only valid active objectives can progress.

## Quest Definition

```lua
TrainingObjectives = {
    Id = "TrainingObjectives",
    Title = "Training",
    Description = "A repeatable sample quest.",
    Repeatable = true,
    RepeatCooldown = 30,
    ProgressionMode = "Sequential",
    Completion = {Mode = "Auto"},
    Steps = {
        {
            Id = "CollectParts",
            Text = "Collect 3 parts",
            Type = "Collect",
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
    },
    Rewards = {
        Currency = {Coins = 25},
        XP = 10,
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
| `Group` | Step progresses from unique targets, such as repairing any 3 relay boxes. |
| `Custom` | Any project-specific objective. |

## Progression Modes

### Sequential

Only the current step can progress.

```lua
ProgressionMode = "Sequential"
```

### Parallel

All incomplete steps are active at the same time.

```lua
ProgressionMode = "Parallel"
```

Use this for quests like:

```txt
Defend the Generator
- Defeat 5 enemies
- Repair any 3 relays
- Survive 30 seconds
```

## Objective Groups

Group objectives support unique progress keys.

```lua
{
    Id = "RepairRelays",
    Text = "Repair any 3 relay boxes",
    Type = "Group",
    Required = 3,
}
```

Progress it like this:

```lua
SmartQuestService:Progress(player, "DefendGenerator", "RepairRelays", 1, "RelayA")
```

The same `progressKey` will not count twice.

## Completion Modes

### Auto

Completes immediately when all objectives are done.

```lua
Completion = {Mode = "Auto"}
```

### ReturnToGiver

Moves the quest to `ReadyToTurnIn` after objectives are done.

```lua
Completion = {
    Mode = "ReturnToGiver",
    GiverTag = "PowerQuestGiver",
}
```

The player must trigger the quest giver again or the server must call:

```lua
SmartQuestService:TurnInQuest(player, "RepairPower")
```

### Manual

Moves the quest to `ReadyToTurnIn`, but your code decides when to complete it.

## Quest Prerequisites

```lua
Prerequisites = {
    CompletedQuests = {"TrainingObjectives"},
    ActiveQuests = {"SomeActiveQuest"},
    NotCompletedQuests = {"BadEnding"},
    Custom = {
        HasItem = "Fuse",
    },
}
```

Register custom prerequisite handlers:

```lua
SmartQuestService:SetPrerequisiteHandler("HasItem", function(player, itemId, quest)
    return InventoryService:HasItem(player, itemId), "You need " .. itemId
end)
```

## Step Conditions

```lua
Conditions = {
    CompletedQuests = {"TrainingObjectives"},
    Custom = {
        HasItem = "Fuse",
    },
}
```

Register custom step condition handlers:

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

A giver starts an available quest. If the quest is `ReadyToTurnIn`, the same giver turns it in.

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
ProgressKey: string = OptionalUniqueKey
```

`ProgressKey` is especially useful for group objectives.

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

Touching the zone progresses the objective.

## Objective Markers

Quest steps can show world-space markers.

```lua
{
    Id = "RepairGenerator",
    Text = "Repair the generator",
    Type = "Interact",
    TargetTag = "Generator",
    Marker = true,
    MarkerText = "Generator",
    ShowDistance = true,
    HideWithin = 8,
}
```

Target lookup order:

1. `TargetTag`
2. `TargetName`
3. `Target`

The server sends marker payloads to the client. The client renders BillboardGui markers.

## Quest Journal

Press `J` by default.

The journal supports:

- Available quests
- Locked quests
- Active quests
- Ready-to-turn-in quests
- Completed quests
- Reward previews
- Start button
- Track/untrack button
- Abandon button
- Turn-in button

Change the key:

```lua
JournalKeyCodeName = "J"
```

## Tracked Quests

Set the tracked quest manually:

```lua
SmartQuestService:SetTrackedQuest(player, "RepairPower")
```

The journal can also track/untrack quests through client buttons.

## Repeatable Quests

```lua
Repeatable = true,
RepeatCooldown = 300,
```

Repeatable quests can be restarted after the cooldown ends.

## Rewards

SmartQuest does not hardcode a currency, item, badge, or XP system. Use the reward hook:

```lua
SmartQuestService:SetRewardHandler(function(player, rewards, quest, state)
    if rewards.Currency and rewards.Currency.Coins then
        CurrencyService:Add(player, "Coins", rewards.Currency.Coins)
    end
end)
```

Reward previews are formatted by `SmartQuestRewardFormatter.lua`.

## Persistence Adapter

SmartQuest does not force a save system. Connect it to your own ProfileService/DataService wrapper:

```lua
SmartQuestService:SetPersistenceAdapter({
    Load = function(player)
        return DataService:Get(player, "SmartQuest")
    end,

    Save = function(player, data)
        DataService:Set(player, "SmartQuest", data)
    end,
})
```

Saved data includes:

- Quest states
- Step progress
- Completion status
- Repeat cooldowns
- Tracked quest
- Active quest arc
- Arc index

## Quest Arcs

Quest arcs chain quests together.

```lua
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
```

Start an arc:

```lua
SmartQuestService:StartQuestArc(player, "PowerRestorationArc")
```

When one quest completes, the next quest in the arc starts automatically.

## Signals

```lua
SmartQuestService.QuestStarted
SmartQuestService.QuestCompleted
SmartQuestService.QuestFailed
SmartQuestService.QuestAbandoned
SmartQuestService.QuestReadyToTurnIn
SmartQuestService.StepStarted
SmartQuestService.StepProgressed
SmartQuestService.StepCompleted
SmartQuestService.RewardGranted
SmartQuestService.TrackedQuestChanged
```

Example:

```lua
SmartQuestService.QuestCompleted:Connect(function(player, questId, quest, rewards)
    print(player.Name .. " completed " .. questId)
end)
```

## Debug Helpers

```lua
SmartQuestService:DebugStart(player, questId)
SmartQuestService:DebugCompleteCurrentStep(player, questId)
SmartQuestService:DebugCompleteQuest(player, questId)
SmartQuestService:DebugReset(player)
SmartQuestService:DebugPrintState(player)
```

Use these for development/testing only.

## Validator

`SmartQuestValidator.lua` checks common setup problems:

- Duplicate step IDs
- Missing step IDs
- Missing quest references
- Missing arc quest references
- Marker steps with no target field
- Timer steps with no duration
- Group steps with no targets table
- Tagged objects referencing missing quests/steps

Disable validation:

```lua
EnableStartupValidation = false
```

## Public API

```lua
SmartQuestService:Init()
SmartQuestService:RegisterQuest(quest)
SmartQuestService:RegisterQuests(quests)
SmartQuestService:StartQuest(player, questId)
SmartQuestService:StartQuestArc(player, arcId)
SmartQuestService:Progress(player, questId, stepId, amount?, progressKey?)
SmartQuestService:TurnInQuest(player, questId)
SmartQuestService:CompleteQuest(player, questId)
SmartQuestService:FailQuest(player, questId, reason?)
SmartQuestService:AbandonQuest(player, questId)
SmartQuestService:ResetQuest(player, questId)
SmartQuestService:ResetPlayer(player)
SmartQuestService:SetTrackedQuest(player, questId?)
SmartQuestService:GetQuestState(player, questId)
SmartQuestService:GetAllStates(player)
SmartQuestService:GetJournalSnapshot(player)
SmartQuestService:CanStartQuest(player, questId)
SmartQuestService:SetRewardHandler(callback)
SmartQuestService:SetPersistenceAdapter(adapter)
SmartQuestService:SetPrerequisiteHandler(name, callback)
SmartQuestService:SetConditionHandler(name, callback)
SmartQuestService:ValidateSetup()
```

## Import Checklist

- [ ] Move `src/ReplicatedStorage/SmartQuestService` into `ReplicatedStorage`
- [ ] Move `src/ServerScriptService/SmartQuestService` into `ServerScriptService`
- [ ] Move `src/StarterPlayer/StarterPlayerScripts/SmartQuestClient.client.lua` into `StarterPlayerScripts`
- [ ] Press Play
- [ ] Check output for `[SmartQuestService] v3 initialized.`
- [ ] Test `examples/ExampleUsage.server.lua`
- [ ] Create a tagged `SmartQuestGiver`
- [ ] Create a tagged `SmartQuestInteract`
- [ ] Create a tagged `SmartQuestZone`
- [ ] Press `J` in-game to test the journal
- [ ] Connect your real reward handler
- [ ] Connect your real persistence adapter if the project saves quest progress

## Final Notes

SmartQuest v3 is intended to be stable enough to use across many projects without constant redesign. Future projects should mainly replace config content and connect project-specific systems through handlers/adapters.

## License

Use this in your Roblox projects. Add a formal license if you want this repo to be public-facing for other developers.
