local please = require('please')
local command = require('please.command')
local future = require('please.future')
local logging = require('please.logging')
local popup = require('please.runners.popup')
local debug = require('please.debug')

local M = {}

-- configure all of the file names / extensions which should correspond to the please filetype
local function configure_filetype()
  vim.g.do_filetype_lua = 1 -- enable Lua filetype detection
  vim.filetype.add({
    extension = {
      build_defs = 'please',
      build_def = 'please',
      build = 'please',
      plz = 'please',
    },
    filename = {
      ['BUILD'] = 'please',
    },
    pattern = {
      ['%.plzconfig.*'] = 'dosini',
    },
  })
end

-- create the Please user command
local function create_user_command()
  local cmds = {
    jump_to_target = please.jump_to_target,
    build = please.build,
    test = please.test,
    run = please.run,
    debug = please.debug,
    yank = please.yank,
    action_history = please.action_history,
    restore_popup = popup.restore,
    reload = M.reload,
    toggle_debug_logs = logging.toggle_debug,
  }
  local cmd_name_to_opts = {
    test = { 'under_cursor', 'failed' },
  }

  command.create_user_command(cmds, cmd_name_to_opts)
end

-- make sure that the python parser is installed and configure it be used for please files
local function configure_treesitter()
  require('nvim-treesitter.install').ensure_installed({ 'python', 'go' })
  future.vim.treesitter.language.register('python', 'please')
end

function M.load()
  configure_filetype()
  configure_treesitter()
  create_user_command()
  debug.setup()
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
