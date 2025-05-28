local M = {}
local uv = vim.loop

function M.start(fn, interval_ms)
	-- Ensure interval is reasonable
	interval_ms = math.max(50, interval_ms) -- Set minimum threshold

	local timer = uv.new_timer()

	-- Use one-shot timer (repeating=0)
	timer:start(
		interval_ms,
		0,
		vim.schedule_wrap(function()
			fn()
			-- Timer is auto-closed since it's one-shot
		end)
	)

	return timer
end

function M.stop(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

return M
