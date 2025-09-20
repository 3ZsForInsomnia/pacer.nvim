local M = {}

local log = require("pacer.log")

-- Setup autocommands for cleanup
local function setup_autocommands()
	local group = vim.api.nvim_create_augroup("PacerCleanup", { clear = true })

	-- Clean up when Neovim is closing
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			log.info("Neovim closing, cleaning up")
			local ok, err = pcall(function()
				require("pacer.core").stop()
				require("pacer.state").cleanup()
			end)
			if not ok then
				log.error("Error during shutdown cleanup: " .. tostring(err))
			end
		end,
		desc = "Clean up Pacer on Neovim exit",
	})

	-- Clean up when the active buffer is deleted
	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = function(ev)
			local state = require("pacer.state")
			if state.bufnr == ev.buf and state.active then
				log.warn("Active buffer deleted, stopping pacer", true)
				local ok, err = pcall(function()
					require("pacer.core").stop()
				end)
				if not ok then
					log.error("Error stopping pacer on buffer delete: " .. tostring(err))
					state.reset_to_safe_state()
				end
			end
		end,
		desc = "Stop Pacer when active buffer is deleted",
	})

	log.info("Autocommands setup completed")
end

function M.setup(opts)
	log.info("Initializing plugin")

	local ok, err = pcall(function()
		local config = require("pacer.config")
		config.setup(opts)

		require("pacer.highlight").refresh_highlight()
		-- Only setup commands if not already done (e.g., by plugin loading)
		if not vim.g.pacer_commands_setup then
			require("pacer.commands").setup()
			vim.g.pacer_commands_setup = true
		end
		require("pacer.focus").setup()

		-- Setup cleanup autocommands
		setup_autocommands()
	end)

	if not ok then
		vim.api.nvim_echo({ { "Pacer setup failed", "ErrorMsg" } }, false, {})
		log.error("Setup failed: " .. tostring(err))
		return false
	end

	log.info("Initialization completed successfully")
	return true
end

return M
