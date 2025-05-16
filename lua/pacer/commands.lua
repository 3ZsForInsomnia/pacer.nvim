local v = vim
local a = v.api
local n = v.notify
local l = v.log

local M = {}
local pacer = require("pacer.core")

-- Store last position when stopping/pausing
local last_position = {
	bufnr = nil,
	line = 0,
	col = 0,
}

function M.start_pacer(args)
	local config = require("pacer.config")
	local options = {}

	if args.args and args.args ~= "" then
		local speed = tonumber(args.args)

		if speed then
			options.speed = speed
		else
			local preset_config = config.get_preset_config(args.args)
			options = preset_config
		end
	end

	-- Save current position to restore it when pacer is stopped
	local bufnr = a.nvim_get_current_buf()
	local cursor = a.nvim_win_get_cursor(0)
	last_position = {
		bufnr = bufnr,
		line = cursor[1] - 1, -- Convert to 0-indexed
		col = cursor[2],
	}

	pacer.restart(options)
end

function M.stop_pacer()
	-- Save current position before stopping
	local bufnr = a.nvim_get_current_buf()
	local cursor = a.nvim_win_get_cursor(0)
	last_position = {
		bufnr = bufnr,
		line = cursor[1] - 1, -- Convert to 0-indexed
		col = cursor[2],
	}

	pacer.stop()
end

function M.resume_pacer()
	-- Check if we have a valid last position
	if not last_position.bufnr then
		n("Pacer: No previous position to resume from", l.levels.WARN)
		return
	end

	-- Check if buffer still exists
	local valid_buf = a.nvim_buf_is_valid(last_position.bufnr)
	if not valid_buf then
		n("Pacer: Previous buffer no longer exists", l.levels.WARN)
		return
	end

	-- Set cursor to last position
	a.nvim_set_current_buf(last_position.bufnr)
	a.nvim_win_set_cursor(0, { last_position.line + 1, last_position.col }) -- Convert back to 1-indexed

	-- Start the pacer
	pacer.start()
end

function M.setup()
	a.nvim_create_user_command("PacerStart", function(args)
		M.start_pacer(args)
	end, { nargs = "?", desc = "Start the pacer (optional: specify speed)" })

	a.nvim_create_user_command("PacerStop", function()
		M.stop_pacer()
	end, { desc = "Stop the pacer" })

	a.nvim_create_user_command("PacerResume", function()
		M.resume_pacer()
	end, { desc = "Resume the pacer from last position" })
end

return M
