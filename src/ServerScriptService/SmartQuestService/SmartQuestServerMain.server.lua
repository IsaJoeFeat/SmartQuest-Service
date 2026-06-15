--!strict
-- SmartQuestServerMain
-- Boot script for SmartQuestService.

local SmartQuestService = require(script.Parent:WaitForChild("SmartQuestService"))

-- Optional reward integration.
-- Keep SmartQuest generic; connect this to your project's economy/inventory/XP systems.
SmartQuestService:SetRewardHandler(function(player, rewards, quest, state)
	print("[SmartQuestService] Reward hook:", player.Name, quest.Id, rewards)
	-- Example:
	-- if rewards.Currency and rewards.Currency.Coins then
	-- 	CurrencyService:Add(player, "Coins", rewards.Currency.Coins)
	-- end
end)

-- Optional persistence integration.
-- Replace this with your own ProfileService/DataService wrapper.
-- SmartQuestService:SetPersistenceAdapter({
-- 	Load = function(player)
-- 		return DataService:Get(player, "SmartQuest")
-- 	end,
-- 	Save = function(player, data)
-- 		DataService:Set(player, "SmartQuest", data)
-- 	end,
-- })

-- Optional custom prerequisite/condition examples.
-- SmartQuestService:SetPrerequisiteHandler("HasItem", function(player, itemId, quest)
-- 	return InventoryService:HasItem(player, itemId), "You need " .. itemId
-- end)
--
-- SmartQuestService:SetConditionHandler("HasItem", function(player, itemId, quest, step)
-- 	return InventoryService:HasItem(player, itemId), "You need " .. itemId
-- end)

SmartQuestService:Init()

print("[SmartQuestService] v3 initialized.")
