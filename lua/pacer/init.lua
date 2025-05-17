local M = {}

function M.setup(opts)
	local config = require("pacer.config")
	config.setup(opts)

	require("pacer.highlight").refresh_highlight()
	require("pacer.commands").setup()
	require("pacer.focus").setup()
end

return M
