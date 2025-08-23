local M = {}

-- Store original functions we'll mock
local original = {
	timer_new = vim.loop.new_timer,
	timer_start = nil, -- Will be captured during setup
	notify = vim.notify,
	schedule_wrap = vim.schedule_wrap,
	now = vim.loop.now,
}

-- Collection of active mock timers
M.mock_timers = {}
-- Current mock time (milliseconds)
M.current_time = 0
-- Collection of captured notifications
M.notifications = {}

-- Create a clean test buffer with content
function M.create_test_buffer(content)
	content = content
		or {
			"This is a test paragraph with several words.",
			"",
			"This is a second paragraph for testing.",
			"It continues here with more text.",
			"",
			"A third paragraph exists here.",
		}

	vim.cmd("enew")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
	return vim.api.nvim_get_current_buf()
end

-- Setup test environment and mocks
function M.setup()
	-- Clear package cache to ensure clean state
	for k in pairs(package.loaded) do
		if k:match("^pacer%.") then
			package.loaded[k] = nil
		end
	end

	-- Reset state
	M.current_time = 0
	M.mock_timers = {}
	M.notifications = {}

	-- Setup buffer
	vim.cmd("bufdo! bwipeout!")
	vim.cmd("set noswapfile")
	vim.cmd("set hidden")

	-- Mock vim.notify to capture notifications
	vim.notify = function(msg, level, opts)
		table.insert(M.notifications, {
			message = msg,
			level = level or vim.log.levels.INFO,
			opts = opts or {},
		})
	end

	-- Mock timer.start from our timer module
	local timer_module = require("pacer.timer")
	original.timer_start = timer_module.start

	-- Mock timer.start to use our controlled timers
	timer_module.start = function(callback, delay_ms)
		local mock_timer = {
			id = #M.mock_timers + 1,
			callback = callback,
			delay = delay_ms,
			created_at = M.current_time,
			is_active = true,

			-- Stop this timer
			stop = function(self)
				self.is_active = false
			end,

			-- Check if timer is closing
			is_closing = function(self)
				return not self.is_active
			end,

			-- Close the timer
			close = function(self)
				self.is_active = false
			end,
		}

		table.insert(M.mock_timers, mock_timer)
		return mock_timer
	end

	-- Mock vim.loop.now() to control time
	vim.loop.now = function()
		return M.current_time
	end

	-- Mock vim.schedule_wrap to execute immediately in tests
	vim.schedule_wrap = function(fn)
		return function(...)
			fn(...)
		end
	end

	-- Setup plugin with default config or apply custom config here
	return require("pacer.init").setup()
end

-- Clean up after tests
function M.teardown()
	-- Restore original functions
	vim.notify = original.notify
	vim.schedule_wrap = original.schedule_wrap
	vim.loop.now = original.now

	-- Restore timer module functions
	if original.timer_start then
		require("pacer.timer").start = original.timer_start
	end

	-- Stop any running pacers
	pcall(function()
		require("pacer.core").stop()
	end)

	-- Clean up buffers
	vim.cmd("bufdo! bwipeout!")
end

-- Execute the next timer due to fire
function M.step_timer()
	if #M.mock_timers == 0 then
		return false
	end

	-- Sort timers by when they would fire
	table.sort(M.mock_timers, function(a, b)
		return (a.created_at + a.delay) < (b.created_at + b.delay)
	end)

	-- Get next timer
	local next_timer = nil
	for _, timer in ipairs(M.mock_timers) do
		if timer.is_active then
			next_timer = timer
			break
		end
	end

	if not next_timer then
		return false
	end

	-- Advance time to when this timer would fire
	local fire_time = next_timer.created_at + next_timer.delay
	M.current_time = fire_time

	-- Execute the timer callback
	local callback = next_timer.callback
	next_timer.is_active = false

	-- Remove from active timers
	for i, timer in ipairs(M.mock_timers) do
		if timer.id == next_timer.id then
			table.remove(M.mock_timers, i)
			break
		end
	end

	-- Execute the callback
	callback()
	return true
end

-- Step forward multiple timer ticks
function M.step_timers(count)
	count = count or 1
	local steps_taken = 0

	for _ = 1, count do
		if not M.step_timer() then
			break
		end
		steps_taken = steps_taken + 1
	end

	return steps_taken
end

-- Advance time without stepping timers
function M.advance_time(ms)
	M.current_time = M.current_time + ms
end

-- Get current plugin state (for assertions)
function M.get_plugin_state()
	return require("pacer.state")
end

-- Reset plugin state to defaults
function M.reset_plugin_state()
	local state = require("pacer.state")

	-- Reset all state variables
	state.active = false
	state.paused = false
	state.timer = nil
	state.bufnr = nil
	state.ns = nil
	state.cur_word = nil
	state.words = nil
	state.last_word_idx = nil
	state.keymap_active = false

	state.current_position = {
		line = 0,
		col = 0,
		bufnr = nil,
	}

	state.last_position = {
		bufnr = nil,
		line = 0,
		col = 0,
	}

	-- Reset to default config
	state.config = require("pacer.config").defaults
end

-- Start the pacer with custom options
function M.start_pacer(options)
	options = options or {}

	-- If a WPM value is directly passed
	if type(options) == "number" then
		options = { wpm = options }
	end

	-- Execute the start command
	if options.preset then
		vim.cmd("PacerStart " .. options.preset)
	elseif options.wpm then
		vim.cmd("PacerStart " .. options.wpm)
	else
		vim.cmd("PacerStart")
	end

	-- Apply any additional config if needed
	if options.config then
		local state = require("pacer.state")
		state.apply_config(options.config)
	end
end

-- Get current highlight state
function M.get_current_highlight()
	local state = require("pacer.state")
	if not state.active or not state.bufnr or not state.ns then
		return nil
	end

	local bufnr = state.bufnr
	local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, state.ns, { 0, 0 }, { -1, -1 }, { details = true })

	if #extmarks == 0 then
		return nil
	end

	local mark = extmarks[1]
	return {
		line = mark[2],
		col_start = mark[3],
		col_end = mark[4].end_col,
		hl_group = mark[4].hl_group,
	}
end

-- Get cursor position (1-indexed for line, 0-indexed for column)
function M.get_cursor()
	return vim.api.nvim_win_get_cursor(0)
end

-- Get last notification of a specific type
function M.get_last_notification(pattern)
	for i = #M.notifications, 1, -1 do
		if M.notifications[i].message:match(pattern) then
			return M.notifications[i]
		end
	end
	return nil
end

-- Simulate a keypress
function M.send_keys(keys)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", true)
end

return M
