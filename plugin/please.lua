local min_nvim_version = '0.11.0'
if vim.fn.has(string.format('nvim-%s', min_nvim_version)) == 0 then
  vim.notify(string.format('please.nvim requires at least Neovim %s', min_nvim_version), vim.log.levels.ERROR)
  return
end

if vim.g.loaded_please then
  return
end

local please = require('please')
local plugin = require('please.plugin')
local command = require('please.command')
local logging = require('please.logging')
local popup = require('please.runners.popup')

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
    reload = plugin.reload,
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

configure_filetype()
create_user_command()

vim.g.loaded_please = true
