local require_on_index = require

---@param modname string
---@return unknown
function require_on_index(modname)
  return setmetatable({}, {
    __index = function(_, k)
      return require(modname)[k]
    end,
  })
end

local query = require_on_index('please.query')
local parsing = require_on_index('please.parsing')
local Runner = require_on_index('please.Runner')
local logging = require_on_index('please.logging')
local debug = require_on_index('please.debug')

local M = {}

---@nodoc
---@class please.Config
---@field max_history_items integer The maximum number of history items to store for each repository.

---@type please.Config
local config = {
  max_history_items = 20,
}

---@inlinedoc
---@class please.Opts
---@field max_history_items integer? The maximum number of history items to store for each repository.

---Updates the configuration with the provided {opts}. Should only be called if you want to change the defaults which
---are shown below.
---
---Example:
---```lua
---local please = require('please')
---please.setup({
---   max_history_items = 20,
---})
---```
---@param opts please.Opts
function M.setup(opts)
  vim.validate('opts', opts, 'table')
  vim.validate('opts.max_history_items', opts.max_history_items, 'number', true)
  config = vim.tbl_deep_extend('force', config, opts)
end

local default_profile = os.getenv('PLZ_CONFIG_PROFILE')

---@type table<string, string?>
local profiles_by_root = setmetatable({}, {
  __index = function()
    return default_profile
  end,
})

local current_runner ---@type please.Runner?

---@param root string
---@param args string[]
---@param opts please.RunnerOpts?
local function start_runner(root, args, opts)
  local profile = profiles_by_root[root]
  if profile then
    table.insert(args, 1, '--profile')
    table.insert(args, 2, profile)
  end
  if current_runner then
    current_runner:destroy()
  end
  current_runner = Runner.start(root, args, opts)
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

---@nodoc
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
      :take(config.max_history_items - 1)
      :totable()
  else
    history[root] = {}
  end
  table.insert(history[root], 1, command)
  write_command_history(history)
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
  start_runner(root, args)
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

---If the current file is a `BUILD` file, builds the target which is under the cursor. Otherwise, builds the target
---which takes the current file as an input.
function M.build()
  logging.log_call('please.build')

  logging.log_errors('Failed to build', function()
    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

    local labels
    if vim.bo.filetype == 'please' then
      local target = assert(parsing.get_target_at_cursor(root))
      labels = { target.label }
    else
      labels = assert(query.whatinputs(root, filepath))
    end

    select_if_many(labels, { prompt = 'Select target to build' }, function(label)
      save_and_run_simple_command(root, { 'build', label })
    end)
  end)
end

