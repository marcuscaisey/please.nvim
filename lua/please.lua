local M = {}

---@inlinedoc
---@class please.Opts
---@field max_history_items integer? The maximum number of history items to store for each repository. Defaults to 20.
---@field configure_gopls boolean? Whether to configure the gopls language server for use in a Please repository. Defaults to true.
---@field configure_golangci_lint_langserver boolean? Whether to configure the golangci-lint-langserver language server for use in a Please repository. Defaults to true.
---@field configure_basedpyright boolean? Whether to configure the basedpyright language server for use in a Please repository. Defaults to true.
---@field configure_pyright boolean? Whether to configure the pyright language server for use in a Please repository. Defaults to true.
---@field puku_command string[]? Command to execute puku. Defaults to nil which means that puku formatting is not enabled.

---Updates the configuration with the provided {opts}.
---
---Should only be called if you want to change the defaults which are shown below.
---
---Example:
---```lua
---local please = require('please')
---please.setup({
---    max_history_items = 20,
---    configure_gopls = true,
---    configure_golangci_lint_langserver = true,
---    configure_basedpyright = true,
---    configure_pyright = true,
---    puku_command = nil,
---})
---```
---@param opts please.Opts
function M.setup(opts)
    local config = require('_please.config')
    config.update(opts)
end

local default_profile = os.getenv('PLZ_CONFIG_PROFILE')

---@type table<string, string?>
local profiles_by_root = setmetatable({}, {
    __index = function()
        return default_profile
    end,
})

---@param root string
---@param args string[]
---@param opts _please.runner.RunnerOpts?
local function start_runner(root, args, opts)
    local runner = require('_please.runner')
    local profile = profiles_by_root[root]
    if profile then
        table.insert(args, 1, '--profile')
        table.insert(args, 2, profile)
    end
    runner.Runner.start(root, args, opts)
end

local data_path = vim.fn.stdpath('data')
---@cast data_path string
local command_history_path = vim.fs.joinpath(data_path, 'please-command-history.json')

---@return table<string, _please.Command[]>
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
---@alias _please.Command _please.SimpleCommand | _please.DebugCommand

---@nodoc
---@class _please.SimpleCommand
---@field type 'simple'
---@field args table
---@field description string

---@nodoc
---@class _please.DebugCommand
---@field type 'debug'
---@field lang string
---@field target string
---@field extra_args string[]
---@field description string

---@param root string
---@param command _please.Command
local function save_command(root, command)
    local config = require('_please.config')
    local history = read_command_history()
    if history[root] then
        history[root] = vim.iter(history[root])
            :filter(function(history_item)
                return history_item.description ~= command.description
            end)
            :take(config.get().max_history_items - 1)
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

---Builds a target.
---
---If the current file is a `BUILD` file, builds the target which is under the cursor. Otherwise, builds the target
---which takes the current file as an input.
---
---See [:Please-build] for the equivalent `:Please` command.
function M.build()
    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_call('please.build')

    logging.log_errors('Failed to build', function()
        local filepath = assert(get_filepath())
        local root = assert(get_repo_root(filepath))

        local targets
        if vim.bo.filetype == 'please' then
            local target = assert(parsing.get_target_at_cursor(root))
            targets = { target.build_label }
        else
            targets = assert(query.whatinputs(root, filepath))
        end

        select_if_many(targets, { prompt = 'Select target to build:' }, function(target)
            save_and_run_simple_command(root, { 'build', target })
        end)
    end)
end

