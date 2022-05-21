local Path = require 'plenary.path'
local query = require 'please.query'
local parsing = require 'please.parsing'
local runners = require 'please.runners'
local logging = require 'please.logging'
local cursor = require 'please.cursor'

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

local run_plz_cmd = function(root, ...)
  local args = { '--repo_root', root, '--interactive_output', '--colour', ... }
  logging.debug('running plz with args: %s', vim.inspect(args))
  runners.popup('plz', args)
end

local get_build_target_at_cursor = function(root, filepath)
  local pkg = get_pkg(root, filepath)
  local target, err = parsing.get_target_at_cursor()
  if err then
    return nil, err
  end
  return string.format('//%s:%s', pkg, target), nil
end

local get_filepath = function()
  local filepath = vim.fn.expand '%:p'
  if filepath == '' then
    return nil, 'no file open'
  end
  return filepath, nil
end

---Jumps to the location of the build target which takes the current file as an input.
---
---The cursor will be moved to where the build target is created if it can be found which should be the case for all
---targets except for those with names which are generated when the BUILD file is executed.
please.jump_to_target = function()
  logging.debug 'please.jump_to_target called'

  logging.log_errors(function()
    local filepath = assert(get_filepath())
    local root = assert(query.reporoot(filepath))
    local labels = assert(query.whatinputs(root, filepath))
    run_with_selected(labels, 'Select target to jump to', function(label)
      local target_filepath, position = assert(parsing.locate_build_target(root, label))
      logging.debug('opening %s at %s', target_filepath, vim.inspect(position))
      vim.cmd('edit ' .. target_filepath)
      cursor.set(position)
    end)
  end)
end

---If the current file is a BUILD file, builds the target which is under the cursor. Otherwise, builds the target which
---takes the current file as an input.
please.build = function()
  logging.debug 'please.build called'

  logging.log_errors(function()
    local filepath = assert(get_filepath())
    local root = assert(query.reporoot(filepath))

    if vim.bo.filetype == 'please' then
      local label = assert(get_build_target_at_cursor(root, filepath))
      run_plz_cmd(root, 'build', label)
    else
      local labels = assert(query.whatinputs(root, filepath))
      run_with_selected(labels, 'Select target to build', function(label)
        run_plz_cmd(root, 'build', label)
      end)
    end
  end)
end

---If the current file is a BUILD file, test the target which is under the cursor. Otherwise, test the target which
---takes the current file as an input.
---
---Optionally (when in a source file), you can specify that only the test function which is under the cursor should be
---run. This is supported for the following languages:
---- Go
---  - regular go test functions (not subtests)
---  - testify suite test methods
---- Python
---  - unittest test methods
---@param opts table
---@field under_cursor boolean: run only the test under the cursor
please.test = function(opts)
  logging.debug('please.test called with opts=%s', vim.inspect(opts))

  opts = opts or {}

  logging.log_errors(function()
    local filepath = assert(get_filepath())
    local root = assert(query.reporoot(filepath))

    if vim.bo.filetype == 'please' then
      local label = assert(get_build_target_at_cursor(root, filepath))
      run_plz_cmd(root, 'test', label)
    else
      local labels = assert(query.whatinputs(root, filepath))

      local test_args = {}
      if opts.under_cursor then
        local test_name = assert(parsing.get_test_at_cursor())
        test_args = { test_name }
      end

      run_with_selected(labels, 'Select target to test', function(label)
        run_plz_cmd(root, 'test', label, unpack(test_args))
      end)
    end
  end)
end

---If the current file is a BUILD file, run the target which is under the cursor. Otherwise, run the target which
---takes the current file as an input.
please.run = function()
  logging.debug 'please.run called'

  logging.log_errors(function()
    local filepath = assert(get_filepath())
    local root = assert(query.reporoot(filepath))

    if vim.bo.filetype == 'please' then
      local label = assert(get_build_target_at_cursor(root, filepath))
      run_plz_cmd(root, 'run', label)
    else
      local labels = assert(query.whatinputs(root, filepath))
      run_with_selected(labels, 'Select target to test', function(label)
        run_plz_cmd(root, 'run', label)
      end)
    end
  end)
end

local yank = function(txt)
  local registers = {
    unnamed = '"',
    star = '*',
  }
  for _, register in pairs(registers) do
    logging.debug('setting %s register to %s', register, txt)
    vim.fn.setreg(register, txt)
  end
  logging.info('yanked %s', txt)
end

---If the current file is a BUILD file, yank the label of the target which is under the cursor. Otherwise, yank the
---label of the target which takes the current file as an input.
please.yank = function()
  logging.debug 'please.yank called'

  logging.log_errors(function()
    local filepath = assert(get_filepath())
    local root = assert(query.reporoot(filepath))

    if vim.bo.filetype == 'please' then
      local label = assert(get_build_target_at_cursor(root, filepath))
      yank(label)
    else
      local labels = assert(query.whatinputs(root, filepath))
      run_with_selected(labels, 'Select target to test', function(label)
        yank(label)
      end)
    end
  end)
end

---Reload the plugin (for use in development).
please.reload = function()
  for pkg, _ in pairs(package.loaded) do
    if vim.startswith(pkg, 'please') then
      package.loaded[pkg] = nil
    end
  end
  logging.info 'reloaded plugin'
end

return please
