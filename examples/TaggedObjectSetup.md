# Tagged Object Setup

SmartQuest v2 supports three automation tags:

- `SmartQuestGiver`
- `SmartQuestInteract`
- `SmartQuestZone`

These tags let you build quest content quickly in Roblox Studio by placing an object, tagging it, and setting attributes.

## SmartQuestGiver

Use this for NPCs, boards, consoles, or objects that start a quest.

Attributes:

```txt
QuestId: string = RepairPower
PromptText: string = Start Quest
ObjectText: string = Quest
HoldDuration: number = 0
MaxActivationDistance: number = 10
```

When triggered, SmartQuest calls:

```lua
SmartQuestService:StartQuest(player, "RepairPower")
```

Prerequisites, repeat cooldowns, and completion checks are handled automatically.

## SmartQuestInteract

Use this for objects that progress an active quest step.

Attributes:

```txt
QuestId: string = RepairPower
StepId: string = FindFuse
PromptText: string = Pick up Fuse
ObjectText: string = Fuse Box
HoldDuration: number = 0.25
MaxActivationDistance: number = 10
Amount: number = 1
```

When triggered, SmartQuest calls:

```lua
SmartQuestService:Progress(player, "RepairPower", "FindFuse", 1)
```

Only the currently active step can progress.

## SmartQuestZone

Use this for objective area triggers, room checks, tutorial checkpoints, or map locations.

Attributes:

```txt
QuestId: string = RepairPower
StepId: string = ReturnToMainRoom
Amount: number = 1
```

When a player touches the zone part, the server progresses that step.

## Objective Markers

Markers are configured on quest steps.

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

SmartQuest finds the first object with the target tag/name and sends it to the client marker UI.

## Startup Warnings

SmartQuest v2 warns about common setup problems:

- Tagged object missing `QuestId`
- Interact/zone object missing `StepId`
- Marker step with no target field
- Duplicate quest step IDs

## Common Problems

### The prompt does not show

Check the tag, attributes, and whether the tagged object is a `BasePart` or a `Model` with a `BasePart`.

### The objective does not progress

Check the quest ID, step ID, active step, conditions, and whether the quest is already completed.

### The marker does not show

Check that the step has `Marker = true` and a valid `TargetTag`, `TargetName`, or `Target`.
