local please = require('please')

local popup = {}

function popup.restore()
  vim.deprecate('please.runners.popup.restore', 'please.maximise_popup', 'v1.0.0', 'please.nvim')
  please.maximise_popup()
end

return popup
