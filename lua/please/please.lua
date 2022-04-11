local query = require 'please.query'
local parsing = require 'please.parsing'
local runners = require 'please.runners'
local input = require 'please.input'

---@tag please-commands

---@brief [[
--- When using a command which involves the build target of the current file, there may be multiple targets found if the
--- file is referenced in multiple places. In such cases, you'll be prompted for which one to use. This prompt uses
--- |vim.ui.select()| which allows you to customise the appearance to your taste (see
--- https://github.com/stevearc/dressing.nvim and |lua-ui|).
---@brief ]]

local please = {}

---Jumps to the location of the build target of the current file.
---
---The cursor will be moved to where the build target is created if it can be found which should be the case for all
---targets except for those with names which are generated when the BUILD file is executed.
please.jump_to_target = function()
  local filepath = vim.fn.expand '%:p'
  -- TODO: use assert to simplify these foo, err = func(<args>) calls and then catch and log in a decorating func like
  -- log_errors
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
  input.select_if_required(labels, 'Select target to jump to', function(label)
    local target_filepath, line, col, err = parsing.locate_build_target(root, label)
    if err then
      print(err)
      return
    end
    vim.cmd('edit ' .. target_filepath)
    vim.api.nvim_win_set_cursor(0, { line, col - 1 }) -- col is 0-indexed
  end)
end

---Builds the target of the current file.
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
  input.select_if_required(labels, 'Select target to build', function(label)
    runners.popup('plz', { '--repo_root', root, '--verbosity', 'info', 'build', label })
  end)
end

---Tests the current file.
please.test_file = function()
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
  input.select_if_required(labels, 'Select target to test', function(label)
    runners.popup('plz', { '--repo_root', root, '--interactive_output', '--colour', 'test', label })
  end)
end

---Runs the test under the cursor.
---
---Supported languages:
---- Go
---  - regular go test functions (not subtests)
---  - testify suite test methods
please.test_under_cursor = function()
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
  local test_name, err = parsing.get_test_at_cursor()
  if err then
    print(err)
    return
  end
  input.select_if_required(labels, 'Select target to test', function(label)
    runners.popup('plz', { '--repo_root', root, '--interactive_output', '--colour', 'test', label, test_name })
  end)
end

return please
