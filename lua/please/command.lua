local please = require 'please'
local logging = require 'please.logging'

local command = {}

local cmds = {
  jump_to_target = please.jump_to_target,
  run = please.run,
  test = please.test,
  build = please.build,
  yank = please.yank,
  reload = please.reload,
  toggle_debug_logs = logging.toggle_debug,
}

---Runs a please.nvim command by name.
---@param name string: name of the command
command.run_command = function(name)
  local cmd = cmds[name]
  if not cmd then
    logging.error("'%s' is not a Please command", name)
    return
  end
  cmd()
end

return command
