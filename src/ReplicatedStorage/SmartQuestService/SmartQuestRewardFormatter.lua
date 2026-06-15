--!strict
-- SmartQuestRewardFormatter
-- Converts generic reward tables into readable UI lines.

local RewardFormatter = {}

local function addLine(lines, text)
	if text and text ~= "" then
		table.insert(lines, text)
	end
end

function RewardFormatter.Format(rewards): {string}
	local lines = {}

	if type(rewards) ~= "table" then
		return lines
	end

	if type(rewards.Currency) == "table" then
		for currencyName, amount in pairs(rewards.Currency) do
			addLine(lines, `+{amount} {currencyName}`)
		end
	end

	if type(rewards.Items) == "table" then
		for itemId, amount in pairs(rewards.Items) do
			if type(itemId) == "number" then
				addLine(lines, `+1 {tostring(amount)}`)
			else
				addLine(lines, `+{amount} {itemId}`)
			end
		end
	end

	if type(rewards.Stats) == "table" then
		for statName, amount in pairs(rewards.Stats) do
			addLine(lines, `+{amount} {statName}`)
		end
	end

	if type(rewards.XP) == "number" then
		addLine(lines, `+{rewards.XP} XP`)
	end

	if type(rewards.Badges) == "table" then
		for _, badgeName in ipairs(rewards.Badges) do
			addLine(lines, `Badge: {badgeName}`)
		end
	end

	return lines
end

function RewardFormatter.ToText(rewards): string
	local lines = RewardFormatter.Format(rewards)
	if #lines == 0 then
		return ""
	end
	return table.concat(lines, "\n")
end

return RewardFormatter
