local M = {}

-- Log levels
M.levels = {
	ERROR = 1,
	WARN = 2,
	INFO = 3,
}

M.level_names = {
	[M.levels.ERROR] = "ERROR",
	[M.levels.WARN] = "WARN",
	[M.levels.INFO] = "INFO",
}

-- Get numeric level from string
local function get_level_num(level_str)
	if level_str == "error" then
		return M.levels.ERROR
	elseif level_str == "warn" then
		return M.levels.WARN
	elseif level_str == "info" then
		return M.levels.INFO
	else
		return M.levels.INFO -- default
	end
end

-- Get current log level from config
local function get_current_level()
	local config = require("pacer.config")
	if config.options and config.options.log_level then
		return get_level_num(config.options.log_level)
	end
	return M.levels.INFO -- default to info level
end

-- Core logging function
local function log(level, message, should_notify)
	local current_level = get_current_level()

	-- Only log if the message level is <= current log level (higher priority)
	if level > current_level then
		return
	end

	local level_name = M.level_names[level] or "UNKNOWN"
	local log_message = string.format("Pacer [%s]: %s", level_name, message)

	-- Always write to messages
	print(log_message)

	-- Notify user if requested
	if should_notify then
		local hl_group = "Normal"
		if level == M.levels.ERROR then
			hl_group = "ErrorMsg"
		elseif level == M.levels.WARN then
			hl_group = "WarningMsg"
		end

		vim.api.nvim_echo({ { message, hl_group } }, false, {})
	end
end

-- Public logging functions
function M.info(message, notify)
	log(M.levels.INFO, message, notify)
end

function M.warn(message, notify)
	log(M.levels.WARN, message, notify or false)
end

function M.error(message, notify)
	log(M.levels.ERROR, message, notify == nil and true or notify) -- errors notify by default
end

return M
