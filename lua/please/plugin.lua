local please = require('please')
local command = require('please.command')
local logging = require('please.logging')
local popup = require('please.runners.popup')

local M = {}

-- configure all of the file names / extensions which should correspond to the please filetype
local function configure_filetype()
  vim.filetype.add({
    extension = {
      build_defs = 'please',
      build = 'please',
    },
    filename = {
      BUILD = function(path)
        if vim.fs.root(path, '.plzconfig') then
          return 'please'
        end
        return 'bzl'
      end,
      ['BUILD.plz'] = 'please',
    },
    pattern = {
      ['%.plzconfig.*'] = 'dosini',
    },
  })
end

-- create the Please user command
local function create_user_command()
  local cmds = {
    restore_popup = popup.restore,
    toggle_debug_logs = logging.toggle_debug,
    reload = M.reload,
  }
  for k, v in pairs(please) do
    cmds[k] = v
  end
  local cmd_name_to_opts = {
    test = { 'under_cursor' },
    debug = { 'under_cursor' },
  }
  local cmd_name_to_positional_args = {
    command = true,
  }

  command.create_user_command(cmds, cmd_name_to_opts, cmd_name_to_positional_args)
end

function M.load()
  configure_filetype()
  create_user_command()
end

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
