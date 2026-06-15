# Tagged Object Setup

SmartQuest supports two optional automation tags:

- `SmartQuestInteract`
- `SmartQuestZone`

These are meant to save setup time inside Roblox Studio.

## SmartQuestInteract

Use this for objects the player activates with a ProximityPrompt.

### Setup

1. Insert a `Part` or `Model`.
2. Tag it with `SmartQuestInteract` using Roblox Studio's Tag Editor.
3. Add these attributes:

```txt
QuestId: string = RepairPower
StepId: string = FindFuse
PromptText: string = Pick up Fuse
HoldDuration: number = 0.25
MaxActivationDistance: number = 10
Amount: number = 1
```

When the player triggers the prompt, the server calls:

```lua
SmartQuestService:Progress(player, "RepairPower", "FindFuse", 1)
```

## SmartQuestZone

Use this for invisible objective zones, room triggers, tutorial areas, map checkpoints, or quest locations.

### Setup

1. Insert a `Part`.
2. Make it transparent and non-collidable if desired.
3. Tag it with `SmartQuestZone`.
4. Add these attributes:

```txt
QuestId: string = RepairPower
StepId: string = ReturnToMainRoom
Amount: number = 1
```

When a player touches the part, the server progresses the step.

## Common Problems

### The prompt does not show

Check that:

- The object has the `SmartQuestInteract` tag.
- `QuestId` is a string attribute.
- `StepId` is a string attribute.
- The tagged object is a `BasePart` or a `Model` containing a `BasePart`.

### The objective does not progress

Check that:

- The quest exists in `SmartQuestConfig.lua`.
- The step ID matches exactly.
- The step is currently active.
- The player has not already completed the quest.

### The zone keeps firing repeatedly

SmartQuest has a short per-player debounce for zones. If you need stricter one-time behavior, handle that in the quest design or add a future one-shot attribute.
