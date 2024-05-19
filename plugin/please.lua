local min_nvim_version = '0.10.0'
if not vim.fn.has(string.format('nvim-%s', min_nvim_version)) then
  vim.api.nvim_err_writeln(string.format('please.nvim requires at least Neovim %s', min_nvim_version))
  return
end

if vim.g.loaded_please then
  return
end

vim.g.loaded_please = true

require('please.plugin').load()
