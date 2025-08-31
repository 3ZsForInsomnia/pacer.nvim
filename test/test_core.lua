local utils = require("test.utils")
local assert = require("luassert")

local function test_pacer_start_stop()
	-- Setup
	utils.setup()
	local bufnr = utils.create_test_buffer()

	-- Start pacer
	utils.start_pacer()
	
	local state = utils.get_plugin_state()
	assert.is_true(state.active)
	assert.is_not_nil(state.timer)
	assert.are.same(bufnr, state.bufnr)

	-- Stop pacer
	vim.cmd("PacerStop")
	
	assert.is_false(state.active)
	assert.is_nil(state.timer)

	utils.teardown()
end

local function test_pacer_pause_resume()
	-- Setup
	utils.setup()
	utils.create_test_buffer()

	-- Start pacer
	utils.start_pacer()
	
	local state = utils.get_plugin_state()
	assert.is_true(state.active)

	-- Pause pacer
	vim.cmd("PacerPause")
	
	assert.is_true(state.paused)
	assert.is_nil(state.timer)

	-- Resume pacer
	vim.cmd("PacerResume")
	
	assert.is_true(state.active)
	assert.is_false(state.paused)
	assert.is_not_nil(state.timer)

	utils.teardown()
end

local function test_state_validation()
	-- Setup
	utils.setup()
	utils.create_test_buffer()

	local state = utils.get_plugin_state()
	
	-- Test valid state
	assert.is_true(state.validate_state())
	
	-- Test invalid state (active without timer)
	state.active = true
	state.timer = nil
	assert.is_false(state.validate_state())
	
	-- State should be reset
	assert.is_false(state.active)

	utils.teardown()
end

local function test_error_handling()
	-- Setup
	utils.setup()

	-- Test starting with invalid WPM
	vim.cmd("PacerStart 50")  -- Below minimum
	local state = utils.get_plugin_state()
	assert.is_false(state.active)

	vim.cmd("PacerStart 3000")  -- Above maximum
	assert.is_false(state.active)

	-- Test resuming without previous session
	vim.cmd("PacerResume")
	assert.is_false(state.active)

	utils.teardown()
end

local function test_word_extraction()
	-- Setup
	utils.setup()
	local content = {
		"Hello world test",
		"",
		"Another paragraph here",
	}
	utils.create_test_buffer(content)

	-- Start pacer to trigger word extraction
	utils.start_pacer()
	
	local state = utils.get_plugin_state()
	assert.is_not_nil(state.words)
	assert.is_true(#state.words >= 6)  -- At least "Hello", "world", "test", "Another", "paragraph", "here"

	utils.teardown()
end

-- Run all tests
test_pacer_start_stop()
test_pacer_pause_resume()
test_state_validation()
test_error_handling()
test_word_extraction()

print("✓ All core functionality tests passed!")