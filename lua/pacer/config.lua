local M = {}

local log = require("pacer.log")

M.defaults = {
	log_level = "error", -- "info", "warn", "error"
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
		vim.api.nvim_echo({ { "Preset '" .. preset_name .. "' not found", "WarningMsg" } }, false, {})
		log.warn("Preset '" .. preset_name .. "' not found. Available presets: " .. vim.inspect(vim.tbl_keys(presets)))
		return M.options
	end

	log.info("Using preset '" .. preset_name .. "': " .. vim.inspect(preset))

	-- Create a new config that inherits from defaults but applies preset overrides
	local ok, preset_config = pcall(vim.tbl_deep_extend, "force", {}, M.options, preset)
	if not ok then
		vim.api.nvim_echo({ { "Preset config error", "ErrorMsg" } }, false, {})
		log.error("Error applying preset '" .. preset_name .. "': " .. tostring(preset_config))
		return M.options
	end

	-- Remove the presets key to avoid confusion
	preset_config.presets = nil

	return preset_config
end

M.options = {}

-- Track if setup has been called
M._setup_called = false

function M.setup(opts)
	M._setup_called = true

	local user_opts = opts or {}
	log.info("Setting up with options: " .. vim.inspect(user_opts))

	local ok, merged_config = pcall(vim.tbl_deep_extend, "force", {}, M.defaults, user_opts)
	if not ok then
		vim.api.nvim_echo({ { "Config error, using defaults", "WarningMsg" } }, false, {})
		log.error("Error merging user config with defaults: " .. tostring(merged_config) .. ". Using defaults.")
		M.options = vim.deepcopy(M.defaults)
	else
		M.options = merged_config
	end

	-- Validate critical config values
	if M.options.wpm < 60 or M.options.wpm > 2000 then
		vim.api.nvim_echo({ { "Pacer: Invalid WPM (" .. M.options.wpm .. "), using 300", "WarningMsg" } }, false, {})
		log.warn("Invalid WPM in config (" .. M.options.wpm .. "), resetting to 300")
		M.options.wpm = 300
	end

	if not M.options.highlight or not M.options.highlight.bg or not M.options.highlight.fg then
		vim.api.nvim_echo({ { "Pacer: Invalid highlight config, using defaults", "WarningMsg" } }, false, {})
		log.warn("Invalid highlight config, using defaults")
		M.options.highlight = vim.deepcopy(M.defaults.highlight)
	end

	-- Validate environment
	M.validate_environment()

	-- Initialize the state with the base config
	local ok, err = pcall(function()
		local state = require("pacer.state")
		state.apply_config(M.options)
	end)

	if not ok then
		log.error("Error applying config to state: " .. tostring(err))
	end

	log.info("Setup completed with final config: " .. vim.inspect(M.options))
	return M.options
end

function M.validate_environment()
	local issues = {}

	-- Check Neovim version
	if vim.fn.has("nvim-0.8") == 0 then
		table.insert(issues, "Neovim version < 0.8 (pacer.nvim requires >= 0.8)")
	end

	-- Check required features
	if vim.fn.has("timers") == 0 then
		table.insert(issues, "Timer support not available")
	end

	if vim.fn.has("lua") == 0 then
		table.insert(issues, "Lua support not available")
	end

	-- Check if we have a valid buffer
	local current_buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(current_buf) then
		table.insert(issues, "No valid buffer available")
	end

	-- Report issues
	if #issues > 0 then
		vim.api.nvim_echo({ { "Pacer: Environment issues detected:", "WarningMsg" } }, false, {})
		log.warn("Environment validation found issues:")
		for _, issue in ipairs(issues) do
			log.warn("  - " .. issue)
		end

		if #issues > 1 then -- Only show this for multiple serious issues
			vim.api.nvim_echo({ { "Pacer may not work correctly", "WarningMsg" } }, false, {})
		end
	else
		log.info("Environment validation passed")
	end

	return #issues == 0
end

function M.ensure_setup()
	if not M._setup_called then
		log.info("Lazy setup - initializing with defaults")
		-- Initialize with defaults if setup hasn't been called
		M.setup()

		-- Setup other components that are normally done in init.lua
		local ok, err = pcall(function()
			require("pacer.highlight").refresh_highlight()
			require("pacer.focus").setup()
		end)

		if not ok then
			log.error("Error during lazy setup: " .. tostring(err))
		end
	end
end

return M
