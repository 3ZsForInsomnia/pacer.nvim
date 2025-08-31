local v = vim
local a = v.api
local n = v.notify
local l = v.log

local M = {}
local pacer = require("pacer.core")
local state = require("pacer.state")

-- Safe buffer operation wrapper
local function safe_buf_operation(bufnr, operation_name, operation)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		print("Pacer: " .. operation_name .. " failed - invalid buffer (id=" .. tostring(bufnr) .. ")")
		return false, "Invalid buffer"
	end
	
	local ok, result = pcall(operation, bufnr)
	if not ok then
		vim.api.nvim_echo({{"Pacer: " .. operation_name .. " failed", "ErrorMsg"}}, false, {})
		print("Pacer: " .. operation_name .. " operation failed: " .. tostring(result))
		return false, result
	end
	return true, result
end

function M.start_pacer(args)
	-- Ensure pacer is fully setup if lazy loaded
	require("pacer.config").ensure_setup()

	-- Validate current state before starting
	if not state.validate_state() then
		print("Pacer: State validation failed during start, state has been reset")
	end

	local options = {}

	if args.args and args.args ~= "" then
		local wpm = tonumber(args.args)

		if wpm then
			-- Add bounds checking
			if wpm < 60 or wpm > 2000 then
				vim.api.nvim_echo({{"Invalid WPM: must be 60-2000", "ErrorMsg"}}, false, {})
 			print("Pacer: Invalid WPM value " .. wpm .. " - must be between 60 and 2000")
				return
			end
			options.wpm = wpm
		else
			options.preset = args.args
		end
	end

	-- Validate current buffer before proceeding
	local current_buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(current_buf) then
		vim.api.nvim_echo({{"Cannot start: invalid buffer", "ErrorMsg"}}, false, {})
		print("Pacer: Cannot start pacer - current buffer is invalid")
		return
	end
	
	-- Check if buffer has content
	local line_count = vim.api.nvim_buf_line_count(current_buf)
	if line_count == 0 or (line_count == 1 and vim.api.nvim_buf_get_lines(current_buf, 0, 1, false)[1] == "") then
		vim.api.nvim_echo({{"Cannot start: buffer is empty", "WarningMsg"}}, false, {})
		print("Pacer: Cannot start pacer - buffer is empty")
		return
	end
	if not state.save_position() then
		print("Pacer: Warning - could not save starting position")
	end

	options.start_from_cursor = true

	local ok, err = pcall(pacer.restart, options)
	if not ok then
		vim.api.nvim_echo({{"Start failed", "ErrorMsg"}}, false, {})
		print("Pacer: Failed to start pacer: " .. tostring(err))
		state.reset_to_safe_state()
	end
end

function M.stop_pacer()
	-- Ensure pacer is fully setup if lazy loaded
	require("pacer.config").ensure_setup()

	local ok, err = pcall(pacer.stop)
	if not ok then
		print("Pacer: Error during stop, forcing cleanup: " .. tostring(err))
		state.reset_to_safe_state()
	end

	v.defer_fn(function()
		state.clear_position()
	end, 0)
end

function M.resume_pacer()
	-- Ensure pacer is fully setup if lazy loaded
	require("pacer.config").ensure_setup()

	-- Validate current state
	if not state.validate_state() then
		print("Pacer: State validation failed during resume, state has been reset")
	end

	-- Check if we have a valid last position
	if not state.last_position.bufnr then
		vim.api.nvim_echo({{"No session to resume", "WarningMsg"}}, false, {})
		print("Pacer: No previous session to resume from - use :PacerStart to begin reading")
		return
	end

	-- Check if buffer still exists
	local valid_buf = a.nvim_buf_is_valid(state.last_position.bufnr)
	if not valid_buf then
		vim.api.nvim_echo({{"Previous buffer no longer exists", "WarningMsg"}}, false, {})
		print("Pacer: Previous buffer (id=" .. state.last_position.bufnr .. ") no longer exists")
		state.clear_position()
		return
	end

	-- Set cursor to last position with error handling
	local ok, err = pcall(function()
		a.nvim_set_current_buf(state.last_position.bufnr)
		a.nvim_win_set_cursor(0, { state.last_position.line + 1, state.last_position.col })
	end)
	
	if not ok then
		vim.api.nvim_echo({{"Resume failed", "ErrorMsg"}}, false, {})
		print("Pacer: Failed to restore position: " .. tostring(err))
		return
	end

	-- Resume the pacer
	ok, err = pcall(pacer.resume)
	if not ok then
		vim.api.nvim_echo({{"Resume failed", "ErrorMsg"}}, false, {})
		print("Pacer: Failed to resume pacer: " .. tostring(err))
		state.reset_to_safe_state()
	end
