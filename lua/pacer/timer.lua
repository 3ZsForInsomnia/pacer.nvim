local M = {}
local uv = vim.loop

function M.start(fn, interval_ms)
	if type(fn) ~= "function" then
		print("Pacer: Timer start called with invalid function")
		return nil
	end
	
	if type(interval_ms) ~= "number" or interval_ms <= 0 then
		print("Pacer: Timer start called with invalid interval: " .. tostring(interval_ms))
		return nil
	end
	
	-- Ensure interval is reasonable
	interval_ms = math.max(50, interval_ms) -- Set minimum threshold

	local ok, timer = pcall(uv.new_timer)
	if not ok or not timer then
		print("Pacer: Failed to create timer: " .. tostring(timer))
		return nil
	end

	-- Use one-shot timer (repeating=0)
	local start_ok, err = pcall(timer.start, timer,
		interval_ms,
		0,
		vim.schedule_wrap(function()
			local fn_ok, fn_err = pcall(fn)
			if not fn_ok then
				print("Pacer: Timer callback error: " .. tostring(fn_err))
			end
			-- Timer is auto-closed since it's one-shot
		end)
	)
	
	if not start_ok then
		print("Pacer: Failed to start timer: " .. tostring(err))
		pcall(timer.close, timer)
		return nil
	end

	return timer
end

function M.stop(timer)
	if not timer then
		return
	end
	
	local ok, is_closing = pcall(timer.is_closing, timer)
	if not ok then
		-- Timer might already be invalid, ignore
		return
	end
	
	if not is_closing then
		pcall(timer.stop, timer)
		pcall(timer.close, timer)
	end
end

return M
