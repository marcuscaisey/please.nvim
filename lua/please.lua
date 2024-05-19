---@brief [[
---*please.nvim*
---A plugin to make you more productive in Neovim when using Please.
---@brief ]]

---@toc please-contents

---@mod please-intro INTRODUCTION
---@brief [[
---please.nvim is a plugin which allows you interact with your Please repository
---from the comfort of Neovim. The aim is to remove the need to switch from your
---editor to the shell when performing routine actions.
---
---Features ~
---  * Build, run, test, and debug a target
---  * Yank a target's label
---  * Jump from a source file to its build target definition
---  * Display history of previous actions and run any of them again
---  * `please` configured as the `filetype` for `BUILD`, `BUILD.plz`, and `*.build_defs`
---    files
---  * `ini` configured as the `filetype` for `.plzconfig` files to enable better
---    syntax highlighting
---  * Python tree-sitter parser configured to be used for please files to enable
---    better syntax highlighting and use of all treesitter features in build
---    files
---@brief ]]

---@mod please-usage USAGE
---@brief [[
---Lua and VimL APIs ~
---please.nvim commands can be called either through the Lua or the VimL API.
---  * Commands are written in Lua and as such the Lua API should be preferred.
---    It can't be guaranteed that all features available through the Lua API
---    will also available through the VimL API.
---  * The VimL API is mostly provided to make it easy to call commands from the
---    command line.
---
---To use the Lua API, you need to import the required module which will usually
---be `please`. For instance, `jump_to_target` is executed with
---`require('please').jump_to_target()`
---
---All available VimL API commands are autocompletable as arguments to the
---`:Please` command. For instance, `jump_to_target` is executed with
---`:Please jump_to_target`
---
---UI Customisation ~
---Some commands may prompt you to either choose from a list of options or input
---some text. For example, when building a file which is an input to multiple
---build targets, you'll be prompted to choose which target to build.
---
---Input and selection prompts are provided by |vim.ui.input()| and
---|vim.ui.select()| respectively. Doing so allows you to customise the
---appearance of them to your taste. See |lua-ui| and the fantastic
---https://github.com/stevearc/dressing.nvim for more information.
---@brief ]]

---@mod please-mappings MAPPINGS
---@brief [[
---please.nvim doesn't come with any mappings defined out of the box so that you
---can customise how you use it. Below are a set of mappings for each available
---command to get you started.
--->lua
---  vim.keymap.set('n', '<leader>pj', require('please').jump_to_target)
---  vim.keymap.set('n', '<leader>pb', require('please').build)
---  vim.keymap.set('n', '<leader>pt', require('please').test)
---  vim.keymap.set('n', '<leader>pct', function()
---    require('please').test({ under_cursor = true })
---  end)
---  vim.keymap.set('n', '<leader>pr', require('please').run)
---  vim.keymap.set('n', '<leader>py', require('please').yank)
---  vim.keymap.set('n', '<leader>pd', require('please').debug)
---  vim.keymap.set('n', '<leader>pcd', function()
---    require('please').debug({ under_cursor = true })
---  end)
---  vim.keymap.set('n', '<leader>pa', require('please').action_history)
---  vim.keymap.set('n', '<leader>pm', require('please').maximise_popup)
---<
---@brief ]]

---@mod please PLEASE COMMANDS

local query = require('please.query')
local parsing = require('please.parsing')
local Runner = require('please.Runner')
local logging = require('please.logging')
local future = require('please.future')
local debug = require('please.debug')

local please = {}

local current_runner ---@type please.Runner?

local function new_runner(root, args)
  local runner = Runner:new(root, args)
  if current_runner then
    current_runner:stop()
  end
  current_runner = runner
  return runner
end

-- TODO: There must be a better way of organising these. It's quite annoying how the action logic for each command is
-- not directly referenced in each function, only indirectly through run_and_save_action. Maybe we should just extract
-- out each action and reference them from both this table and the associated command function.
local actions = {
  jump_to_target = function(filepath, position)
    vim.cmd('edit ' .. filepath)
    vim.api.nvim_win_set_cursor(0, position)
  end,
  build = function(root, label)
    new_runner(root, { 'build', label }):start()
  end,
  test = function(root, label)
    new_runner(root, { 'test', label }):start()
  end,
  test_selector = function(root, label, test_selector)
    new_runner(root, { 'test', label, test_selector }):start()
  end,
  run = function(root, label, args)
    if #args > 0 then
      args = { '--', unpack(args) }
    end
    new_runner(root, { 'run', label, unpack(args) }):start()
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
    local runner = new_runner(root, { 'build', '--config', 'dbg', label })
    runner:on_success(function()
      runner:minimise()
      logging.log_errors('Failed to debug', function()
        assert(launcher(root, label))
      end)
    end)
    runner:start()
  end,
  debug_selector = function(root, label, lang, test_selector)
    local launcher = debug.launchers[lang] -- FIXME: error if this is nil
    local runner = new_runner(root, { 'build', '--config', 'dbg', label })
    runner:on_success(function()
      runner:minimise()
      launcher(root, label, test_selector)
    end)
    runner:start()
  end,
}

