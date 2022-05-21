if not vim.fn.has 'nvim-0.7.0' then
  vim.api.nvim_err_writeln 'please.nvim requires at least Neovim 0.7'
  return
end

if vim.g.loaded_please then
  return
end

vim.g.loaded_please = true

local please = require 'please'
local logging = require 'please.logging'

vim.api.nvim_create_user_command('Please', function(opts)
  local cmd_name = opts.fargs[1]

  local cmd = please[cmd_name]
  if not cmd then
    logging.error("'%s' is not a Please command", cmd)
    return
  end

  local args = { unpack(opts.fargs, 2) }
  local cmd_opts = {}
  for _, arg in ipairs(args) do
    cmd_opts[arg] = true
  end
  cmd(cmd_opts)
end, { nargs = '+', force = true })
