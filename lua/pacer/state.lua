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

-- State validation and cleanup functions
function M.validate_state()
	-- Check for inconsistent timer state
	if M.active and not M.timer then
		vim.api.nvim_echo({{"Pacer: Warning - Active state without timer, resetting to safe state", "WarningMsg"}}, false, {})
		print("Pacer: State inconsistency detected - active=true but no timer. Resetting state.")
		M.reset_to_safe_state()
		return false
	end
	
	-- Check for invalid buffer
	if M.active and M.bufnr and not vim.api.nvim_buf_is_valid(M.bufnr) then
		vim.api.nvim_echo({{"Pacer: Warning - Active buffer no longer valid, stopping", "WarningMsg"}}, false, {})
		print("Pacer: Active buffer (id=" .. M.bufnr .. ") is no longer valid. Stopping pacer.")
		M.reset_to_safe_state()
		return false
	end
	
	return true
end

function M.reset_to_safe_state()
	print("Pacer: Resetting to safe state - cleaning up resources and state")
	
	-- Stop timer if it exists
	if M.timer then
		local Timer = require("pacer.timer")
		Timer.stop(M.timer)
		M.timer = nil
	end
	
	-- Clear highlights and namespaces
	if M.bufnr and vim.api.nvim_buf_is_valid(M.bufnr) then
		if M.ns then
			pcall(vim.api.nvim_buf_clear_namespace, M.bufnr, M.ns, 0, -1)
		end
		pcall(require("pacer.focus").clear_highlights, M.bufnr)
	end
	
	-- Clear progress
	pcall(require("pacer.progress").clear_progress)
	
	-- Reset state variables
	M.active = false
	M.paused = false
	M.bufnr = nil
	M.ns = nil
	M.cur_word = nil
	M.words = nil
	M.last_word_idx = nil
	
	-- Remove keymaps safely
	pcall(require("pacer.core").remove_keymap)
	M.keymap_active = false
end

function M.cleanup()
	print("Pacer: Full cleanup - clearing all resources and resetting state")
	M.reset_to_safe_state()
	
	-- Also clear saved positions
	M.current_position = {
		line = 0,
		col = 0,
		bufnr = nil,
	}
	
	M.last_position = {
		bufnr = nil,
		line = 0,
		col = 0,
	}
end

function M.apply_config(config)
	-- Deep merge the configs
	M.config = vim.tbl_deep_extend("force", M.config, config or {})

	-- Apply any side effects of config changes
	if M.config.highlight then
		require("pacer.highlight").refresh_highlight(M.config)
	end
end

function M.adjust_wpm(change)
	if not M.validate_state() then
		return
	end
	
	local old_wpm = M.config.wpm
	M.config.wpm = math.max(60, M.config.wpm + change) -- Min 60 WPM (1 word per second)

	-- Convert WPM to milliseconds per word
	local ms_per_word = math.floor(60000 / M.config.wpm)

	-- If timer is active, restart it with new speed
	if M.timer then
		local Timer = require("pacer.timer")
		Timer.stop(M.timer)
		M.timer = nil
		M.timer = Timer.start(function()
			require("pacer.core").step()
		end, ms_per_word)
	end

	vim.api.nvim_echo({{"Speed: " .. M.config.wpm .. " WPM", "Normal"}}, false, {})
	print("Pacer: Speed changed from " .. old_wpm .. " WPM to " .. M.config.wpm .. " WPM")
end

function M.save_position()
	if not vim.api.nvim_buf_is_valid(vim.api.nvim_get_current_buf()) then
		print("Pacer: Cannot save position - current buffer is invalid")
		return false
	end
	
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	M.last_position = {
		bufnr = bufnr,
		line = cursor[1] - 1, -- Convert to 0-indexed
		col = cursor[2],
	}
	print("Pacer: Position saved - buffer=" .. bufnr .. " line=" .. (cursor[1] - 1) .. " col=" .. cursor[2])
	return true
end

function M.clear_position()
	print("Pacer: Clearing saved positions")
	M.current_position = {
		bufnr = nil,
		line = 0,
		col = 0,
	}
	M.last_position = {
		bufnr = nil,
		line = 0,
		col = 0,
	}
end

return M
