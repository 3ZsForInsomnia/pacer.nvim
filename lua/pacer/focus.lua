local M = {}
local state = require("pacer.state")

local function setup_namespace()
	if not M.ns_id then
		M.ns_id = vim.api.nvim_create_namespace("PacerFocus")
	end
	return M.ns_id
end

function M.undim_line(bufnr, lnum)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	vim.api.nvim_buf_clear_namespace(bufnr, setup_namespace(), lnum, lnum + 1)
end

-- Clear all focus highlights
function M.clear_highlights(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, setup_namespace(), 0, -1)
	end
end

-- Check if current buffer is text-based
function M.is_text_file()
	local text_filetypes = {
		"text",
		"markdown",
		"tex",
		"plaintex",
		"rst",
		"asciidoc",
		"org",
		"html",
		"mail",
	}
	local ft = vim.bo.filetype
	for _, text_ft in ipairs(text_filetypes) do
		if ft == text_ft then
			return true
		end
	end
	return false
end

-- Find paragraph boundaries for text files
function M.get_paragraph_range()
	local bufnr = state.current_position.bufnr or vim.api.nvim_get_current_buf()
	local cursor_row = state.current_position.line or (vim.api.nvim_win_get_cursor(0)[1] - 1)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	-- Find paragraph start (backward from cursor)
	local start_row = cursor_row
	while start_row > 0 and lines[start_row + 1] and lines[start_row + 1]:match("%S") do
		start_row = start_row - 1
	end

	-- Find paragraph end (forward from cursor)
	local end_row = cursor_row
	while end_row < #lines and lines[end_row + 1] and lines[end_row + 1]:match("%S") do
		end_row = end_row + 1
	end

	return { start_row = start_row, end_row = end_row }
end

function M.get_window_range()
	local cursor_row = state.current_position.line or (vim.api.nvim_win_get_cursor(0)[1] - 1)
	local MIN_VISIBLE_LINES = 5

	local bufnr = state.current_position.bufnr or vim.api.nvim_get_current_buf()
	local line_count = vim.api.nvim_buf_line_count(bufnr)

	return {
		start_row = math.max(0, cursor_row - MIN_VISIBLE_LINES),
		end_row = math.min(line_count - 1, cursor_row + MIN_VISIBLE_LINES),
		start_col = 0,
		end_col = 0,
	}
end

function M.get_scope_range()
	-- Basic checks for treesitter availability
	local has_ts, ts_parsers = pcall(require, "nvim-treesitter.parsers")
	if not has_ts or not ts_parsers.has_parser() then
		return M.get_window_range()
	end

	local bufnr = state.current_position.bufnr or vim.api.nvim_get_current_buf()

	-- Get cursor position
	local cursor_row = state.current_position.line or (vim.api.nvim_win_get_cursor(0)[1] - 1)
	local cursor_col = state.current_position.col or vim.api.nvim_win_get_cursor(0)[2]

	-- Constants
	local MIN_CONTEXT_LINES = 3 -- Minimum extra context lines above/below scope

	-- Get tree
	local parser = vim.treesitter.get_parser(bufnr)
	local tree = parser:parse()[1]
	local root = tree:root()

	-- Find the node at cursor position
	local current_node = root:named_descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)
	if not current_node then
		return M.get_window_range()
	end

	-- Track found scopes (immediate and parent)
	local scopes = {}

	-- Walk up the tree to find relevant scopes
	local node = current_node
	while node do
		local node_type = node:type()

		-- Collect both immediate function scope and parent table/block scopes
		if
			node_type:match("function")
			or node_type:match("method")
			or node_type == "block"
			or node_type == "table" -- Important for Lua tables with functions
			or node_type:match("statement")
		then
			table.insert(scopes, node)
		end

		node = node:parent()

		-- Stop if we've found enough context
		if #scopes >= 2 then
			break
		end
	end

	-- If no scopes found, fallback to window
	if #scopes == 0 then
		return M.get_window_range()
	end

	-- Initialize with first scope
	local start_row, start_col, end_row, end_col = scopes[1]:range()

	-- Expand with parent scope if available
	if scopes[2] then
		local parent_start, _, parent_end, _ = scopes[2]:range()
		start_row = math.min(start_row, parent_start)
		end_row = math.max(end_row, parent_end)
	end

	-- Add extra context lines
	start_row = math.max(0, start_row - MIN_CONTEXT_LINES)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	end_row = math.min(line_count - 1, end_row + MIN_CONTEXT_LINES)

	return {
		start_row = start_row,
		end_row = end_row,
		start_col = 0,
		end_col = 0,
	}
end

function M.apply_focus(config)
	config = config or state.config
	if not config.focus.enabled then
		return
	end

	local dim_color = config.focus.dim_color or "#777777"
	vim.cmd(string.format("highlight PacerDimText guifg=%s", dim_color))

	local bufnr = state.current_position and state.current_position.bufnr or vim.api.nvim_get_current_buf()

	-- Clear previous highlights
	M.clear_highlights(bufnr)

	-- Get range based on file type
	local focus_range = nil
	if M.is_text_file() then
		focus_range = M.get_paragraph_range()
	else
		focus_range = M.get_scope_range()
	end

	-- If we couldn't determine a range, do nothing
	if not focus_range then
		return
	end

	-- Get total lines in buffer
	local total_lines = vim.api.nvim_buf_line_count(bufnr)

	-- Apply dimming to everything outside the focus range
	-- Dim lines before the focus range
	for i = 0, focus_range.start_row - 1 do
		vim.api.nvim_buf_add_highlight(bufnr, setup_namespace(), "PacerDimText", i, 0, -1)
	end

	-- Dim lines after the focus range
	for i = focus_range.end_row + 1, total_lines - 1 do
		vim.api.nvim_buf_add_highlight(bufnr, setup_namespace(), "PacerDimText", i, 0, -1)
	end
end

function M.setup()
	vim.cmd([[
    highlight default PacerDimText guifg=#777777 guibg=NONE gui=italic
  ]])
end

return M
