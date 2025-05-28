local v = vim

local Timer = require("pacer.timer")
local H = require("pacer.highlight")
local state = require("pacer.state")
local progress = require("pacer.progress")
local M = {}

function M.check_scroll_position()
	if not state.active or not state.bufnr then
		return
	end

	local current_line = state.current_position.line
	if not current_line then
		return
	end

	local win = v.api.nvim_get_current_win()
	local win_info = v.fn.getwininfo(win)[1]

	-- Calculate visible region
	local top_line = win_info.topline - 1 -- Convert to 0-indexed
	local bottom_line = win_info.botline - 1 -- Convert to 0-indexed
	local visible_lines = bottom_line - top_line

	local bottom_quarter_line = top_line + math.floor(visible_lines * 0.75)

	if current_line > bottom_quarter_line then
		local target_topline = current_line - math.floor(visible_lines * 0.25)

		v.fn.winrestview({ topline = target_topline + 1 }) -- Convert back to 1-indexed
	end
end

local function get_words(bufnr)
	local words = {}
	local lines = v.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	for lnum, line in ipairs(lines) do
		if line:match("%S") then
			local word_start = 1
			while word_start <= #line do
				local start_pos, end_pos = line:find("%S+", word_start)
				if not start_pos then
					break
				end

				local word = line:sub(start_pos, end_pos)
				table.insert(words, {
					word = word,
					lnum = lnum - 1, -- Convert to 0-indexed
					col = start_pos - 1, -- Convert to 0-indexed
					len = end_pos - start_pos + 1,
				})

				word_start = end_pos + 1
			end
		end
	end

	return words
end

local function is_paragraph_boundary(word_idx, words)
	-- If we're at the last word or out of range
	if word_idx >= #words then
		return false
	end

	local current = words[word_idx]
	local next_word = words[word_idx + 1]

	-- If next word is on a line with a gap, current word is paragraph end
	if next_word.lnum > current.lnum + 1 then
		return true
	end

	-- If next word is on a different line, check for code structure changes
	if next_word.lnum > current.lnum then
		local current_line = v.api.nvim_buf_get_lines(state.bufnr, current.lnum, current.lnum + 1, false)[1] or ""
		local next_line = v.api.nvim_buf_get_lines(state.bufnr, next_word.lnum, next_word.lnum + 1, false)[1] or ""

		-- Get indentation levels
		local current_indent = current_line:match("^%s*"):len()
		local next_indent = next_line:match("^%s*"):len()

		-- Top-level definitions or significant scope changes
		if
			next_indent == 0
			and (
				next_line:match("^function%s+")
				or next_line:match("^class%s+")
				or next_line:match("^local%s+function")
				or next_line:match("^def%s+")
				or next_line:match("^import%s+")
				or next_line:match("^export%s+")
				or next_line:match("^module%s+")
				or next_line:match("^#") -- Comments
			)
		then
			return true
		end

		-- Significant indentation decreases
		if current_indent > 0 and next_indent < current_indent and (current_indent - next_indent) >= 4 then
			return true
		end

		-- Empty line plus indentation change
		if current_line:match("^%s*$") and math.abs(current_indent - next_indent) >= 4 then
			return true
		end
	end

	return false
end

function M.find_paragraph_boundary(direction)
	if not state.active or not state.bufnr then
		return nil
	end

	local current_line = state.current_position.line or v.api.nvim_win_get_cursor(0)[1] - 1
	local lines = v.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
	local line_count = #lines

	local function is_blank(idx)
		if idx < 0 or idx >= line_count then
			return true
		end
		return lines[idx + 1]:match("^%s*$")
	end

	local target_line = current_line

	if direction == "next" then
		while target_line < line_count and not is_blank(target_line) do
			target_line = target_line + 1
		end

		while target_line < line_count and is_blank(target_line) do
			target_line = target_line + 1
		end
	else
		while target_line > 0 and not is_blank(target_line - 1) do
			target_line = target_line - 1
		end

		if target_line == current_line then
			while target_line > 0 and is_blank(target_line - 1) do
				target_line = target_line - 1
			end

			while target_line > 0 and not is_blank(target_line - 1) do
				target_line = target_line - 1
			end
		end
	end

	target_line = math.max(0, math.min(target_line, line_count - 1))
	return target_line
end

