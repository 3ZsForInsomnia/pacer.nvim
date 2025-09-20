local v = vim
local state = require("pacer.state")

local log = require("pacer.log")

local M = {}

local last_notification_time = 0
local last_milestone_percent = -1

local function get_milestones(total_words)
	if total_words < 500 then
		-- Small texts: 25%, 50%, 75%
		return { 25, 50, 75 }
	elseif total_words < 2000 then
		-- Medium texts: 20%, 40%, 60%, 80%
		return { 20, 40, 60, 80 }
	elseif total_words < 5000 then
		-- Larger texts: 10%, 20%, 30%, ..., 90%
		return { 10, 20, 30, 40, 50, 60, 70, 80, 90 }
	else
		-- Very large texts: 5%, 10%, 15%, ..., 95%
		local milestones = {}
		for i = 5, 95, 5 do
			table.insert(milestones, i)
		end
		return milestones
	end
end

local function is_at_milestone(percent, total_words)
	local milestones = get_milestones(total_words)
	for _, milestone in ipairs(milestones) do
		if percent >= milestone and last_milestone_percent < milestone then
			last_milestone_percent = milestone
			return true
		end
	end
	return false
end

function M.update_progress()
	if not state.active or not state.words or #state.words == 0 then
		return
	end

	local ok, err = pcall(function()
	local total_words = #state.words
	local current_pos = state.cur_word or 1
	local percent_done = math.floor((current_pos / total_words) * 100)

	local words_remaining = total_words - current_pos
	local minutes_remaining = math.ceil((words_remaining / state.config.wpm))
	local time_text = minutes_remaining <= 1 and "< 1 minute" or minutes_remaining .. " minutes"

	local now = v.loop.now()
	local time_since_last = now - last_notification_time

	-- Show notifications:
	-- 1. At the beginning (first few words)
	-- 2. At adaptive milestones based on text size
	-- 3. Near the end (last 5%)
	-- 4. Maximum once every 60 seconds
	local should_notify = (time_since_last > 60000) -- At least 60 seconds between notifications
		or (current_pos < 10 and time_since_last > 10000) -- More frequent at start
		or (percent_done >= 95 and time_since_last > 20000) -- More frequent near end
		or is_at_milestone(percent_done, total_words) -- Dynamic milestones

	if should_notify then
		last_notification_time = now

			local short_message = string.format("%d%% (%s left)", percent_done, time_text)
			local long_message = string.format("Pacer: %d%% complete (%s remaining) - word %d of %d at %d WPM", 
				percent_done, time_text, current_pos, total_words, state.config.wpm)
			
			v.api.nvim_echo({{short_message, "Normal"}}, false, {})
			log.info(string.format("%d%% complete (%s remaining) - word %d of %d at %d WPM", 
				percent_done, time_text, current_pos, total_words, state.config.wpm))
	end
	end)
	
	if not ok then
		log.error("Error updating progress: " .. tostring(err))
	end
end

function M.clear_progress()
	log.info("Clearing progress tracking")
	last_notification_time = 0
	last_milestone_percent = -1
end

return M