---Runs a target.
---
---If the current file is a `BUILD` file, runs the target which is under the cursor. Otherwise, runs the target which
---takes the current file as an input.
---
---See [:Please-run] for the equivalent `:Please` command.
function M.run()
    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_call('please.run')

    logging.log_errors('Failed to run', function()
        local filepath = assert(get_filepath())
        local root = assert(get_repo_root(filepath))

        local targets
        if vim.bo.filetype == 'please' then
            local target = assert(parsing.get_target_at_cursor(root))
            targets = { target.build_label }
        else
            targets = assert(query.whatinputs(root, filepath))
        end

        select_if_many(targets, { prompt = 'Select target to run:' }, function(target)
            vim.ui.input({ prompt = 'Enter program arguments: ' }, function(input)
                if not input then
                    return
                end
                local args = {}
                -- vim.ui.input passes empty input as an empty string instead of nil, I think this is a bug so just check for both to be safe.
                input = vim.trim(input)
                if input ~= '' then
                    args = { '--', unpack(vim.split(input, ' ')) }
                end
                save_and_run_simple_command(root, { 'run', target, unpack(args) })
            end)
        end)
    end)
end

---@class please.TestOptions
---@inlinedoc
---@field under_cursor boolean run the test under the cursor

---Tests a target.
---
---If the current file is a `BUILD` file, tests the target which is under the cursor. Otherwise, tests the target which
---takes the current file as an input.
---
---Optionally (when in a source file), you can run only the test which is under the cursor.
---This is supported for the following languages:
---- Go - test functions, subtests, table tests, testify suite methods, testify suite subtests, testify suite table
---  tests
---- Python - unittest test classes, unittest test methods
---
---See [:Please-test] for the equivalent `:Please` command.
---@param opts please.TestOptions? optional keyword arguments
function M.test(opts)
    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_call('please.test')

    logging.log_errors('Failed to test', function()
        opts = opts or {}

        vim.validate('opts', opts, 'table')
        vim.validate('opts.under_cursor', opts.under_cursor, 'boolean', true)

        local filepath = assert(get_filepath())
        local root = assert(get_repo_root(filepath))

        local targets = {} ---@type string[]
        local extra_args = {} ---@type string[]
        if opts.under_cursor then
            local test = assert(parsing.get_test_at_cursor())
            extra_args = { test.selector }
            targets = assert(query.whatinputs(root, filepath))
        elseif vim.bo.filetype == 'please' then
            local target = assert(parsing.get_target_at_cursor(root))
            targets = { target.build_label }
        else
            targets = assert(query.whatinputs(root, filepath))
        end

        select_if_many(targets, { prompt = 'Select target to test:' }, function(targets)
            save_and_run_simple_command(root, { 'test', targets, unpack(extra_args) })
        end)
    end)
end

---@param root string
---@param lang string
---@param target string
---@param extra_args string[]
local function run_debug_command(root, lang, target, extra_args)
    local debug = require('_please.debug')
    local logging = require('_please.logging')

    local launcher = debug.launchers[lang]
    start_runner(root, { 'build', '--config', 'dbg', target }, {
        on_exit = function(success, runner)
            if not success then
                return
            end
            runner:minimise()
            logging.log_errors('Failed to debug', function()
                assert(launcher(root, target, extra_args))
            end)
        end,
    })
end

---@param root string
---@param lang string
---@param target string
---@param extra_args string[]
local function save_and_run_debug_command(root, lang, target, extra_args)
    save_command(root, {
        type = 'debug',
        lang = lang,
        target = target,
        extra_args = extra_args,
        description = table.concat({ 'plz', 'debug', target, unpack(extra_args) }, ' '),
    })
    run_debug_command(root, lang, target, extra_args)
end

---@class please.DebugOptions
---@inlinedoc
---@field under_cursor boolean debug the test under the cursor

