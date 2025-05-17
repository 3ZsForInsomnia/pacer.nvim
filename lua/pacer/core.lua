local Timer = require("pacer.timer")
local H = require("pacer.highlight")
local state = require("pacer.state")

local function clear()
	if state.ns and state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		-- Clear all highlights
		vim.api.nvim_buf_clear_namespace(state.bufnr, state.ns, 0, -1)
	end
end

local M = {}

-- Stop the pacer
function M.stop()
	if state.timer then
		Timer.stop(state.timer)
		state.timer = nil
	end
	clear()

	-- Explicitly clear focus highlights
	if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		require("pacer.focus").clear_highlights(state.bufnr)
	end

	M.remove_keymap()
	state.active = false
	state.paused = false
end

-- Step function to move through words
function M.step()
	if state.cur_word > #state.words then
		clear()
		Timer.stop(state.timer)
		state.timer = nil
		M.remove_keymap()

		if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
			require("pacer.focus").clear_highlights(state.bufnr)
		end

		state.active = false
		return
	end

	clear()

	local w = state.words[state.cur_word]
	if w then
		H.highlight_word(state.bufnr, state.ns, w.lnum, w.col, w.len)

		state.current_position = {
			line = w.lnum,
			col = w.col,
			bufnr = state.bufnr,
		}

		if state.config.move_cursor then
			vim.api.nvim_win_set_cursor(0, { w.lnum + 1, w.col })
		end

		if state.config.focus and state.config.focus.enabled then
			local focus = require("pacer.focus")
			focus.apply_focus(state.config)
		end

		state.last_word_idx = state.cur_word
		state.cur_word = state.cur_word + 1
	end
end

-- Add keybinding
function M.add_keymap()
	if not state.keymap_active then
		vim.keymap.set("n", state.config.stop_key, function()
			vim.notify("Pacer stopped", "info")
			M.pause()
			M.remove_keymap()
		end, { noremap = true, silent = true, desc = "Stop pacer" })

		-- Add speed controls
		vim.keymap.set("n", "<C-.>", function()
			state.adjust_speed(10) -- Increase speed (lower delay)
		end, { noremap = true, silent = true, desc = "Increase pacer speed" })

		vim.keymap.set("n", "<C-,>", function()
			state.adjust_speed(-10) -- Decrease speed (higher delay)
		end, { noremap = true, silent = true, desc = "Decrease pacer speed" })

		state.keymap_active = true
	end
end

function M.remove_keymap()
	if state.keymap_active then
		vim.keymap.del("n", state.config.stop_key)
		vim.keymap.del("n", "<C-.>")
		vim.keymap.del("n", "<C-,>")
		state.keymap_active = false
	end
end

-- Get words from buffer
local function get_words(bufnr)
	local words = {}
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for lnum, line in ipairs(lines) do
		local real_lnum = lnum - 1 -- Convert to 0-indexed

		-- Find words and their positions
		for pos, word in line:gmatch("()(%w+)") do
			table.insert(words, {
				text = word,
				lnum = real_lnum,
				col = pos - 1, -- Convert to 0-indexed
				len = #word,
			})
		end
	end

	return words
end

-- Restart pacer with options
function M.restart(options)
	options = options or {}

	-- Apply config from options
	if options.preset then
		-- Get preset configuration
		local config_module = require("pacer.config")
		local preset_config = config_module.get_preset_config(options.preset)
		state.apply_config(preset_config)
	else
		-- Apply direct options
		state.apply_config(options)
	end

	-- Setup pacer state
	state.bufnr = vim.api.nvim_get_current_buf()
	state.ns = H.create_namespace()
	state.words = get_words(state.bufnr)

	local start_word = 1
	if options.start_from_cursor and not options.from_word then
		local cursor = vim.api.nvim_win_get_cursor(0)
		local cursor_line = cursor[1] - 1
		local cursor_col = cursor[2]

		for i, word in ipairs(state.words) do
			if word.lnum > cursor_line or (word.lnum == cursor_line and word.col >= cursor_col) then
				start_word = i
				break
			end

			if i == #state.words then
				start_word = i
			end
		end
	end

	state.cur_word = options.from_word or start_word
	state.active = true
	state.paused = false

	clear()

	if state.timer then
		Timer.stop(state.timer)
	end

	state.timer = Timer.start(function()
		M.step()
	end, state.config.speed)

	M.add_keymap()
end

function M.pause()
	if state.timer then
		Timer.stop(state.timer)
	end

	clear()

	-- Explicitly clear focus highlights
	if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		require("pacer.focus").clear_highlights(state.bufnr)
	end

	state.paused = true
	M.remove_keymap()
end

function M.resume()
	if state.paused and state.last_word_idx then
		M.restart({ from_word = state.last_word_idx })
	else
		M.restart()
	end
end

-- Export the module
local module = {
	restart = M.restart,
	pause = M.pause,
	resume = M.resume,
	stop = M.stop,
	step = M.step,
	add_keymap = M.add_keymap,
	remove_keymap = M.remove_keymap,
}

return module
