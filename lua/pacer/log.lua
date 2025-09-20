local M = {}

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

local function get_current_level()
	local config = require("pacer.config")
	if config.options and config.options.log_level then
		return get_level_num(config.options.log_level)
	end
	-- Use the default from config.defaults if options not yet set
	if config.defaults and config.defaults.log_level then
		return get_level_num(config.defaults.log_level)
	end
	-- Final fallback
	return M.levels.ERROR
end

local function log(level, message, should_notify)
	local current_level = get_current_level()

	if level > current_level then
		return
	end

	local level_name = M.level_names[level] or "UNKNOWN"
	local log_message = string.format("Pacer [%s]: %s", level_name, message)

	print(log_message)

	if should_notify then
		vim.notify(
			message,
			level == M.levels.ERROR and vim.log.levels.ERROR
				or level == M.levels.WARN and vim.log.levels.WARN
				or vim.log.levels.INFO
		)
	end
end

function M.info(message, notify)
	log(M.levels.INFO, message, notify)
end

function M.warn(message, notify)
	log(M.levels.WARN, message, notify or false)
end

function M.error(message, notify)
	log(M.levels.ERROR, message, notify == nil and true or notify)
end

return M
