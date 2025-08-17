local logging = require('please.logging')

local M = {}

function M.reload()
  for modname, _ in pairs(package.loaded) do
    if modname == 'please' or vim.startswith(modname, 'please.') then
      package.loaded[modname] = nil
    end
  end
  vim.g.loaded_please = false
  vim.cmd.packadd('please.nvim')
  logging.info('reloaded plugin')
end

return M
