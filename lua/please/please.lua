local query = require 'please.query'
local parsing = require 'please.parsing'
local runners = require 'please.runners'
local logging = require 'please.logging'
local cursor = require 'please.cursor'
local debug = require 'please.debug'

---@tag please-commands

---@brief [[
--- Some commands may prompt you to choose between different options. For example, when building a file which is an
--- input to multiple build targets, you'll be prompted to choose which target to build. This prompt uses
--- |vim.ui.select()| which allows you to customise the appearance to your taste (see
--- https://github.com/stevearc/dressing.nvim and |lua-ui|).
---@brief ]]

local please = {}

local run_with_selected = function(items, prompt, func)
  if #items > 1 then
    local max_item_length = 0
    for _, item in ipairs(items) do
      max_item_length = math.max(#item, max_item_length)
    end
    local padding = 7
    local min_width = 80
    vim.ui.select(items, {
      prompt = prompt,
      telescope = {
        layout_config = {
          width = math.max(min_width, math.max(max_item_length, #prompt) + padding),
          height = 15,
        },
      },
    }, function(item, idx)
      -- selected is nil if the input is cancelled
      if not item then
        return
      end
      logging.log_errors(function()
        func(item, idx)
      end)
    end)
  else
    logging.log_errors(function()
      func(items[1], 1)
    end)
  end
end

-- validate that all opts are:
-- - one of valid_opts
-- - boolean
local validate_opts = function(opts, valid_opts)
  for opt, value in pairs(opts) do
    if not vim.tbl_contains(valid_opts, opt) then
      return false, string.format("'%s' is not a valid opt", opt)
    end
    if type(value) ~= 'boolean' then
      return false,
        string.format('invalid type (%s) for "%s" value %s, should be boolean', type(value), opt, vim.inspect(value))
    end
  end
  return true
end

local run_plz_cmd = function(root, args, opts)
  local cmd_args = { '--repo_root', root, '--interactive_output', '--colour', unpack(args) }
  logging.debug('running plz with args: %s', vim.inspect(cmd_args))
  runners.popup('plz', cmd_args, opts)
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
      local label = assert(parsing.get_target_at_cursor(root))
      run_plz_cmd(root, { 'build', label })
    else
      local labels = assert(query.whatinputs(root, filepath))
      run_with_selected(labels, 'Select target to build', function(label)
        run_plz_cmd(root, { 'build', label })
      end)
    end
  end)
end

---If the current file is a BUILD file, test the target which is under the cursor. Otherwise, test the target which
---takes the current file as an input.
---
---Optionally (when in a source file), you can run only a specific test. Either by running the test which is under the
---cursor or by choosing which test to run from a list of tests in the current file. This is supported for the following
---languages:
---- Go
---  - regular test functions (not subtests)
---  - testify suite test methods
---- Python
---  - unittest test methods
---@param opts table
---@field under_cursor boolean: run the test under the cursor
---@field list boolean: select which test to run
please.test = function(opts)
  logging.debug('please.test called with opts=%s', vim.inspect(opts))

  opts = opts or {}

  logging.log_errors(function()
    assert(validate_opts(opts, { 'under_cursor', 'list' }))

    local filepath = assert(get_filepath())
    local root = assert(query.reporoot(filepath))

    if vim.bo.filetype == 'please' then
      local label = assert(parsing.get_target_at_cursor(root))
      run_plz_cmd(root, { 'test', label })
    else
      local labels = assert(query.whatinputs(root, filepath))

      local run_plz_test = function(test_selector)
        local args = test_selector and { test_selector } or {}
        run_with_selected(labels, 'Select target to test', function(label)
          run_plz_cmd(root, { 'test', label, unpack(args) })
        end)
      end

      if opts.under_cursor then
        local test_selector = assert(parsing.get_test_selector_at_cursor())
        run_plz_test(test_selector)
      elseif opts.list then
        local tests = assert(parsing.list_tests_in_file())
        local test_names = vim.tbl_map(function(test)
          return test.name
        end, tests)
        run_with_selected(test_names, 'Select test to run', function(_, idx)
          run_plz_test(tests[idx].selector)
        end)
      else
        run_plz_test()
      end
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
      local label = assert(parsing.get_target_at_cursor(root))
      run_plz_cmd(root, { 'run', label })
    else
      local labels = assert(query.whatinputs(root, filepath))
      run_with_selected(labels, 'Select target to test', function(label)
        run_plz_cmd(root, { 'run', label })
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
  if vim.fn.exists ':OSCYankReg' == 2 then
    logging.debug 'calling :OSCYankReg "'
    vim.cmd 'OSCYankReg "'
  else
    logging.debug ':OSCYankReg does not exist'
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
      local label = assert(parsing.get_target_at_cursor(root))
      yank(label)
    else
      local labels = assert(query.whatinputs(root, filepath))
      run_with_selected(labels, 'Select target to test', function(label)
        yank(label)
      end)
    end
  end)
end

---If the current file is a BUILD file, debug the target which is under the cursor. Otherwise, debug the target which
---takes the current file as an input.
---
---Debug support is provided by https://github.com/mfussenegger/nvim-dap. This is supported for the following languages:
---- Go (Delve)
---- Python (debugpy)
please.debug = function()
  logging.debug 'please.debug called'

  logging.log_errors(function()
    local filepath = assert(get_filepath())
    local root = assert(query.reporoot(filepath))

    if vim.bo.filetype == 'please' then
      local label, rule = assert(parsing.get_target_at_cursor(root))
      local lang = rule:match '(%w+)_.+' -- assumes that rules will be formatted like $lang_xxx which feels pretty safe
      local launcher = debug.launchers[lang]
      run_plz_cmd(root, { 'build', '--config', 'dbg', label }, {
        on_success = function(close)
          close()
          launcher(root, label)
        end,
      })
    else
      local labels = assert(query.whatinputs(root, filepath))
      local launcher = debug.launchers[vim.bo.filetype]
      run_with_selected(labels, 'Select target to debug', function(label)
        run_plz_cmd(root, { 'build', '--config', 'dbg', label }, {
          on_success = function(close)
            close()
            launcher(root, label)
          end,
        })
      end)
    end
  end)
end

return please
