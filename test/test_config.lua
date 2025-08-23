local utils = require("test.utils")
local assert = require("luassert")

local function test_default_config()
	-- Setup
	utils.setup()

	-- Clear any previous config
	package.loaded["pacer.config"] = nil
	package.loaded["pacer.state"] = nil

	-- Get fresh config module
	local config = require("pacer.config")

	-- Test default initialization
	local options = config.setup()

	-- Verify defaults are applied correctly
	assert.are.same("#335577", options.highlight.bg)
	assert.are.same("#ffffff", options.highlight.fg)
	assert.are.same("underline", options.highlight.style)
	assert.are.same(300, options.wpm)
	assert.are.same("<C-c>", options.pause_key)
	assert.are.same(true, options.move_cursor)
	assert.are.same(1.75, options.paragraph_delay_multiplier)
	assert.are.same(true, options.focus.enabled)
	assert.are.same("#777777", options.focus.dim_color)

	utils.teardown()
end

local function test_custom_config()
	-- Setup
	utils.setup()

	-- Clear any previous config
	package.loaded["pacer.config"] = nil
	package.loaded["pacer.state"] = nil

	-- Get fresh config module
	local config = require("pacer.config")

	-- Test custom initialization
	local options = config.setup({
		wpm = 400,
		highlight = {
			bg = "#FF0000",
		},
		move_cursor = false,
	})

	-- Verify custom options override defaults
	assert.are.same("#FF0000", options.highlight.bg)
	assert.are.same("#ffffff", options.highlight.fg) -- Not overridden
	assert.are.same("underline", options.highlight.style) -- Not overridden
	assert.are.same(400, options.wpm)
	assert.are.same("<C-c>", options.pause_key) -- Not overridden
	assert.are.same(false, options.move_cursor)

	utils.teardown()
end

local function test_preset_config()
	-- Setup
	utils.setup()

	-- Clear any previous config
	package.loaded["pacer.config"] = nil
	package.loaded["pacer.state"] = nil

	-- Get fresh config module
	local config = require("pacer.config")

	-- Setup with presets
	local options = config.setup({
		wpm = 350,
		presets = {
			fast = {
				wpm = 500,
				highlight = {
					bg = "#00FF00",
				},
			},
			slow = {
				wpm = 200,
				paragraph_delay_multiplier = 2.5,
			},
		},
	})

	-- Test base config first
	assert.are.same(350, options.wpm)

	-- Test fast preset
	local fast_config = config.get_preset_config("fast")
	assert.are.same(500, fast_config.wpm)
	assert.are.same("#00FF00", fast_config.highlight.bg)
	assert.are.same("#ffffff", fast_config.highlight.fg) -- Inherited from base

	-- Test slow preset
	local slow_config = config.get_preset_config("slow")
	assert.are.same(200, slow_config.wpm)
	assert.are.same(2.5, slow_config.paragraph_delay_multiplier)
	assert.are.same("#335577", slow_config.highlight.bg) -- Inherited from defaults

	-- Test non-existent preset (should return base config)
	local nonexistent = config.get_preset_config("nonexistent")
	assert.are.same(options, nonexistent)

	utils.teardown()
end

-- Run all tests
test_default_config()
test_custom_config()
test_preset_config()

print("✓ All config tests passed!")
