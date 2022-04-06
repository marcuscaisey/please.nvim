local query = require 'please.query'
local targets = require 'please.targets'
local runners = require 'please.runners'

---@tag please-commands

local please = {}

local run_with_selected = function(options, prompt, func)
  if #options > 1 then
    vim.ui.select(options, { prompt = prompt }, function(selected)
      func(selected)
    end)
  else
    func(options[1])
  end
end

---Jumps to the location of the build target which takes the current file as input.
---
---The cursor will be moved to the starting position of the target's build rule invocation if it can be found which
---should be the case for all targets except for those with names which are generated when the BUILD file is executed.
---
---If there are multiple targets which use the open file as an input, then you'll be prompted for which one to jump to.
---This prompt uses |vim.ui.select()| which allows you to customise the appearance to your taste (see
---https://github.com/stevearc/dressing.nvim and |lua-ui|).
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
  run_with_selected(labels, 'Select target to jump to', function(label)
    local filepath, line, col, err = targets.locate_build_target(root, label)
    if err then
      print(err)
      return
    end
    vim.cmd('edit ' .. filepath)
    vim.api.nvim_win_set_cursor(0, { line, col - 1 }) -- col is 0-indexed
  end)
end

---Builds the target which takes the current file as input.
---
---If there are multiple targets which use the open file as an input, then you'll be prompted for which one to build.
---This prompt uses |vim.ui.select()| which allows you to customise the appearance to your taste (see
---https://github.com/stevearc/dressing.nvim and |lua-ui|).
please.build_target = function()
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
  run_with_selected(labels, 'Select target to build', function(label)
    runners.popup('plz', { '--repo_root', root, '--verbosity', 'info', 'build', label })
  end)
end

---Tests the target which takes the current file as input.
---
---If there are multiple targets which use the open file as an input, then you'll be prompted for which one to test.
---This prompt uses |vim.ui.select()| which allows you to customise the appearance to your taste (see
---https://github.com/stevearc/dressing.nvim and |lua-ui|).
please.test_target = function()
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
  run_with_selected(labels, 'Select target to test', function(label)
    runners.popup('plz', { '--repo_root', root, '--verbosity', 'info', '--colour', 'test', label })
  end)
end

return please
