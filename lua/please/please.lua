local Path = require 'plenary.path'
local query = require 'please.query'
local parsing = require 'please.parsing'
local runners = require 'please.runners'
local logging = require 'please.logging'

---@tag please-commands

---@brief [[
--- When using a command which involves the build target which takes the current file as an input, there may be multiple
--- targets found if the file is referenced in multiple places. In such cases, you'll be prompted for which one to use.
--- This prompt uses |vim.ui.select()| which allows you to customise the appearance to your taste (see
--- https://github.com/stevearc/dressing.nvim and |lua-ui|).
---@brief ]]

local please = {}

local run_with_selected = function(options, prompt, func)
  if #options > 1 then
    vim.ui.select(options, { prompt = prompt }, function(selected)
      -- selected is nil if the input is cancelled
      if not selected then
        return
      end
      logging.log_errors(function()
        func(selected)
      end)
    end)
  else
    logging.log_errors(function()
      func(options[1])
    end)
  end
end

-- gets pkg name of BUILD file
local get_pkg = function(root, build_file_path)
  local pkg = Path:new(build_file_path):parent():make_relative(root)
  if pkg == '.' then
    pkg = ''
  end
  return pkg
end

---Jumps to the location of the build target which takes the current file as an input.
---
---The cursor will be moved to where the build target is created if it can be found which should be the case for all
---targets except for those with names which are generated when the BUILD file is executed.
please.jump_to_target = function()
  logging.debug 'please.jump_to_target called'

  logging.log_errors(function()
    local filepath = vim.fn.expand '%:p'
    if filepath == '' then
      return
    end
    local root = assert(query.reporoot(filepath))
    local labels = assert(query.whatinputs(root, filepath))
    run_with_selected(labels, 'Select target to jump to', function(label)
      local target_filepath, line, col = assert(parsing.locate_build_target(root, label))
      vim.cmd('edit ' .. target_filepath)
      vim.api.nvim_win_set_cursor(0, { line, col - 1 }) -- col is 0-indexed
    end)
  end)
end

---If the current file is a BUILD file, builds the target which is under the cursor. Otherwise, builds the target which
---takes the current file as an input.
please.build = function()
  logging.debug 'please.build called'

  logging.log_errors(function()
    local filepath = vim.fn.expand '%:p'
    if filepath == '' then
      return
    end

    local root = assert(query.reporoot(filepath))

    if vim.bo.filetype == 'please' then
      local pkg = get_pkg(root, filepath)
      local target = assert(parsing.get_target_at_cursor())
      local label = string.format('//%s:%s', pkg, target)
      runners.popup('plz', { '--repo_root', root, '--interactive_output', '--colour', 'build', label })
    else
      local labels = assert(query.whatinputs(root, filepath))
      run_with_selected(labels, 'Select target to build', function(label)
        runners.popup('plz', { '--repo_root', root, '--interactive_output', '--colour', 'build', label })
      end)
    end
  end)
end

---Tests the target which takes the current file as an input.
---
---Optionally, you can specify that only the test function which is under the cursor should be run. This is supported
---for the following languages:
---- Go
---  - regular go test functions (not subtests)
---  - testify suite test methods
---@param opts table
---@field under_cursor boolean: run only the test under the cursor
please.test = function(opts)
  logging.debug(string.format('please.test called with opts=%s', vim.inspect(opts)))

  opts = opts or {}

  logging.log_errors(function()
    local filepath = vim.fn.expand '%:p'
    if filepath == '' then
      return
    end
    local root = assert(query.reporoot(filepath))
    local labels = assert(query.whatinputs(root, filepath))

    if opts.under_cursor then
      local test_name = assert(parsing.get_test_at_cursor())
      run_with_selected(labels, 'Select target to test', function(label)
        runners.popup('plz', { '--repo_root', root, '--interactive_output', '--colour', 'test', label, test_name })
      end)
      return
    end

    run_with_selected(labels, 'Select target to test', function(label)
      runners.popup('plz', { '--repo_root', root, '--interactive_output', '--colour', 'test', label })
    end)
  end)
end

---Runs the target which takes the current file as an input.
please.run = function()
  logging.debug 'please.run called'

  logging.log_errors(function()
    local filepath = vim.fn.expand '%:p'
    if filepath == '' then
      return
    end
    local root = assert(query.reporoot(filepath))
    local labels = assert(query.whatinputs(root, filepath))
    run_with_selected(labels, 'Select target to test', function(label)
      runners.popup('plz', { '--repo_root', root, '--interactive_output', '--colour', 'run', label })
    end)
  end)
end

---Runs the test under the cursor in the target which takes the current file as an input.
please.test_under_cursor = function()
  logging.debug 'please.test_under_cursor called'

  logging.log_errors(function()
    local filepath = vim.fn.expand '%:p'
    if filepath == '' then
      return
    end
    local root = assert(query.reporoot(filepath))
    local labels = assert(query.whatinputs(root, filepath))
  end)
end

return please
