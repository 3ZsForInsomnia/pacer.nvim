local M = {}

M.defaults = {
	highlight = {
		bg = "#335577",
		fg = "#ffffff",
		style = "underline",
	},
	wpm = 300,
	pause_key = "<C-c>",
	move_cursor = true,
	paragraph_delay_multiplier = 1.75,
	focus = {
		enabled = true,
		dim_color = "#777777",
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

-- Track if setup has been called
M._setup_called = false

function M.setup(opts)
	M._setup_called = true
	M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

	-- Initialize the state with the base config
	local state = require("pacer.state")
	state.apply_config(M.options)

	return M.options
end

function M.ensure_setup()
	if not M._setup_called then
		-- Initialize with defaults if setup hasn't been called
		M.setup()
		
		-- Setup other components that are normally done in init.lua
		require("pacer.highlight").refresh_highlight()
		require("pacer.focus").setup()
	end
end

return M