function M.navigate_paragraph(direction)
	if not state.active then
		return
	end

	local target_line = M.find_paragraph_boundary(direction)
	if target_line == nil then
		return
	end

	local first_word_idx = nil
	for i, word in ipairs(state.words) do
		if word.lnum >= target_line then
			first_word_idx = i
			break
		end
	end

	if first_word_idx then
		state.cur_word = first_word_idx

		M.step()

		if state.timer then
			Timer.stop(state.timer)
			state.timer = Timer.start(function()
				M.step()
			end, state.config.wpm)
		end
	end
end

function M.add_keymap()
	if not state.keymap_active then
		v.keymap.set("n", state.config.pause_key, function()
			v.notify("Pacer stopped", v.log.levels.INFO)
			M.pause()
			M.remove_keymap()
		end, { noremap = true, silent = true, desc = "Stop pacer" })

		v.keymap.set("n", "<C-.>", function()
			state.adjust_wpm(10) -- Increase speed (lower delay)
		end, { noremap = true, silent = true, desc = "Increase pacer speed" })

		v.keymap.set("n", "<C-,>", function()
			state.adjust_wpm(-10) -- Decrease speed (higher delay)
		end, { noremap = true, silent = true, desc = "Decrease pacer speed" })

		v.keymap.set("n", "<C-n>", function()
			M.navigate_paragraph("next")
		end, { noremap = true, silent = true, desc = "Jump to next paragraph" })

		v.keymap.set("n", "<C-p>", function()
			M.navigate_paragraph("prev")
		end, { noremap = true, silent = true, desc = "Jump to previous paragraph" })

		state.keymap_active = true
	end
end

function M.remove_keymap()
	if state.keymap_active then
		v.keymap.del("n", state.config.pause_key)
		v.keymap.del("n", "<C-.>")
		v.keymap.del("n", "<C-,>")
		v.keymap.del("n", "<C-n>")
		v.keymap.del("n", "<C-p>")
		state.keymap_active = false
	end
end

local function clear()
	if state.ns and state.bufnr and v.api.nvim_buf_is_valid(state.bufnr) then
		v.api.nvim_buf_clear_namespace(state.bufnr, state.ns, 0, -1)
	end
end

-- Stop the pacer
function M.stop()
	if state.timer then
		Timer.stop(state.timer)
		state.timer = nil
	end

	clear()
	progress.clear_progress()

	if state.bufnr and v.api.nvim_buf_is_valid(state.bufnr) then
		require("pacer.focus").clear_highlights(state.bufnr)
	end

	M.remove_keymap()
	state.active = false
	state.paused = false
	state.wpm = state.config.wpm
end

function M.step()
	if state.cur_word > #state.words then
		-- End of file handling
		clear()
		Timer.stop(state.timer)
		state.timer = nil
		M.remove_keymap()
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
			v.api.nvim_win_set_cursor(0, { w.lnum + 1, w.col })
		end

		M.check_scroll_position()

		if state.config.focus and state.config.focus.enabled then
			local focus = require("pacer.focus")
			focus.apply_focus(state.config)
		end

		state.last_word_idx = state.cur_word
		state.cur_word = state.cur_word + 1

		-- Calculate base delay
		local ms_per_word = math.floor(60000 / state.config.wpm)
		local next_delay = ms_per_word

		-- Check if this is the last word of a paragraph
		if is_paragraph_boundary(state.last_word_idx, state.words) then
			next_delay = ms_per_word * state.config.paragraph_delay_multiplier
		end

		progress.update_progress()

		-- Reset timer with appropriate delay
		if state.timer then
			Timer.stop(state.timer)
		end
		state.timer = Timer.start(function()
			M.step()
		end, next_delay)
	end
end

function M.restart(options)
	options = options or {}

	if options.preset then
		local config_module = require("pacer.config")
		local preset_config = config_module.get_preset_config(options.preset)
		state.apply_config(preset_config)
	else
		state.apply_config(options)
	end

	state.bufnr = v.api.nvim_get_current_buf()
	state.ns = H.create_namespace()
	state.words = get_words(state.bufnr)

	local start_word = 1
	if options.start_from_cursor and not options.from_word then
		local cursor = v.api.nvim_win_get_cursor(0)
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
	progress.update_progress()

	if state.timer then
		Timer.stop(state.timer)
	end

	local ms_per_word = math.floor(60 * 1000 / state.config.wpm)

	state.timer = Timer.start(function()
		M.step()
	end, ms_per_word)

	M.add_keymap()
end

function M.pause()
	if state.timer then
		Timer.stop(state.timer)
	end

	clear()

	-- Explicitly clear focus highlights
	if state.bufnr and v.api.nvim_buf_is_valid(state.bufnr) then
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