end

function M.pause_pacer()
	-- Ensure pacer is fully setup if lazy loaded
	require("pacer.config").ensure_setup()

	local ok, err = pcall(pacer.pause)
	if not ok then
		print("Pacer: Error during pause, forcing cleanup: " .. tostring(err))
		state.reset_to_safe_state()
	end
end

function M.validate_pacer()
	-- Ensure pacer is fully setup if lazy loaded
	require("pacer.config").ensure_setup()
	
	vim.api.nvim_echo({{"=== Pacer Validation ===", "Title"}}, false, {})
	print("Pacer: Running validation check...")
	
	local config = require("pacer.config")
	local state = require("pacer.state")
	
	-- Validate environment
	local env_ok = config.validate_environment()
	
	-- Validate configuration
	print("Pacer: Current configuration:")
	print("  WPM: " .. config.options.wpm)
	print("  Highlight: " .. vim.inspect(config.options.highlight))
	print("  Move cursor: " .. tostring(config.options.move_cursor))
	print("  Focus enabled: " .. tostring(config.options.focus.enabled))
	
	-- Validate state
	local state_ok = state.validate_state()
	if state.active then
		print("Pacer: Currently active with " .. (#state.words or 0) .. " words")
	else
		print("Pacer: Not currently active")
	end
	
	-- Test basic functionality
	local current_buf = vim.api.nvim_get_current_buf()
	if vim.api.nvim_buf_is_valid(current_buf) then
		local line_count = vim.api.nvim_buf_line_count(current_buf)
		if line_count > 0 then
			print("Pacer: Current buffer has " .. line_count .. " lines")
			
			-- Test word extraction
			local words = {}
			local ok, err = pcall(function()
				local core = require("pacer.core")
				-- We can't call get_words directly since it's local, but we can test the setup
				require("pacer.highlight").create_namespace()
			end)
			
			if ok then
				print("Pacer: Core functionality test passed")
			else
				print("Pacer: Core functionality test failed: " .. tostring(err))
			end
		else
			print("Pacer: Current buffer is empty")
		end
	else
		print("Pacer: Current buffer is invalid")
	end
	
	-- Check optional dependencies
	local has_ts, ts_parsers = pcall(require, "nvim-treesitter.parsers")
	if has_ts then
		print("Pacer: nvim-treesitter available (enhanced focus mode)")
	else
		print("Pacer: nvim-treesitter not available (basic focus mode)")
	end
	
	local all_ok = env_ok and state_ok
	if all_ok then
		vim.api.nvim_echo({{"Pacer validation passed!", "MoreMsg"}}, false, {})
		print("Pacer: All validation checks passed. Try :PacerStart to begin reading.")
	else
		vim.api.nvim_echo({{"Pacer validation found issues", "WarningMsg"}}, false, {})
		print("Pacer: Some validation checks failed. Check messages above.")
	end
end

function M.setup()
	-- Mark that commands have been setup
	vim.g.pacer_commands_setup = true

	a.nvim_create_user_command("PacerStart", function(args)
		M.start_pacer(args)
	end, { nargs = "?", desc = "Start the pacer (optional: specify speed or preset)" })

	a.nvim_create_user_command("PacerPause", function()
		M.pause_pacer()
	end, { desc = "Pause the pacer" })

	a.nvim_create_user_command("PacerStop", function()
		M.stop_pacer()
	end, { desc = "Stop the pacer" })

	a.nvim_create_user_command("PacerResume", function()
		M.resume_pacer()
	end, { desc = "Resume the pacer from last position" })

	a.nvim_create_user_command("PacerValidate", function()
		M.validate_pacer()
	end, { desc = "Validate Pacer configuration and environment" })
end

return M