---If the current file is a `BUILD` file, run the target which is under the cursor. Otherwise, run the target which
---takes the current file as an input.
function M.run()
  logging.log_call('please.run')

  logging.log_errors('Failed to run', function()
    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

    local labels
    if vim.bo.filetype == 'please' then
      local target = assert(parsing.get_target_at_cursor(root))
      labels = { target.label }
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

---@class please.TestOptions
---@inlinedoc
---@field under_cursor boolean run the test under the cursor

---If the current file is a `BUILD` file, test the target which is under the cursor. Otherwise, test the target which
---takes the current file as an input.
---
---Optionally (when in a source file), you can run only the test which is under the cursor.
---This is supported for the following languages:
---- Go - test functions, subtests, table tests, testify suite methods, testify suite subtests, testify suite table
---  tests
---- Python - unittest test classes, unittest test methods
---@param opts please.TestOptions? optional keyword arguments
function M.test(opts)
  logging.log_call('please.test')

  logging.log_errors('Failed to test', function()
    opts = opts or {}

    vim.validate('opts', opts, 'table')
    vim.validate('opts.under_cursor', opts.under_cursor, 'boolean', true)

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
        local target = assert(parsing.get_target_at_cursor(root))
        labels = { target.label }
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
  start_runner(root, { 'build', '--config', 'dbg', label }, {
    on_success = function(runner)
      runner:minimise()
      logging.log_errors('Failed to debug', function()
        assert(launcher(root, label))
      end)
    end,
  })
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

---@class please.DebugOptions
---@inlinedoc
---@field under_cursor boolean debug the test under the cursor

---If the current file is a `BUILD` file, debug the target which is under the cursor. Otherwise, debug the target which
---takes the current file as an input.
---
---Debug support is provided by https://github.com/mfussenegger/nvim-dap.
---This is supported for the following languages:
---- Go (Delve)
---- Python (debugpy)
---
---Optionally (when in a source file), you can debug only the test which is under the cursor. The supported languages
---and test types are the same as for [please.test()].
---@param opts please.DebugOptions? optional keyword arguments
function M.debug(opts)
  logging.log_call('please.debug')

  logging.log_errors('Failed to debug', function()
    debug.setup()

    opts = opts or {}

    vim.validate('opts', opts, 'table')
    vim.validate('opts.under_cursor', opts.under_cursor, 'boolean', true)

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
        local target = assert(parsing.get_target_at_cursor(root))
        labels = { target.label }
        lang = target.rule:match('(%w+)_.+') -- assumes that rules will be formatted like $lang_xxx
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
---
---Example:
---```lua
---local please = require('please')
---please.command('build', '//foo/bar/...')
---```
---@param ... string Arguments to pass to plz
function M.command(...)
  logging.log_call('please.command')

  local args = { ... }
  logging.log_errors('Failed to run command', function()
    local path = get_filepath() or assert(vim.uv.cwd())
    local root = assert(get_repo_root(path))
    save_and_run_simple_command(root, args)
  end)
end

---Display a history of previous commands. Selecting one of them will run it again.
function M.history()
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

---Clears the command history for the current repository.
function M.clear_history()
  logging.log_call('please.clear_history')

  logging.log_errors('Failed to clear command history', function()
    local path = get_filepath() or assert(vim.uv.cwd())
    local root = assert(get_repo_root(path))

    local history = read_command_history()
    if not history[root] then
      return
    end

    history[root] = nil
    write_command_history(history)
  end)
end

---Sets the profile that will be used by [please.build()], [please.run()], [please.test()], [please.debug()], and
---[please.command()]. Profiles will be searched for in `/etc/please`, `~/.config/please`, and the current repository.
function M.set_profile()
  logging.log_call('please.profile')

  logging.log_errors('Failed to set profile', function()
    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

    local profiles = {} ---@type string[]

    for dir, profile_pattern in pairs({
      [root] = '%.plzconfig%.(.+)',
      ['/etc/please'] = 'plzconfig%.(.+)',
      ['~/.config/please'] = 'plzconfig%.(.+)',
    }) do
      for name, type in vim.fs.dir(dir) do
        if type == 'file' then
          local profile = name:match(profile_pattern)
          if profile and not (dir == root and name == '.plzconfig.local') then
            table.insert(profiles, profile)
          end
        end
      end
    end

    assert(#profiles > 0, 'no profiles found')

    table.sort(profiles)

    table.insert(profiles, 1, '')
    table.insert(profiles, 2, 'unset')

    select(profiles, {
      prompt = string.format('Select profile (Current: %s)', profiles_by_root[root] or 'no profile'),
      format_item = function(item)
        if item == '' then
          return string.format('Default (%s)', default_profile or 'no profile')
        end
        return item
      end,
    }, function(item)
      if item == '' then
        profiles_by_root[root] = nil
      else
        profiles_by_root[root] = item
      end
    end)
  end)
end

---Maximises the popup which was most recently quit or minimised.
function M.maximise_popup()
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
function M.jump_to_target()
  logging.log_call('please.jump_to_target')

  logging.log_errors('Failed to jump to target', function()
    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))
    local labels = assert(query.whatinputs(root, filepath))
    select_if_many(labels, { prompt = 'Select target to jump to' }, function(label)
      local target = assert(parsing.locate_build_target(root, label))
      logging.debug('opening %s at %s', target.file, vim.inspect(target.position))
      vim.cmd('edit ' .. target.file)
      vim.api.nvim_win_set_cursor(0, target.position)
    end)
  end)
end

---If the current file is a `BUILD` file, yank the label of the target which is
---under the cursor. Otherwise, yank the label of the target which takes the
---current file as an input.
function M.yank()
  logging.log_call('please.yank')

  logging.log_errors('Failed to yank', function()
    local filepath = assert(get_filepath())
    local root = assert(get_repo_root(filepath))

    local labels = {}
    if vim.bo.filetype == 'please' then
      local target = assert(parsing.get_target_at_cursor(root))
      labels = { target.label }
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

---Toggle debug logging. The debug logs mostly contain which functions are being called with which arguments. This
---should provide enough information to debug most issues.
function M.toggle_debug_logging()
  local enabled = logging.toggle_debug()
  if enabled then
    logging.info('debug logs disabled')
  else
    logging.info('debug logs enabled')
  end
end

return M
