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
---  * Display history of previous commands and run any of them again
---  * Jump from a source file to its build target definition
---  * Yank a target's label
---  * `please` configured as the `filetype` for `BUILD`, `BUILD.plz`, and `*.build_defs`
---    files
---  * `ini` configured as the `filetype` for `.plzconfig` files to enable better
---    syntax highlighting
---  * Python tree-sitter parser configured to be used for please files to enable
---    better syntax highlighting and use of all tree-sitter features in build
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
---  vim.keymap.set('n', '<leader>pb', require('please').build)
---  vim.keymap.set('n', '<leader>pr', require('please').run)
---  vim.keymap.set('n', '<leader>pt', require('please').test)
---  vim.keymap.set('n', '<leader>pct', function()
---    require('please').test({ under_cursor = true })
---  end)
---  vim.keymap.set('n', '<leader>pd', require('please').debug)
---  vim.keymap.set('n', '<leader>pcd', function()
---    require('please').debug({ under_cursor = true })
---  end)
---  vim.keymap.set('n', '<leader>ph', require('please').history)
---  vim.keymap.set('n', '<leader>pm', require('please').maximise_popup)
---  vim.keymap.set('n', '<leader>pj', require('please').jump_to_target)
---  vim.keymap.set('n', '<leader>py', require('please').yank)
---<
---@brief ]]

---@mod please PLEASE COMMANDS

local query = require('please.query')
local parsing = require('please.parsing')
local Runner = require('please.Runner')
local logging = require('please.logging')
local debug = require('please.debug')

local please = {}

local current_runner ---@type please.Runner?

local function new_runner(root, args)
  local runner = Runner:new(root, args)
  if current_runner then
    current_runner:stop()
    current_runner:minimise()
  end
  current_runner = runner
  return runner
end

local data_path = vim.fn.stdpath('data')
---@cast data_path string
local command_history_path = vim.fs.joinpath(data_path, 'please-command-history.json')

---@return table<string, please.Command[]>
local function read_command_history()
  if not vim.uv.fs_stat(command_history_path) then
    return {}
  end
  local f = assert(io.open(command_history_path))
  local history_text = assert(f:read('*a'))
  local history = vim.json.decode(history_text) or {}
  assert(f:close())
  return history
end

---@param history table<string, any>
local function write_command_history(history)
  if not vim.uv.fs_stat(data_path) then
    vim.fn.mkdir(data_path, 'p')
  end
  local f = assert(io.open(command_history_path, 'w'))
  assert(f:write(vim.json.encode(history)))
  assert(f:close())
end

---@private
---@class please.Command
---@field type 'simple' | 'debug'
---@field args table
---@field description string
---@field opts table<string, string>

---@param root string
---@param command please.Command
local function save_command(root, command)
  local history = read_command_history()
  if history[root] then
    history[root] = vim
      .iter(history[root])
      :filter(function(history_item)
        return history_item.description ~= command.description
      end)
      :totable()
  else
    history[root] = {}
  end
  table.insert(history[root], 1, command)
  write_command_history(history)
end

---@param root string
---@param args string[]
local function run_simple_command(root, args)
  new_runner(root, args):start()
end

---@param root string
---@param args string[]
local function save_and_run_simple_command(root, args)
  save_command(root, {
    type = 'simple',
    args = args,
    description = 'plz ' .. table.concat(args, ' '),
    opts = {},
  })
  run_simple_command(root, args)
end

---Wrapper around vim.ui.select which:
---- sets a width for the telescope popup which will fit all of the provided items
---- handles input cancellation
---- wraps on_choice in logging.log_errors
---@generic T any
---@param items T[]
---@param opts table
---@param on_choice fun(item: T)
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
  local root = vim.fs.root(path, '.plzconfig')
  if root then
    return root
  end
  return nil, "Couldn't locate the repo root. Are you sure you're inside a plz repo?"
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
      save_and_run_simple_command(root, { 'build', label })
    end)
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
        input = vim.trim(input)
        if input ~= '' then
          args = { '--', unpack(vim.split(input, ' ')) }
        end
        save_and_run_simple_command(root, { 'run', label, unpack(args) })
      end)
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

    vim.validate({
      opts = { opts, 'table' },
      under_cursor = { opts.under_cursor, 'boolean', true },
    })

    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

    local labels = {} ---@type string[]
    local extra_args = {} ---@type string[]
    if opts.under_cursor then
      local test = assert(parsing.get_test_at_cursor())
      extra_args = { test.selector }
      labels = assert(query.whatinputs(root, filepath))
    else
      if vim.bo.filetype == 'please' then
        local label = assert(parsing.get_target_at_cursor(root))
        labels = { label }
      else
        labels = assert(query.whatinputs(root, filepath))
      end
    end

    select_if_many(labels, { prompt = 'Select target to test' }, function(label)
      save_and_run_simple_command(root, { 'test', label, unpack(extra_args) })
    end)
  end)
