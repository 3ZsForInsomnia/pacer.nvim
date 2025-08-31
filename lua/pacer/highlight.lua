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

	if not config or not config.highlight then
		print("Pacer: Invalid config for highlight setup, using defaults")
		config = { highlight = M.defaults and M.defaults.highlight or { bg = "#335577", fg = "#ffffff", style = "underline" } }
	end

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

	local ok, err = pcall(c, cmd)
	if not ok then
		print("Pacer: Failed to setup highlight: " .. tostring(err))
		-- Try with basic highlight as fallback
		pcall(c, "highlight " .. HL_GROUP .. " guibg=#335577 guifg=#ffffff gui=underline")
	end
end

-- Set up our highlight group on colorscheme change
local ok, err = pcall(v.api.nvim_create_autocmd, "ColorScheme", {
	callback = function()
		local highlight_ok, highlight_err = pcall(setup_highlight)
		if not highlight_ok then
			print("Pacer: Failed to refresh highlight on colorscheme change: " .. tostring(highlight_err))
		end
	end,
})
if not ok then
	print("Pacer: Failed to setup colorscheme autocmd: " .. tostring(err))
end

function M.create_namespace()
	if M.ns_id == nil then
		local ok, ns_id = pcall(a.nvim_create_namespace, "Pacer")
		if ok then
			M.ns_id = ns_id
		else
			print("Pacer: Failed to create namespace: " .. tostring(ns_id))
			return nil
		end
	end
	return M.ns_id
end

function M.highlight_word(bufnr, ns, lnum, col, len)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		print("Pacer: Cannot highlight word - invalid buffer")
		return false
	end
	
	if not ns or not lnum or not col or not len then
		print("Pacer: Cannot highlight word - missing parameters")
		return false
	end
	
	local ok, err = pcall(a.nvim_buf_set_extmark, bufnr, ns, lnum, col, {
		end_col = col + len,
		hl_group = HL_GROUP,
	})
	
	if not ok then
		print("Pacer: Failed to set highlight extmark: " .. tostring(err))
		return false
	end
	
	return true
end

-- Apply highlight when the module loads
local ok, err = pcall(setup_highlight)
if not ok then
	print("Pacer: Failed to setup initial highlight: " .. tostring(err))
end

-- Function to refresh highlight when config changes
function M.refresh_highlight(config)
	local ok, err = pcall(setup_highlight, config)
	if not ok then
		print("Pacer: Failed to refresh highlight: " .. tostring(err))
	end
end

return M
