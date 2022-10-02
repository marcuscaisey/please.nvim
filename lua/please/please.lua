local Path = require('plenary.path')
local query = require('please.query')
local parsing = require('please.parsing')
local runners = require('please.runners')
local logging = require('please.logging')
local cursor = require('please.cursor')
local debug = require('please.debug')

---@tag please-commands

---@brief [[
--- Some commands may prompt you to choose between different options. For example, when building a file which is an
--- input to multiple build targets, you'll be prompted to choose which target to build. This prompt uses
--- |vim.ui.select()| which allows you to customise the appearance to your taste (see
--- https://github.com/stevearc/dressing.nvim and |lua-ui|).
---@brief ]]

local please = {}

local run_plz_cmd = function(root, args, opts)
  local cmd_args = { '--repo_root', root, '--interactive_output', '--colour', unpack(args) }
  logging.debug('running plz with args: %s', vim.inspect(cmd_args))
  runners.popup('plz', cmd_args, opts)
end

local actions = {
  jump_to_target = function(filepath, position)
    vim.cmd('edit ' .. filepath)
    cursor.set(position)
  end,
  build = function(root, label)
    run_plz_cmd(root, { 'build', label })
  end,
  test = function(root, label)
    run_plz_cmd(root, { 'test', label })
  end,
  test_selector = function(root, label, test_selector)
    run_plz_cmd(root, { 'test', label, test_selector })
  end,
  test_failed = function(root)
    run_plz_cmd(root, { 'test', '--failed' })
  end,
  run = function(root, label, args)
    run_plz_cmd(root, { 'run', label, '--', unpack(args) })
  end,
  yank = function(txt)
    local registers = {
      unnamed = '"',
      star = '*',
    }
    for _, register in pairs(registers) do
      logging.debug('setting %s register to %s', register, txt)
      vim.fn.setreg(register, txt)
    end
    if vim.fn.exists(':OSCYankReg') == 2 then
      logging.debug('calling :OSCYankReg "')
      vim.api.nvim_cmd({ cmd = 'OSCYankReg', args = { '"' } }, {})
    else
      logging.debug(':OSCYankReg does not exist')
    end
    logging.info('yanked %s', txt)
  end,
  debug = function(root, label, lang)
    local launcher = debug.launchers[lang] -- FIXME: error if this is nil
    run_plz_cmd(root, { 'build', '--config', 'dbg', label }, {
      on_success = function(close)
        close()
        launcher(root, label)
      end,
    })
  end,
}

local action_history_path = Path:new(vim.fn.stdpath('data'), 'please-history.json')

local read_action_history = function()
  return action_history_path:exists() and vim.json.decode(action_history_path:read()) or {}
end

local write_action_history = function(history)
  action_history_path:write(vim.json.encode(history), 'w')
end

---@class Action
---@field name string: the name of the action to run
---@field args table: the args to pass to the action
---@field description string: the text which will be shown for this action in the history

---Run the given action and save it at the top of the action history for the given root. If an action with the same
---description is already in the action history for the given root, then it will moved to the top.
---@param root string: an absolute path to the repo root
---@param action Action: the action to run
local run_and_save_action = function(root, action)
  local history = read_action_history()
  if history[root] then
    history[root] = vim.tbl_filter(function(history_item)
      return history_item.description ~= action.description
    end, history[root])
  else
    history[root] = {}
  end
  table.insert(history[root], 1, action)
  write_action_history(history)
  actions[action.name](unpack(action.args))
end

---Wrapper around vim.ui.select which:
---- sets a width for the telescope popup which will fit all of the provided items
---- handles input cancellation
---- wraps on_choice in logging.log_errors
local select = function(items, opts, on_choice)
  local max_item_length = 0
  local format_item = opts.format_item or tostring
  for _, item in ipairs(items) do
    max_item_length = math.max(#format_item(item), max_item_length)
  end
  local padding = 7
  local min_width = 80
  opts.prompt = opts.prompt or 'Select one of:'
  opts.telescope = {
    layout_config = {
      width = math.max(min_width, math.max(max_item_length, #opts.prompt) + padding),
      height = 15,
    },
  }
  vim.ui.select(items, opts, function(item)
    -- item is nil if the input is cancelled
    if not item then
      return
    end
    logging.log_errors(on_choice)(item)
  end)
end

---Call select if there is more than one item, otherwise call on_choice with the singular item.
local select_if_many = function(items, opts, on_choice)
  if #items > 1 then
    select(items, opts, on_choice)
  else
    logging.log_errors(on_choice)(items[1])
  end
end

---Validate that all opts are:
---- one of valid_opts
---- boolean
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

local get_filepath = function()
  local filepath = vim.fn.expand('%:p')
  if filepath == '' then
    return nil, 'no file open'
  end
  return filepath, nil
end

---Jumps to the location of the build target which takes the current file as an input.
---
---The cursor will be moved to where the build target is created if it can be found which should be the case for all
---targets except for those with names which are generated when the BUILD file is executed.
please.jump_to_target = logging.log_errors(function()
  logging.debug('please.jump_to_target called')

  local filepath = assert(get_filepath())
  local root = assert(query.reporoot(filepath))
  local labels = assert(query.whatinputs(root, filepath))
  select_if_many(labels, { prompt = 'Select target to jump to' }, function(label)
    local target_filepath, position = assert(parsing.locate_build_target(root, label))
    logging.debug('opening %s at %s', target_filepath, vim.inspect(position))
    run_and_save_action(root, {
      name = 'jump_to_target',
      args = { target_filepath, position },
      description = 'Jump to ' .. label,
    })
  end)
end, 'Failed to jump to target')

---If the current file is a BUILD file, builds the target which is under the cursor. Otherwise, builds the target which
---takes the current file as an input.
please.build = logging.log_errors(function()
  logging.debug('please.build called')

  local filepath = assert(get_filepath())
  local root = assert(query.reporoot(filepath))

  local labels
  if vim.bo.filetype == 'please' then
    local label = assert(parsing.get_target_at_cursor(root))
    labels = { label }
  else
    labels = assert(query.whatinputs(root, filepath))
  end

  select_if_many(labels, { prompt = 'Select target to build' }, function(label)
    run_and_save_action(root, {
      name = 'build',
      args = { root, label },
      description = 'Build ' .. label,
    })
  end)
end, 'Failed to build')

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
---@field failed boolean: run just the test cases which failed from the immediately previous run
please.test = logging.log_errors(function(opts)
  logging.debug('please.test called with opts=%s', vim.inspect(opts))

  opts = opts or {}

  assert(validate_opts(opts, { 'under_cursor', 'list', 'failed' }))

  local filepath = assert(get_filepath())
  local root = assert(query.reporoot(filepath))

  if opts.under_cursor or opts.list then
    local tests
    if opts.under_cursor then
      tests = { assert(parsing.get_test_at_cursor()) }
    elseif opts.list then
      tests = assert(parsing.list_tests_in_file())
    end
    local get_test_name = function(test)
      return test.name
    end
    local labels = assert(query.whatinputs(root, filepath))
    select_if_many(tests, { prompt = 'Select test to run', format_item = get_test_name }, function(test)
      select_if_many(labels, { prompt = 'Select target to test' }, function(label)
        run_and_save_action(root, {
          name = 'test_selector',
          args = { root, label, test.selector },
          description = string.format('Test %s (%s)', label, test.name),
        })
      end)
    end)
  elseif opts.failed then
    run_and_save_action(root, {
      name = 'test_failed',
      args = { root },
      description = 'Run previously failed tests',
    })
  else
    local labels
    if vim.bo.filetype == 'please' then
      local label = assert(parsing.get_target_at_cursor(root))
      labels = { label }
    else
      labels = assert(query.whatinputs(root, filepath))
    end
    select_if_many(labels, { prompt = 'Select target to test' }, function(label)
      run_and_save_action(root, {
        name = 'test',
        args = { root, label },
        description = 'Test ' .. label,
      })
    end)
  end
end, 'Failed to test')

---If the current file is a BUILD file, run the target which is under the cursor. Otherwise, run the target which
---takes the current file as an input. Program arguments can be entered via a |vim.ui.input()| prompt which allows you
---to customise the appearance to your taste (see https://github.com/stevearc/dressing.nvim and |lua-ui|).
please.run = logging.log_errors(function()
  logging.debug('please.run called')

  local filepath = assert(get_filepath())
  local root = assert(query.reporoot(filepath))

  local labels
  if vim.bo.filetype == 'please' then
    local label = assert(parsing.get_target_at_cursor(root))
    labels = { label }
  else
    labels = assert(query.whatinputs(root, filepath))
  end

  select_if_many(labels, { prompt = 'Select target to run' }, function(label)
    vim.ui.input({ prompt = 'Enter program arguments' }, function(input)
      local args = {}
      if input then
        args = vim.split(input, ' ')
      end
      run_and_save_action(root, {
        name = 'run',
        args = { root, label, args },
        description = string.format('Run %s (%s)', label, table.concat(args, ' ')),
      })
    end)
  end)
end, 'Failed to run')

---If the current file is a BUILD file, yank the label of the target which is under the cursor. Otherwise, yank the
---label of the target which takes the current file as an input.
please.yank = logging.log_errors(function()
  logging.debug('please.yank called')

  local filepath = assert(get_filepath())
  local root = assert(query.reporoot(filepath))

  local labels = {}
  if vim.bo.filetype == 'please' then
    local label = assert(parsing.get_target_at_cursor(root))
    labels = { label }
  else
    labels = assert(query.whatinputs(root, filepath))
  end

  select_if_many(labels, { prompt = 'Select label to yank' }, function(label)
    run_and_save_action(root, {
      name = 'yank',
      args = { label },
      description = 'Yank ' .. label,
    })
  end)
end, 'Failed to yank')

---If the current file is a BUILD file, debug the target which is under the cursor. Otherwise, debug the target which
---takes the current file as an input.
---
---Debug support is provided by https://github.com/mfussenegger/nvim-dap. This is supported for the following languages:
---- Go (Delve)
---- Python (debugpy)
please.debug = logging.log_errors(function()
  logging.debug('please.debug called')

  local filepath = assert(get_filepath())
  local root = assert(query.reporoot(filepath))

  local labels, lang
  if vim.bo.filetype == 'please' then
    local label, rule = assert(parsing.get_target_at_cursor(root))
    labels = { label }
    lang = rule:match('(%w+)_.+') -- assumes that rules will be formatted like $lang_xxx which feels pretty safe
  else
    labels = assert(query.whatinputs(root, filepath))
    lang = vim.bo.filetype
  end

  select_if_many(labels, { prompt = 'Select target to debug' }, function(label)
    run_and_save_action(root, {
      name = 'debug',
      args = { root, label, lang },
      description = 'Debug ' .. label,
    })
  end)
end, 'Failed to debug')

---List the previous actions which you have run, ordered from most to least recent. You can rerun any of any action by
---selecting it.
please.action_history = logging.log_errors(function()
  logging.debug('please.action_history called')

  local cwd = get_filepath() or vim.loop.cwd()
  local root = assert(query.reporoot(cwd))

  local history = read_action_history()
  if not history[root] then
    logging.error('action history is empty for repo ' .. root)
    return
  end

  local get_description = function(history_item)
    return history_item.description
  end
  select(history[root], { prompt = 'Pick action to run again', format_item = get_description }, function(history_item)
    run_and_save_action(root, history_item)
  end)
end, 'Failed to show action history')

return please