---Debugs a target.
---
---If the current file is a `BUILD` file, debugs the target which is under the cursor. Otherwise, debugs the target
---which takes the current file as an input.
---
---Debug support is provided by https://github.com/mfussenegger/nvim-dap.
---This is supported for the following languages:
---- Go (Delve)
---- Python (debugpy)
---
---Optionally (when in a source file), you can debug only the test which is under the cursor. The supported languages
---and test types are the same as for [please.test()].
---
---See [:Please-debug] for the equivalent `:Please` command.
---@param opts please.DebugOptions? optional keyword arguments
function M.debug(opts)
    local debug = require('_please.debug')
    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_call('please.debug')

    logging.log_errors('Failed to debug', function()
        opts = opts or {}

        vim.validate('opts', opts, 'table')
        vim.validate('opts.under_cursor', opts.under_cursor, 'boolean', true)

        local filepath = assert(get_filepath())
        local root = assert(get_repo_root(filepath))

        local targets = {} ---@type string[]
        local lang = '' ---@type string
        local extra_args = {} ---@type string[]
        if opts.under_cursor then
            local test = assert(parsing.get_test_at_cursor())
            extra_args = { test.selector }
            targets = assert(query.whatinputs(root, filepath))
            lang = vim.bo.filetype
        elseif vim.bo.filetype == 'please' then
            local target = assert(parsing.get_target_at_cursor(root))
            targets = { target.build_label }
            lang = target.rule:match('(%w+)_.+') -- assumes that rules will be formatted like $lang_xxx
        else
            targets = assert(query.whatinputs(root, filepath))
            lang = vim.bo.filetype
        end

        if not debug.launchers[lang] then
            error(string.format('debugging is not supported for %s files', lang))
        end

        select_if_many(targets, { prompt = 'Select target to debug:' }, function(target)
            logging.log_errors('Failed to debug', function()
                local is_test = assert(query.print_field(root, target, 'test')) == 'True'
                if is_test then
                    save_and_run_debug_command(root, lang, target, extra_args)
                else
                    vim.ui.input({ prompt = 'Enter program arguments: ' }, function(input)
                        if not input then
                            return
                        end
                        local extra_args = {}
                        input = vim.trim(input)
                        if input ~= '' then
                            extra_args = { '--', unpack(vim.split(input, ' ')) }
                        end
                        save_and_run_debug_command(root, lang, target, extra_args)
                    end)
                end
            end)
        end)
    end)
end

---Runs an arbitrary plz command and displays the output in a popup.
---
---Example:
---```lua
---local please = require('please')
---please.command('build', '//foo/bar/...')
---```
---See [:Please-command] for the equivalent `:Please` command.
---@param ... string Arguments to pass to plz
function M.command(...)
    local logging = require('_please.logging')

    logging.log_call('please.command')

    local args = { ... }
    logging.log_errors('Failed to run command', function()
        if #args == 0 then
            error('no arguments provided')
        end
        local path = get_filepath() or assert(vim.uv.cwd())
        local root = assert(get_repo_root(path))
        save_and_run_simple_command(root, args)
    end)
end

---Displays a history of previous commands run in the current repository. Selecting one runs it again.
---
---See [:Please-history] for the equivalent `:Please` command.
function M.history()
    local logging = require('_please.logging')

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
        select(
            history[root],
            { prompt = 'Pick command to run again:', format_item = get_description },
            function(command)
                if command.type == 'simple' then
                    save_and_run_simple_command(root, command.args)
                elseif command.type == 'debug' then
                    save_and_run_debug_command(root, command.lang, command.target, command.extra_args)
                else
                    error('unknown command type: ' .. vim.inspect(command))
                end
            end
        )
    end)
end

---Clears the command history for the current repository.
---
---See [:Please-clear_history] for the equivalent `:Please` command.
function M.clear_history()
    local logging = require('_please.logging')

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

