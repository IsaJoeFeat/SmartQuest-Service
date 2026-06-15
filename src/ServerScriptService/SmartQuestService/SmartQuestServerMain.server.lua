--!strict
-- SmartQuestServerMain
-- Boot script for SmartQuestService.

local SmartQuestService = require(script.Parent:WaitForChild("SmartQuestService"))

-- Optional integration examples:
-- SmartQuestService:SetRewardHandler(function(player, rewards, quest, state)
-- 	-- Connect to CurrencyService, InventoryService, XPService, BadgeService, etc.
-- end)
--
-- SmartQuestService:SetPrerequisiteHandler("HasItem", function(player, itemId, quest)
-- 	-- return InventoryService:HasItem(player, itemId), "You need " .. itemId
-- end)
--
-- SmartQuestService:SetConditionHandler("HasItem", function(player, itemId, quest, step)
-- 	-- return InventoryService:HasItem(player, itemId), "You need " .. itemId
-- end)

SmartQuestService:Init()

print("[SmartQuestService] v2 initialized.")
