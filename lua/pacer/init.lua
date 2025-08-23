local M = {}

function M.setup(opts)
	local config = require("pacer.config")
	config.setup(opts)

	require("pacer.highlight").refresh_highlight()
	-- Only setup commands if not already done (e.g., by plugin loading)
	if not vim.g.pacer_commands_setup then
		require("pacer.commands").setup()
		vim.g.pacer_commands_setup = true
	end
	require("pacer.focus").setup()
end

return M