end

---@param root string
---@param lang string
---@param args string[]
local function run_debug_command(root, lang, args)
  local launcher = debug.launchers[lang]
  local label = args[2] -- args = { 'debug', label, ... }
  local runner = new_runner(root, { 'build', '--config', 'dbg', label })
  runner:on_success(function()
    runner:minimise()
    logging.log_errors('Failed to debug', function()
      assert(launcher(root, label))
    end)
  end)
  runner:start()
end

---@param root string
---@param lang string
---@param args string[]
local function save_and_run_debug_command(root, lang, args)
  save_command(root, {
    type = 'debug',
    args = args,
    description = 'plz ' .. table.concat(args, ' '),
    opts = { lang = lang },
  })
  run_debug_command(root, lang, args)
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

    vim.validate({
      opts = { opts, 'table' },
      under_cursor = { opts.under_cursor, 'boolean', true },
    })

    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

    local labels = {} ---@type string[]
    local lang = '' ---@type string
    local extra_args = {} ---@type string[]
    if opts.under_cursor then
      local test = assert(parsing.get_test_at_cursor())
      extra_args = { test.selector }
      labels = assert(query.whatinputs(root, filepath))
      lang = vim.bo.filetype
    else
      if vim.bo.filetype == 'please' then
        local label, rule = assert(parsing.get_target_at_cursor(root))
        labels = { label }
        lang = rule:match('(%w+)_.+') -- assumes that rules will be formatted like $lang_xxx
      else
        labels = assert(query.whatinputs(root, filepath))
        lang = vim.bo.filetype
      end
    end

    if not debug.launchers[lang] then
      error(string.format('debugging is not supported for %s files', lang))
    end

    select_if_many(labels, { prompt = 'Select target to debug' }, function(label)
      save_and_run_debug_command(root, lang, { 'debug', label, unpack(extra_args) })
    end)
  end)
end

---Run an arbitrary plz command and display the output in a popup.
---@param ... string Arguments to pass to plz
---@usage [[
---local please = require('please')
---please.command('build', '//foo/bar/...')
---@usage ]]
function please.command(...)
  logging.log_call('please.command')

  local args = { ... }
  logging.log_errors('Failed to run command', function()
    local path = get_filepath() or assert(vim.uv.cwd())
    local root = assert(get_repo_root(path))
    save_and_run_simple_command(root, args)
  end)
end

---Display a history of previous commands. Selecting one of them will run it
---again.
function please.history()
  logging.log_call('please.history')

  logging.log_errors('Failed to show command history', function()
    local path = get_filepath() or assert(vim.uv.cwd())
    local root = assert(get_repo_root(path))

    local history = read_command_history()
    if not history[root] then
      logging.error('command history is empty for repo ' .. root)
      return
    end

    local function get_description(command)
      return command.description
    end
    select(history[root], { prompt = 'Pick command to run again', format_item = get_description }, function(command)
      if command.type == 'simple' then
        save_and_run_simple_command(root, command.args)
      elseif command.type == 'debug' then
        save_and_run_debug_command(root, command.opts.lang, command.args)
      else
        error('unknown command type ' .. command.type)
      end
    end)
  end)
end

---@private
function please.action_history()
  vim.deprecate('please.action_history', 'please.history', 'v1.0.0', 'please.nvim')
  please.history()
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
      vim.cmd('edit ' .. target_filepath)
      vim.api.nvim_win_set_cursor(0, position)
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
      local registers = { '"', '*' }
      for _, register in ipairs(registers) do
        logging.debug('setting %s register to %s', register, label)
        vim.fn.setreg(register, label)
      end
      logging.info('yanked %s', label)
    end)
  end)
end

return please
