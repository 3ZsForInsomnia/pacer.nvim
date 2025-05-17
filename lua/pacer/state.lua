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

M.config = {
	speed = 250,
	highlight = {
		bg = "#335577",
		fg = "#ffffff",
		bold = true,
	},
	move_cursor = false,
	stop_key = "<C-c>",
	focus = {
		enabled = false,
		dim_color = "#777777",
		dim_style = "italic",
	},
}

function M.apply_config(config)
	-- Deep merge the configs
	M.config = vim.tbl_deep_extend("force", M.config, config or {})

	-- Apply any side effects of config changes
	if M.config.highlight then
		require("pacer.highlight").refresh_highlight(M.config)
	end
end

function M.adjust_speed(change)
	M.config.speed = math.max(10, M.config.speed + change)

	-- If timer is active, restart it with new speed
	if M.timer then
		local Timer = require("pacer.timer")
		Timer.stop(M.timer)
		M.timer = Timer.start(function()
			require("pacer.core").step()
		end, M.config.speed)
	end

	vim.notify("Pacer speed: " .. M.config.speed .. "ms", vim.log.levels.INFO)
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