---Sets the profile used by [please.build()], [please.run()], [please.test()], [please.debug()], and [please.command()].
---
---Profiles are searched for in `/etc/please`, `~/.config/please`, and the current repository.
---
---See [:Please-set_profile] for the equivalent `:Please` command.
function M.set_profile()
    local logging = require('_please.logging')

    logging.log_call('please.set_profile')

    logging.log_errors('Failed to set profile', function()
        local path = get_filepath() or assert(vim.uv.cwd())
        local root = assert(get_repo_root(path))

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
            prompt = string.format('Select profile (Current: %s):', profiles_by_root[root] or 'no profile'),
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
---
---See [:Please-maximise_popup] for the equivalent `:Please` command.
function M.maximise_popup()
    local logging = require('_please.logging')
    local runner = require('_please.runner')

    logging.log_call('please.maximise_popup')
    if runner.current then
        runner.current:maximise()
    else
        logging.error('no popup to maximise')
    end
end

---Jumps to the location of the target which takes the current file as an input.
---
---The cursor is moved to where the target is created if it can be found which should be the case for all targets except
---for those with names which are generated when the `BUILD` file is executed.
---
---See [:Please-jump_to_target] for the equivalent `:Please` command.
function M.jump_to_target()
    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_call('please.jump_to_target')

    logging.log_errors('Failed to jump to target', function()
        local filepath = assert(get_filepath())
        local root = assert(get_repo_root(filepath))
        local targets = assert(query.whatinputs(root, filepath))
        select_if_many(targets, { prompt = 'Select target to jump to:' }, function(target)
            local target = assert(parsing.locate_target(root, target))
            logging.debug('opening %s at %s', target.file, vim.inspect(target.position))
            vim.cmd('edit ' .. target.file)
            vim.api.nvim_win_set_cursor(0, target.position)
        end)
    end)
end

---Looks up a target by its build label and jumps to its location.
---
---If the cursor is already on a build label, then this is used. Otherwise, you'll be prompted for one.
---
---The cursor is moved to where the target is created if it can be found which should be the case for all targets except
---for those with names which are generated when the `BUILD` file is executed.
---
---See [:Please-look_up_target] for the equivalent `:Please` command.
function M.look_up_target()
    local logging = require('_please.logging')
    local parsing = require('_please.parsing')

    logging.log_call('please.look_up_target')

    logging.log_errors('Failed to look up target', function()
        local path = get_filepath() or assert(vim.uv.cwd())
        local root = assert(get_repo_root(path))

        ---@param target string
        local function look_up_target(target)
            local target, err = parsing.locate_target(root, target)
            if err then ---@cast target -?
                logging.error('Failed to look up target: %s', err)
                return
            end
            logging.debug('opening %s at %s', target.file, vim.inspect(target.position))
            vim.cmd('edit ' .. target.file)
            vim.api.nvim_win_set_cursor(0, target.position)
        end

        local build_label_at_cursor = parsing.get_build_label_at_cursor()
        if build_label_at_cursor then
            look_up_target(build_label_at_cursor)
            return
        end

        vim.ui.input({ prompt = 'Enter target to look up: ' }, function(target)
            if not target then
                return
            end
            look_up_target(vim.trim(target))
        end)
    end)
end

---Yanks a target's build label.
---
---If the current file is a `BUILD` file, yanks the build label of the target which is under the cursor. Otherwise,
---yanks the build label of the target which takes the current file as an input.
---
---See [:Please-yank] for the equivalent `:Please` command.
function M.yank()
    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_call('please.yank')

    logging.log_errors('Failed to yank', function()
        local filepath = assert(get_filepath())
        local root = assert(get_repo_root(filepath))

        local targets = {}
        if vim.bo.filetype == 'please' then
            local target = assert(parsing.get_target_at_cursor(root))
            targets = { target.build_label }
        else
            targets = assert(query.whatinputs(root, filepath))
        end

        select_if_many(targets, { prompt = 'Select build label to yank:' }, function(target)
            local registers = { '"', '*' }
            for _, register in ipairs(registers) do
                logging.debug('setting %s register to %s', register, target)
                vim.fn.setreg(register, target)
            end
            logging.info('yanked %s', target)
        end)
    end)
end

---Toggles debug logging.
---
---The debug logs mostly contain which functions are being called with which arguments. This should provide enough
---information to debug most issues.
---
---See [:Please-toggle_debug_logging] for the equivalent `:Please` command.
function M.toggle_debug_logging()
    local logging = require('_please.logging')

    local enabled = logging.toggle_debug()
    if enabled then
        logging.info('debug logs enabled')
    else
        logging.info('debug logs disabled')
    end
end

return M
