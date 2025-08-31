if vim.g.loaded_pacer then
	return
end
vim.g.loaded_pacer = true

-- This allows lazy.nvim to work properly while still setting up commands
require("pacer.commands").setup()
