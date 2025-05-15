local v = vim
local a = v.api
local c = v.cmd

local M = {}
local config = require("pacer.config")

M.ns_id = nil
local HL_GROUP = "PacerHighlight"

-- Helper function to set up the highlight with config values
local function setup_highlight()
	local hl_config = config.options.highlight
	local cmd = string.format(
		"highlight %s guibg=%s guifg=%s gui=%s",
		HL_GROUP,
		hl_config.bg or "#335577",
		hl_config.fg or "#ffffff",
		hl_config.bold and "bold" or "NONE"
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

-- Apply highlight when the module loads if config is already available
if config.options and config.options.highlight then
	setup_highlight()
else
	-- Fallback if config not loaded yet
	if v.fn.hlexists(HL_GROUP) == 0 then
		c(("highlight %s guibg=#335577 guifg=#ffffff gui=bold"):format(HL_GROUP))
	end
end

-- Function to refresh highlight when config changes
function M.refresh_highlight()
	setup_highlight()
end

return M
