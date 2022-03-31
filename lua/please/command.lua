local please = require 'please'

local command = {}

---Runs a please.nvim command by name.
---@param name string: name of the command
command.run_command = function(name)
  local cmd = please[name]
  if not cmd then
    print(string.format("'%s' is not a Please command", name))
    return
  end
  cmd()
end

return command
