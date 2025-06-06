local v = vim
local a = v.api
local c = v.cmd

local M = {}
local state = require("pacer.state")

M.ns_id = nil
local HL_GROUP = "PacerHighlight"

local allowed_styles = {
	"NONE",
	"bold",
	"italic",
	"underline",
	"undercurl",
}

-- Helper function to set up the highlight with config values
local function setup_highlight(config)
	config = config or state.config

	local hl_config = config.highlight
	local style = hl_config.style or "NONE"
	local styles = {}

	for s in string.gmatch(style, "[^,%s]+") do
		if v.tbl_contains(allowed_styles, s) then
			table.insert(styles, s)
		end
	end

	local final_style = table.concat(styles, ",")
	if final_style == "" then
		final_style = "NONE"
	end

	local cmd = string.format(
		"highlight %s guibg=%s guifg=%s gui=%s",
		HL_GROUP,
		hl_config.bg or "#335577",
		hl_config.fg or "#ffffff",
		final_style
	)

	c(cmd)
end

-- Set up our highlight group on colorscheme change
v.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		setup_highlight()
	end,
})

function M.create_namespace()
	if M.ns_id == nil then
		M.ns_id = a.nvim_create_namespace("Pacer")
	end
	return M.ns_id
end

function M.highlight_word(bufnr, ns, lnum, col, len)
	a.nvim_buf_set_extmark(bufnr, ns, lnum, col, {
		end_col = col + len,
		hl_group = HL_GROUP,
	})
end

-- Apply highlight when the module loads
setup_highlight()

-- Function to refresh highlight when config changes
function M.refresh_highlight(config)
	setup_highlight(config)
end

return M
