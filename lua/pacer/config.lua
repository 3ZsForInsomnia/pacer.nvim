local M = {}

M.defaults = {
	highlight = {
		bg = "#335577",
		fg = "#ffffff",
		bold = true,
	},
	speed = 250,
	auto_pause = true,
	stop_key = "<C-c>",
	move_cursor = true,
	focus = {
		enabled = true,
		dim_color = "#777777",
		dim_style = "italic",
	},
	presets = {
		Code = {
			speed = 150,
		},
		Article = {
			speed = 300,
		},
		LongForm = {
			speed = 400,
		},
	},
}

function M.get_preset_config(preset_name)
	if not preset_name then
		return M.options
	end

	-- Check if preset exists
	local presets = M.options.presets or {}
	local preset = presets[preset_name]

	if not preset then
		vim.notify("Pacer: Preset '" .. preset_name .. "' not found", vim.log.levels.WARN)
		return M.options
	end

	-- Create a new config that inherits from defaults but applies preset overrides
	local preset_config = vim.tbl_deep_extend("force", {}, M.options, preset)

	-- Remove the presets key to avoid confusion
	preset_config.presets = nil

	return preset_config
end

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

	-- Initialize the state with the base config
	local state = require("pacer.state")
	state.apply_config(M.options)

	return M.options
end

return M
