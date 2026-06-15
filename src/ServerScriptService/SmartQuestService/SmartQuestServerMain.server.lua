--!strict
-- SmartQuestServerMain
-- Simple boot script for SmartQuestService.

local SmartQuestService = require(script.Parent:WaitForChild("SmartQuestService"))

SmartQuestService:Init()

print("[SmartQuestService] SmartQuestService initialized.")
