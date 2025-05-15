local Timer = require("pacer.timer")
local H = require("pacer.highlight")

local state = {
	timer = nil,
	cur_word = nil,
	words = nil,
	bufnr = nil,
	ns = nil,
	paused = false,
	last_word_idx = nil,
	keymap_active = false, -- Track if our keymaps are active
	config = {
		move_cursor = false, -- Default to not moving cursor
		stop_key = "<C-c>", -- Default stop key
	},
}

local function clear()
	if state.ns and state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		-- Clear all highlights in the namespace
		vim.api.nvim_buf_clear_namespace(state.bufnr, state.ns, 0, -1)
	end
end

function state.stop()
	if state.timer then
		Timer.stop(state.timer)
		state.timer = nil
	end
	clear()
	state.remove_keymap()
end

-- Modify step function to conditionally move cursor
local function step()
	if state.cur_word > #state.words then
		clear()
		Timer.stop(state.timer)
		state.timer = nil
		state.remove_keymap() -- Remove keymap when finished
		return
	end
	clear()
	local w = state.words[state.cur_word]
	if w then
		H.highlight_word(state.bufnr, state.ns, w.lnum, w.col, w.len)

		-- Move cursor if configured to do so
		if state.config.move_cursor then
			vim.api.nvim_win_set_cursor(0, { w.lnum + 1, w.col })
		end

		state.last_word_idx = state.cur_word
		state.cur_word = state.cur_word + 1
	end
end

-- Add keybinding management functions
function state.add_keymap()
	if not state.keymap_active then
		vim.keymap.set("n", state.config.stop_key, function()
			vim.notify("Pacer stopped", "info")
			state.pause()
			state.remove_keymap()
		end, { noremap = true, silent = true, desc = "Stop pacer" })
		state.keymap_active = true
	end
end

function state.remove_keymap()
	if state.keymap_active then
		vim.keymap.del("n", state.config.stop_key)
		state.keymap_active = false
	end
end

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

-- Update restart function to set keymap and accept configuration
function state.restart(options)
	options = options or {}

	local default_speed = options.speed or 250
	local speed = options.speed or default_speed

	state.bufnr = vim.api.nvim_get_current_buf()
	state.ns = H.create_namespace()
	state.words = get_words(state.bufnr)
	state.cur_word = options.from_word or 1

	clear()

	if state.timer then
		Timer.stop(state.timer)
	end
	state.timer = Timer.start(function()
		step()
	end, speed)
	state.paused = false

	-- Add stop keymap when pacer starts
	state.add_keymap()
end

-- Update pause function to remove keymap
function state.pause()
	if state.timer then
		Timer.stop(state.timer)
	end
	state.paused = true
	state.remove_keymap()
end

-- Add configuration function
function state.configure(user_config)
	user_config = user_config or {}
	state.config.move_cursor = user_config.move_cursor or state.config.move_cursor
	state.config.stop_key = user_config.stop_key or state.config.stop_key
end

-- Update setup function to accept configuration
function state.setup(config)
	state.configure(config)

	-- User commands
	vim.api.nvim_create_user_command("PacerStart", function(opts)
		state.restart({ speed = tonumber(opts.args) or default_speed })
	end, { nargs = "?", desc = "Start pacer (optional speed in ms)" })

	vim.api.nvim_create_user_command("PacerPause", function()
		state.pause()
	end, {})
	vim.api.nvim_create_user_command("PacerResume", function()
		state.resume()
	end, {})
	vim.api.nvim_create_user_command("PacerResumeCursor", function()
		state.resume_from_cursor()
	end, {})

	-- React to insert, change, etc (auto-pause)
	vim.api.nvim_create_autocmd({ "InsertEnter", "TextChanged", "TextChangedI" }, {
		callback = function()
			state.pause()
		end,
	})

	-- Optional: autocmd BufLeave, etc
end

function state.resume()
	if state.paused and state.last_word_idx then
		state.restart({ from_word = state.last_word_idx })
	else
		state.restart()
	end
end

return state
