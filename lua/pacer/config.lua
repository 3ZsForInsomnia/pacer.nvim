local M = {}

M.defaults = {
	highlight = {
		bg = "#335577",
		fg = "#ffffff",
		bold = true,
	},
	speed = 250, -- ms
	auto_pause = true,
	stop_key = "<C-c>",
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
	return M.options
end

return M
