local query = require 'please.query'
local targets = require 'please.targets'

local please = {}

local jump_to_target = function(root, label)
  local filepath, line, col, err = targets.locate_build_target(root, label)
  if err then
    print(err)
    return
  end
  vim.cmd('edit ' .. filepath)
  vim.api.nvim_win_set_cursor(0, { line, col - 1 }) -- col is 0-indexed
end

---Jumps to the location of the build target which takes the file open in the current buffer as input.
---
---The cursor will be moved to the starting position of the target's build rule invocation if it can be found which
---*should* be the case for all targets except for those with names which are generated when the BUILD file is executed.
---
---If there are multiple targets which use the open file as an input, then you'll be prompted for which one to jump to.
---This prompt uses vim.ui.select which allows you to customise the appearance to your taste (see
---https://github.com/stevearc/dressing.nvim for example).
please.jump_to_target = function()
  local filepath = vim.fn.expand '%:p'
  local root, err = query.reporoot(filepath)
  if err then
    print(err)
    return
  end
  local labels, err = query.whatinputs(root, filepath)
  if err then
    print(err)
    return
  end
  if #labels > 1 then
    vim.ui.select(labels, { prompt = 'Select target' }, function(selected)
      jump_to_target(root, selected)
    end)
  else
    jump_to_target(root, labels[1])
  end
end

return please
