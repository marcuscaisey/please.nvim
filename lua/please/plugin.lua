local logging = require('please.logging')

local M = {}

function M.reload()
  for pkg, _ in pairs(package.loaded) do
    if vim.startswith(pkg, 'please') then
      package.loaded[pkg] = nil
    end
  end
  require('please.plugin').load()
  logging.info('reloaded plugin')
end

return M
