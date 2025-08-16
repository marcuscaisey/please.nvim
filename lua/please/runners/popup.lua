local please = require('please')

local M = {}

function M.restore()
  vim.deprecate('please.runners.popup.restore', 'please.maximise_popup', 'v1.0.0', 'please.nvim')
  please.maximise_popup()
end

return M
