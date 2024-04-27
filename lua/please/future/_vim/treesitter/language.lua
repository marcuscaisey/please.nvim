local M = {}

function M.register(lang, filetype)
  require('nvim-treesitter.parsers').filetype_to_parsername[filetype] = lang
end

return M
