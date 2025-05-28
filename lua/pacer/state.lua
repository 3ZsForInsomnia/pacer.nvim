local defaultConfig = require("pacer.config").defaults

local M = {}

M.active = false
M.paused = false
M.timer = nil
M.bufnr = nil
M.ns = nil
M.cur_word = nil
M.words = nil
M.last_word_idx = nil
M.keymap_active = false

M.last_position = {
	bufnr = nil,
	line = 0,
	col = 0,
}

M.current_position = {
	line = 0,
	col = 0,
	bufnr = nil,
}

M.config = defaultConfig

function M.apply_config(config)
	-- Deep merge the configs
	M.config = vim.tbl_deep_extend("force", M.config, config or {})

	-- Apply any side effects of config changes
	if M.config.highlight then
		require("pacer.highlight").refresh_highlight(M.config)
	end
end

function M.adjust_wpm(change)
	local old_wpm = M.config.wpm
	M.config.wpm = math.max(60, M.config.wpm + change) -- Min 60 WPM (1 word per second)

	-- Convert WPM to milliseconds per word
	local ms_per_word = math.floor(60000 / M.config.wpm)

	-- If timer is active, restart it with new speed
	if M.timer then
		local Timer = require("pacer.timer")
		Timer.stop(M.timer)
		M.timer = Timer.start(function()
			require("pacer.core").step()
		end, ms_per_word)
	end

	vim.notify("Pacer speed: " .. M.config.wpm .. " WPM (was " .. old_wpm .. " WPM)", vim.log.levels.INFO)
end

function M.save_position()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	M.last_position = {
		bufnr = bufnr,
		line = cursor[1] - 1, -- Convert to 0-indexed
		col = cursor[2],
	}
end

return M
