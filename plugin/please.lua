if not vim.fn.has 'nvim-0.7.0' then
  vim.api.nvim_err_writeln 'please.nvim requires at least Neovim 0.7'
  return
end

if vim.g.loaded_please then
  return
end

vim.g.loaded_please = true

require('please.plugin').load()
