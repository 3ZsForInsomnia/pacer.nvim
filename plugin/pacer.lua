-- This is sourced when plugin is loaded (by packer/lazy.nvim or runtimepath)
-- Safe to re-source
if vim.g.loaded_pacer then
	return
end
vim.g.loaded_pacer = true

require("pacer").setup()
