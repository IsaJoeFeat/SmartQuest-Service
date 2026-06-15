# SmartQuest Service

SmartQuest Service is a reusable, server-authoritative quest and objective system for Roblox Studio.

It is built as a drop-in toolkit module you can import into multiple projects instead of rewriting quest logic every time. It is intentionally game-agnostic, so it can support RP jobs, zombie Easter egg steps, tutorials, story missions, simulator tasks, dungeon objectives, or minigame task chains.

## Core Rule

**The server owns quest progress.**

Clients only display objective state. Clients do not decide when objectives complete.

## What It Includes

- Config-based quest definitions
- Server-authoritative quest state
- Step-by-step objective progression
- Count-based progress such as `0/3`, `1/3`, `2/3`
- Quest started/completed toast messages
- Basic client objective tracker UI
- Optional tagged interactables using ProximityPrompts
- Optional tagged zones for reach-area objectives
- Clean API for other systems to call

## Current Version

`v1.0.0`

This version is a reusable foundation. It does not try to be a giant quest framework yet. The goal is to be easy to understand, easy to import, and easy to extend.

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
    └── SmartQuestToast
```

## Quick Start

### 1. Add a quest

Open:

```txt
ReplicatedStorage/SmartQuestService/SmartQuestConfig.lua
```

Example quest:

```lua
SmartQuestConfig.Quests.RepairPower = {
    Id = "RepairPower",
    Title = "Restore the Power",
    Description = "Find the fuse and repair the generator.",
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
    },
    Rewards = {
        Currency = {
            Coins = 100,
        },
    },
}
```

### 2. Start a quest from the server

```lua
local SmartQuestService = require(game.ServerScriptService.SmartQuestService.SmartQuestService)

