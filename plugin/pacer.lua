if vim.g.loaded_pacer then
	return
end
vim.g.loaded_pacer = true

-- Setup commands immediately but defer full initialization
-- This allows lazy.nvim to work properly while still setting up commands
require("pacer.commands").setup()
