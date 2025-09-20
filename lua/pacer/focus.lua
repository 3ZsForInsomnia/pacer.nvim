local M = {}
local state = require("pacer.state")

local log = require("pacer.log")

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
	local ok, ft = pcall(function()
		return vim.bo.filetype
	end)
	if not ok then
		log.warn("Could not determine filetype, assuming non-text")
		return false
	end

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

	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		log.error("Invalid buffer for paragraph range")
		return M.get_window_range()
	end

	local cursor_row = state.current_position.line or (vim.api.nvim_win_get_cursor(0)[1] - 1)

	local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
	if not ok then
		log.error("Failed to get buffer lines for paragraph range: " .. tostring(lines))
		return M.get_window_range()
	end

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
	local cursor_row = state.current_position.line

	if not cursor_row then
		local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
		if ok then
			cursor_row = cursor[1] - 1
		else
			log.warn("Could not get cursor position for window range, using 0")
			cursor_row = 0
		end
	end

	local MIN_VISIBLE_LINES = 5

	local bufnr = state.current_position.bufnr or vim.api.nvim_get_current_buf()

	local ok, line_count = pcall(vim.api.nvim_buf_line_count, bufnr)
	if not ok then
		log.error("Failed to get line count for window range: " .. tostring(line_count))
		line_count = cursor_row + MIN_VISIBLE_LINES + 1
	end

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
	if not has_ts then
		log.info("Treesitter not available, using window range")
		return M.get_window_range()
	end
	
	-- Get the current buffer's filetype for parser check
	local bufnr = state.current_position.bufnr or vim.api.nvim_get_current_buf()
	local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')
	
	if not filetype or filetype == '' or not ts_parsers.has_parser(filetype) then
		log.info("Treesitter not available or no parser, using window range")
		return M.get_window_range()
	end


	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		log.error("Invalid buffer for scope range")
		return M.get_window_range()
	end

	-- Get cursor position
	local cursor_row = state.current_position.line
	local cursor_col = state.current_position.col

	if not cursor_row or not cursor_col then
		local ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
		if ok then
			cursor_row = cursor_row or (cursor[1] - 1)
			cursor_col = cursor_col or cursor[2]
		else
			log.warn("Could not get cursor position for scope range")
			return M.get_window_range()
		end
	end

	-- Constants
	local MIN_CONTEXT_LINES = 3 -- Minimum extra context lines above/below scope

	-- Get tree
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not ok then
		log.error("Failed to get treesitter parser: " .. tostring(parser))
		return M.get_window_range()
	end

	local ok, trees = pcall(parser.parse, parser)
	if not ok or not trees or #trees == 0 then
		log.error("Failed to parse tree: " .. tostring(trees))
		return M.get_window_range()
	end

	local tree = trees[1]
	local root = tree:root()

	-- Find the node at cursor position
	local current_node = root:named_descendant_for_range(cursor_row, cursor_col, cursor_row, cursor_col)
	if not current_node then
		log.info("No treesitter node at cursor position")
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
		log.info("No relevant scopes found in treesitter")
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
	local ok, line_count = pcall(vim.api.nvim_buf_line_count, bufnr)
	if not ok then
		log.error("Failed to get line count for scope range")
		line_count = end_row + MIN_CONTEXT_LINES + 1
	end
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

	local ok, err = pcall(vim.cmd, string.format("highlight PacerDimText guifg=%s", dim_color))
	if not ok then
		log.error("Failed to set dim text highlight: " .. tostring(err))
		return
	end

	local bufnr = state.current_position and state.current_position.bufnr or vim.api.nvim_get_current_buf()

	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		log.error("Cannot apply focus - invalid buffer")
		return
	end

	-- Clear previous highlights
	M.clear_highlights(bufnr)

	-- Get range based on file type
	local focus_range = nil
	local ok, err = pcall(function()
		if M.is_text_file() then
			focus_range = M.get_paragraph_range()
		else
			focus_range = M.get_scope_range()
		end
	end)

	if not ok then
		log.error("Error determining focus range: " .. tostring(err))
		focus_range = M.get_window_range() -- Fallback to window range
	end

	-- If we couldn't determine a range, do nothing
	if not focus_range then
		log.warn("Could not determine focus range, skipping focus")
		return
	end

	-- Get total lines in buffer
	local ok, total_lines = pcall(vim.api.nvim_buf_line_count, bufnr)
	if not ok then
		log.error("Failed to get buffer line count: " .. tostring(total_lines))
		return
	end

	-- Apply dimming to everything outside the focus range
	-- Dim lines before the focus range
	for i = 0, focus_range.start_row - 1 do
		pcall(vim.api.nvim_buf_add_highlight, bufnr, setup_namespace(), "PacerDimText", i, 0, -1)
	end

	-- Dim lines after the focus range
	for i = focus_range.end_row + 1, total_lines - 1 do
		pcall(vim.api.nvim_buf_add_highlight, bufnr, setup_namespace(), "PacerDimText", i, 0, -1)
	end
end

function M.setup()
	local ok, err = pcall(
		vim.cmd,
		[[
		highlight default PacerDimText guifg=#777777 guibg=NONE gui=italic
	]]
	)

	if not ok then
		log.error("Failed to setup default dim text highlight: " .. tostring(err))
	end
end

return M
