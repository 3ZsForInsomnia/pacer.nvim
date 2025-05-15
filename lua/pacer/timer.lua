local M = {}
local uv = vim.loop

function M.start(fn, interval_ms)
	local timer = uv.new_timer()
	timer:start(0, interval_ms, vim.schedule_wrap(fn))
	return timer
end

function M.stop(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

return M