local data_path = vim.fn.stdpath('data')
---@cast data_path string
local action_history_path = future.vim.fs.joinpath(data_path, 'please-history.json')

---@return table<string, any>
local function read_action_history()
  if not future.vim.uv.fs_stat(action_history_path) then
    return {}
  end
  local f = assert(io.open(action_history_path))
  local history_text = assert(f:read('*a'))
  local history = vim.json.decode(history_text) or {}
  assert(f:close())
  return history
end

---@param history table<string, any>
local function write_action_history(history)
  if not future.vim.uv.fs_stat(data_path) then
    vim.fn.mkdir(data_path, 'p')
  end
  local f = assert(io.open(action_history_path, 'w'))
  assert(f:write(vim.json.encode(history)))
  assert(f:close())
end

---@private
---@class Action
---@field name string: the name of the action to run
---@field args table: the args to pass to the action
---@field description string: the text which will be shown for this action in the history

---Run the given action and save it at the top of the action history for the given root. If an action with the same
---description is already in the action history for the given root, then it will moved to the top.
---@param root string: an absolute path to the repo root
---@param action Action: the action to run
local function run_and_save_action(root, action)
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
local function select(items, opts, on_choice)
  local max_item_length = 0
  local format_item = opts.format_item or tostring
  for _, item in ipairs(items) do
    max_item_length = math.max(#format_item(item), max_item_length)
  end
  local padding = 7
  local min_width = 80
  local min_height = 15
  opts.prompt = opts.prompt or 'Select one of:'
  opts.telescope = {
    layout_config = {
      width = math.max(min_width, math.max(max_item_length, #opts.prompt) + padding),
      height = math.max(#items, min_height) + 5,
    },
  }
  vim.ui.select(items, opts, function(item)
    -- item is nil if the input is cancelled
    if not item then
      return
    end
    on_choice(item)
  end)
end

---Call select if there is more than one item, otherwise call on_choice with the singular item.
local function select_if_many(items, opts, on_choice)
  if #items > 1 then
    select(items, opts, on_choice)
  else
    on_choice(items[1])
  end
end

---Validate that all opts are:
---- one of valid_opts
---- boolean
local function validate_opts(opts, valid_opts)
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

local function get_filepath()
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == '' then
    return nil, 'no file open'
  end
  return filepath, nil
end

---@param path string
---@return string?
---@return string?
local function get_repo_root(path)
  local root = future.vim.fs.root(path, '.plzconfig')
  if root then
    return root
  end
  return nil, "Couldn't locate the repo root. Are you sure you're inside a plz repo?"
end

---Jumps to the location of the build target which takes the current file as
---an input.
---
---The cursor will be moved to where the build target is created if it can be
---found which should be the case for all targets except for those with names
---which are generated when the `BUILD` file is executed.
function please.jump_to_target()
  logging.log_call('please.jump_to_target')

  logging.log_errors('Failed to jump to target', function()
    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))
    local labels = assert(query.whatinputs(root, filepath))
    select_if_many(labels, { prompt = 'Select target to jump to' }, function(label)
      local target_filepath, position = assert(parsing.locate_build_target(root, label))
      logging.debug('opening %s at %s', target_filepath, vim.inspect(position))
      run_and_save_action(root, {
        name = 'jump_to_target',
        args = { target_filepath, { position[1], position[2] } },
        description = 'Jump to ' .. label,
      })
    end)
  end)
end

---If the current file is a `BUILD` file, builds the target which is under
---the cursor. Otherwise, builds the target which takes the current file as
---an input.
function please.build()
  logging.log_call('please.build')

  logging.log_errors('Failed to build', function()
    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

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
  end)
end

---If the current file is a `BUILD` file, test the target which is under the
---cursor. Otherwise, test the target which takes the current file as an
---input.
---
---Optionally (when in a source file), you can run only the test which is
---under the cursor.
---This is supported for the following languages:
---- Go
---  - test functions
---  - subtests
---  - table tests
---  - testify suite methods
---  - testify suite subtests
---  - testify suite table tests
---- Python
---  - unittest test classes
---  - unittest test methods
---@param opts table|nil available options
---  * {under_cursor} (boolean): run the test under the cursor
function please.test(opts)
  logging.log_call('please.test')

  logging.log_errors('Failed to test', function()
    opts = opts or {}

    assert(validate_opts(opts, { 'under_cursor' }))

    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

    if opts.under_cursor then
      local test = assert(parsing.get_test_at_cursor())
      local labels = assert(query.whatinputs(root, filepath))
      select_if_many(labels, { prompt = 'Select target to test' }, function(label)
        run_and_save_action(root, {
          name = 'test_selector',
          args = { root, label, test.selector },
          description = string.format('Test %s %s', label, test.name),
        })
      end)
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
  end)
end

---If the current file is a `BUILD` file, run the target which is under the
---cursor. Otherwise, run the target which takes the current file as an
---input.
function please.run()
  logging.log_call('please.run')

  logging.log_errors('Failed to run', function()
    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

    local labels
    if vim.bo.filetype == 'please' then
      local label = assert(parsing.get_target_at_cursor(root))
      labels = { label }
    else
      labels = assert(query.whatinputs(root, filepath))
    end

    select_if_many(labels, { prompt = 'Select target to run' }, function(label)
      vim.ui.input({ prompt = 'Enter program arguments' }, function(input)
        if not input then
          return
        end
        local args = {}
        -- vim.ui.input passes empty input as an empty string instead of nil, I think this is a bug so just check for both to be safe.
        if input and input ~= '' then
          args = vim.split(input, ' ')
        end
        local description = 'Run ' .. label
        if #args > 0 then
          description = description .. ' ' .. input
        end
        run_and_save_action(root, {
          name = 'run',
          args = { root, label, args },
          description = description,
        })
      end)
    end)
  end)
end

---If the current file is a `BUILD` file, yank the label of the target which is
---under the cursor. Otherwise, yank the label of the target which takes the
---current file as an input.
function please.yank()
  logging.log_call('please.yank')

  logging.log_errors('Failed to yank', function()
    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

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
  end)
end

---If the current file is a `BUILD` file, debug the target which is under the
---cursor. Otherwise, debug the target which takes the current file as an
---input.
---
---Debug support is provided by https://github.com/mfussenegger/nvim-dap.
---This is supported for the following languages:
---- Go (Delve)
---- Python (debugpy)
---
---Optionally (when in a source file), you can debug only the test which is
---under the cursor. The supported languages and test types are the same as
---for the `please.test`.
---@param opts table|nil available options
---  * {under_cursor} (boolean): debug the test under the cursor
function please.debug(opts)
  logging.log_call('please.debug')

  logging.log_errors('Failed to debug', function()
    opts = opts or {}
    assert(validate_opts(opts, { 'under_cursor' }))

    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

    if opts.under_cursor then
      local test = assert(parsing.get_test_at_cursor())
      local labels = assert(query.whatinputs(root, filepath))
      local lang = vim.bo.filetype
      select_if_many(labels, { prompt = 'Select target to debug' }, function(label)
        run_and_save_action(root, {
          name = 'debug_selector',
          args = { root, label, lang, test.selector },
          description = string.format('Debug %s %s', label, test.name),
        })
      end)
    else
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
    end
  end)
end

---Display a history of previous actions. Selecting one of them will run it
---again.
function please.action_history()
  logging.log_call('please.action_history')

  logging.log_errors('Failed to show action history', function()
    local cwd = get_filepath() or assert(future.vim.uv.cwd())
    local root = assert(get_repo_root(cwd))

    local history = read_action_history()
    if not history[root] then
      logging.error('action history is empty for repo ' .. root)
      return
    end

    local function get_description(history_item)
      return history_item.description
    end
    select(history[root], { prompt = 'Pick action to run again', format_item = get_description }, function(history_item)
      run_and_save_action(root, history_item)
    end)
  end)
end

---Maximises the popup which was most recently quit or minimised.
function please.maximise_popup()
  logging.log_call('please.maximise_popup')
  if current_runner then
    current_runner:maximise()
  else
    logging.error('no popup to maximise')
  end
end

return please