SmartQuestService:StartQuest(player, "RepairPower")
```

### 3. Progress a step from the server

```lua
SmartQuestService:Progress(player, "RepairPower", "FindFuse", 1)
```

When the current step reaches its required progress, SmartQuest automatically moves to the next step. Completing the final step completes the quest.

## Recommended Step Types

Step types are descriptive in v1. Progress is still changed by the server with `Progress()`.

| Type | Use |
|---|---|
| `Interact` | Player uses an object, NPC, machine, door, console, etc. |
| `Collect` | Player gathers one or more items. |
| `Kill` | Player defeats enemies. |
| `ReachZone` | Player enters a specific area. |
| `Custom` | Any game-specific objective. |

Example count objective:

```lua
{
    Id = "CollectParts",
    Text = "Collect 3 machine parts",
    Type = "Collect",
    Target = "MachinePart",
    Required = 3,
}
```

Progress it like this:

```lua
SmartQuestService:Progress(player, "BuildMachine", "CollectParts", 1)
```

## Tagged Interactables

SmartQuest can automatically create a ProximityPrompt for tagged objects.

1. Insert a `Part` or `Model`.
2. Add the CollectionService tag:

```txt
SmartQuestInteract
```

3. Add attributes:

```txt
QuestId: string = RepairPower
StepId: string = FindFuse
PromptText: string = Pick up Fuse
HoldDuration: number = 0.25
MaxActivationDistance: number = 10
Amount: number = 1
```

When the player triggers the prompt, SmartQuest calls:

```lua
SmartQuestService:Progress(player, "RepairPower", "FindFuse", 1)
```

## Tagged Zones

SmartQuest can progress objectives when a player touches a tagged zone part.

1. Insert a `Part`.
2. Make it transparent and non-collidable if desired.
3. Add the CollectionService tag:

```txt
SmartQuestZone
```

4. Add attributes:

```txt
QuestId: string = RepairPower
StepId: string = ReturnToMainRoom
Amount: number = 1
```

## Public API

### `SmartQuestService:Init()`

Boots the system, registers quests from config, creates remotes, and binds tagged objects.

### `SmartQuestService:RegisterQuest(questDefinition)`

Registers one quest manually.

```lua
SmartQuestService:RegisterQuest({
    Id = "ExampleQuest",
    Title = "Example Quest",
    Steps = {
        { Id = "Step1", Text = "Do the thing", Required = 1 },
    },
})
```

### `SmartQuestService:RegisterQuests(quests)`

Registers multiple quests from a config table.

### `SmartQuestService:StartQuest(player, questId)`

Starts a quest for a player. Returns `true` if the quest started or was already active.

### `SmartQuestService:Progress(player, questId, stepId, amount?)`

Progresses the active step.

Important behavior:

- If the quest is not started, SmartQuest starts it automatically.
- Only the current active step can progress.
- Completed steps advance to the next step.
- Completing the final step completes the quest.

### `SmartQuestService:CompleteQuest(player, questId)`

Force-completes an active quest.

### `SmartQuestService:FailQuest(player, questId)`

Fails an active quest.

### `SmartQuestService:GetQuestState(player, questId)`

Returns the player's runtime state for one quest.

### `SmartQuestService:GetAllStates(player)`

Returns all tracked quest states for the player.

### `SmartQuestService:ResetPlayer(player)`

Clears all quest state for a player. Useful for testing, round resets, or fresh sessions.

## Quest Definition Format

```lua
{
    Id = "QuestId",
    Title = "Quest Title",
    Description = "Optional description.",
    AutoStart = false,
    Steps = {
        {
            Id = "StepId",
            Text = "Objective text shown to player",
            Type = "Interact",
            Target = "OptionalTargetId",
            Required = 1,
            Optional = false,
        },
    },
    Rewards = {
        -- Optional. SmartQuest does not spend/give rewards by itself in v1.
    },
}
```

## Reward Hook

SmartQuest stores the `Rewards` table but does not directly give currency/items yet. That is intentional because every project may use a different reward system.

Inside `CompleteQuest()`, there is a clear future hook:

```lua
-- RewardService:Give(player, quest.Rewards)
```

Connect this once to your project's `CurrencyService`, `InventoryService`, `XPService`, `BadgeService`, `JobService`, or any other reward handler.

## Design Philosophy

1. **Server authority first.** The client never decides quest completion.
2. **Config over one-off scripts.** Most quests should be created by editing tables, not writing new systems.
3. **Generic objective types.** The same system should work across many game genres.
4. **Automation where it helps.** Tags and attributes let you make interactables and zones functional quickly.
5. **No hidden magic.** If something does not work, the tag, attributes, quest ID, and step ID should be easy to inspect.

## Current Limits

v1 does not include:

- DataStore persistence
- Objective markers/arrows
- Branching dialogue quests
- Party/shared quest progress
- Time-limited objectives
- Quest prerequisites
- Built-in rewards
- Studio validator plugin
- Full generated quest journal UI

These are planned as later layers.

## Suggested Roadmap

### v1.1

- Quest prerequisites
- Repeatable quests
- Quest abandon/restart
- Better tracker UI config
- RewardService integration hook

### v1.2

- Objective markers
- Quest journal UI
- Optional DataStore adapter
- Better typed config validation

### v1.3

- Dialogue hooks
- NPC quest giver support
- Branching steps
- Optional step conditions

### v1.4

- Studio setup validator
- Warnings for missing tags/attributes
- Quest config linting

## Import Checklist

After importing into a Roblox project:

- [ ] `SmartQuestConfig.lua` is under `ReplicatedStorage/SmartQuestService`
- [ ] `SmartQuestShared.lua` is under `ReplicatedStorage/SmartQuestService`
- [ ] `SmartQuestService.lua` is under `ServerScriptService/SmartQuestService`
- [ ] `SmartQuestServerMain.server.lua` is under `ServerScriptService/SmartQuestService`
- [ ] `SmartQuestClient.client.lua` is under `StarterPlayer/StarterPlayerScripts`
- [ ] Press Play and check output for `[SmartQuestService] SmartQuestService initialized.`
- [ ] Test with `examples/ExampleUsage.server.lua`

## License

Use this however you want in your own Roblox projects. Add a formal license later if this repo becomes public-facing for other developers.
