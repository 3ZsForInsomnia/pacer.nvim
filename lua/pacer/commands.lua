local v = vim
local a = v.api
local n = v.notify
local l = v.log

local M = {}
local pacer = require("pacer.core")
local state = require("pacer.state")

function M.start_pacer(args)
	local options = {}

	if args.args and args.args ~= "" then
		local speed = tonumber(args.args)

		if speed then
			options.speed = speed
		else
			options.preset = args.args
		end
	end

	state.save_position()

	options.start_from_cursor = true

	pacer.restart(options)
end

function M.stop_pacer()
	-- Save position
	state.save_position()

	-- Stop pacer
	pacer.stop()
end

function M.resume_pacer()
	-- Check if we have a valid last position
	if not state.last_position.bufnr then
		n("Pacer: No previous position to resume from", l.levels.WARN)
		return
	end

	-- Check if buffer still exists
	local valid_buf = a.nvim_buf_is_valid(state.last_position.bufnr)
	if not valid_buf then
		n("Pacer: Previous buffer no longer exists", l.levels.WARN)
		return
	end

	-- Set cursor to last position
	a.nvim_set_current_buf(state.last_position.bufnr)
	a.nvim_win_set_cursor(0, { state.last_position.line + 1, state.last_position.col }) -- Convert back to 1-indexed

	-- Resume the pacer
	pacer.resume()
end

function M.setup()
	a.nvim_create_user_command("PacerStart", function(args)
		M.start_pacer(args)
	end, { nargs = "?", desc = "Start the pacer (optional: specify speed or preset)" })

	a.nvim_create_user_command("PacerStop", function()
		M.stop_pacer()
	end, { desc = "Stop the pacer" })

	a.nvim_create_user_command("PacerResume", function()
		M.resume_pacer()
	end, { desc = "Resume the pacer from last position" })
end

return M
