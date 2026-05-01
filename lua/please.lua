local M = {}

---@class please.Opts
---@inlinedoc
---@field coverage please.CoverageOpts? Options affecting [:Please-cover]. See [please.CoverageOpts].
---@field formatting please.FormattingOpts? Options affecting formatting. See [please.FormattingOpts].
---@field history please.HistoryOpts? Options affecting [:Please-history]. See [please.HistoryOpts].
---@field lsp please.LSPOpts? Options affecting LSP. See [please.LSPOpts].
---@field package max_history_items integer? Deprecated. Use `history.max_items` instead. See [please.HistoryOpts].
---@field package configure_gopls boolean?  Deprecated. Use `lsp.gopls` instead. See [please.LSPOpts].
---@field package configure_golangci_lint_langserver boolean? Deprecated. Use `lsp.golangci_lint_langserver` instead. See [please.LSPOpts].
---@field package configure_basedpyright boolean? Deprecated. Use `lsp.basedpyright` instead. See [please.LSPOpts].
---@field package configure_pyright boolean? Deprecated. Use `lsp.pyright` instead. See [please.LSPOpts].
---@field package puku_command string[]? Deprecated. Use `formatting.puku_command` instead. See [please.FormattingOpts].

---Options affecting [:Please-cover].
---@class please.CoverageOpts
---@field highlighting please.CoverageHighlightingOpts? Options affecting highlighting. See [please.CoverageHighlightingOpts].

---Options affecting coverage highlighting.
---@class please.CoverageHighlightingOpts
---@field lines boolean? Whether to highlight covered and uncovered lines. Defaults to `false`.
---@field line_numbers boolean? Whether to highlight the line numbers of covered and uncovered lines. Defaults to `true`.

---Options affecting formatting.
---@class please.FormattingOpts
---@field puku_command string[]? Command to execute puku. Defaults to `nil` which means that puku formatting is not enabled.

---Options affecting [:Please-history].
---@class please.HistoryOpts
---@field max_items integer? The maximum number of history items to store for each repository. Defaults to `20`.

---Options affecting LSP.
---@class please.LSPOpts
---@field gopls boolean? Whether to configure the gopls language server for use in a Please repository. Defaults to `true`.
---@field golangci_lint_langserver boolean? Whether to configure the golangci-lint-langserver language server for use in a Please repository. Defaults to `true`.
---@field basedpyright boolean? Whether to configure the basedpyright language server for use in a Please repository. Defaults to `true`.
---@field pyright boolean? Whether to configure the pyright language server for use in a Please repository. Defaults to `true`.

---Updates the configuration with the provided {opts}.
---
---Should only be called if you want to change the defaults which are shown below.
---
---Execute `:checkhealth please` to view the current configuration.
---
---Example:
---```lua
---local please = require('please')
---please.setup({
---    coverage = {
---        highlighting = { lines = false, line_numbers = true },
---    },
---    formatting = { puku_command = nil },
---    history = { max_items = 20 },
---    lsp = {
---        gopls = true,
---        golangci_lint_langserver = true,
---        basedpyright = true,
---        pyright = true,
---    },
---})
---```
---@param opts please.Opts
function M.setup(opts)
    local config = require('_please.config')

    opts = vim.tbl_deep_extend('keep', opts, {
        formatting = { puku_command = opts.puku_command },
        history = { max_items = opts.max_history_items },
        lsp = {
            gopls = opts.configure_gopls,
            golangci_lint_langserver = opts.configure_golangci_lint_langserver,
            basedpyright = opts.configure_basedpyright,
            pyright = opts.configure_pyright,
        },
    })

    local deprecated_opt_replacements = {
        max_history_items = 'history.max_items',
        configure_gopls = 'lsp.gopls',
        configure_golangci_lint_langserver = 'lsp.golangci_lint_langserver',
        configure_basedpyright = 'lsp.basedpyright',
        configure_pyright = 'lsp.pyright',
        puku_command = 'formatting.puku_command',
    }
    for old, new in pairs(deprecated_opt_replacements) do
        if opts[old] == nil then
            goto continue
        end
        local value = vim.inspect(opts[old])
        local section, name = new:match('(%a+)%.(%a+)')
        vim.deprecate(
            string.format('please.setup({ %s = %s })', old, value),
            string.format('please.setup({ %s = { %s = %s } })', section, name, value),
            '2.0.0',
            'please.nvim'
        )
        opts[old] = nil
        ::continue::
    end

    config.set(opts)
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
---@alias _please.Command _please.SimpleCommand | _please.DebugCommand | _please.CoverCommand

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

---@nodoc
---@class _please.CoverCommand
---@field type 'cover'
---@field target string
---@field test_selector string?
---@field quickfix boolean
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
            :take(config.get().history.max_items - 1)
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

local function current_filepath()
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath == '' then
        return nil, 'no file open'
    end
    return filepath, nil
end

---@param path string
---@return string?
---@return string?
local function current_repo_root(path)
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
    require('_please.logging').log_call('please.build')

    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_errors('Failed to build', function()
        local filepath = assert(current_filepath())
        local root = assert(current_repo_root(filepath))

        local targets
        if vim.bo.filetype == 'please' then
            local target = assert(parsing.target_under_cursor(root))
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
    require('_please.logging').log_call('please.run')

    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_errors('Failed to run', function()
        local filepath = assert(current_filepath())
        local root = assert(current_repo_root(filepath))

        local targets
        if vim.bo.filetype == 'please' then
            local target = assert(parsing.target_under_cursor(root))
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
---Optionally, when in a source file, you can run only the test under the cursor. This is supported for the following
---languages:
---  - Go - test functions, subtests, table tests, testify suite methods, testify suite subtests, testify suite table
---    tests
---  - Python - unittest test classes, unittest test methods
---
---See [:Please-test] for the equivalent `:Please` command.
---@param opts please.TestOptions? optional keyword arguments
function M.test(opts)
    require('_please.logging').log_call('please.test')

    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_errors('Failed to test', function()
        opts = opts or {}

        vim.validate('opts', opts, 'table')
        vim.validate('opts.under_cursor', opts.under_cursor, 'boolean', true)

        local filepath = assert(current_filepath())
        local root = assert(current_repo_root(filepath))

        local targets = {} ---@type string[]
        local extra_args = {} ---@type string[]
        if opts.under_cursor then
            local test = assert(parsing.test_under_cursor())
            extra_args = { test.selector }
            targets = assert(query.whatinputs(root, filepath))
        elseif vim.bo.filetype == 'please' then
            local target = assert(parsing.target_under_cursor(root))
            targets = { target.build_label }
        else
            targets = assert(query.whatinputs(root, filepath))
        end

        select_if_many(targets, { prompt = 'Select target to test:' }, function(target)
            save_and_run_simple_command(root, { 'test', target, unpack(extra_args) })
        end)
    end)
end

---@class _please.Coverage
---@nodoc
---@field tests table<string, table<string, string>>
---@field files table<string, string>
---@field stats _please.CoverageStats

---@class _please.CoverageStats
---@nodoc
---@field total_coverage 	number
---@field coverage_by_file	table<string, number>
---@field coverage_by_directory	table<string, number>
---@field incremental _please.CoverageIncrementalStats?

---@class _please.CoverageIncrementalStats
---@nodoc
---@field modified_files integer
---@field modified_lines integer
---@field covered_lines integer
---@field percentage number

---@enum _please.LineCoverage
local LineCoverage = {
    NOT_EXECUTABLE = 'N', -- Line isn't executable (eg. comment, blank)
    UNREACHABLE = 'X', -- Line is executable but we've determined it can't be reached. So far not used.
    UNCOVERED = 'U', -- Line is executable but isn't covered.
    COVERED = 'C', -- Line is executable and covered.
}

---@class _please.CoverageState
---@nodoc
---@field enabled boolean
---@field root string
---@field coverage _please.Coverage
---@field covered_bufnrs integer[]

local coverage_namespace = vim.api.nvim_create_namespace('please.coverage')
local coverage_augroup = vim.api.nvim_create_augroup('please.coverage', {})
local current_coverage_state ---@type _please.CoverageState?

---@param root string
---@param coverage _please.Coverage
local function start_coverage_highlighting(root, coverage)
    local config = require('_please.config')

    local covered_bufnrs = {} ---@type integer[]
    current_coverage_state = {
        enabled = true,
        root = root,
        coverage = coverage,
        covered_bufnrs = covered_bufnrs,
    }

    local covered_line_higroup = 'PleaseCoverageCoveredLine'
    local uncovered_line_higroup = 'PleaseCoverageUncoveredLine'
    local covered_line_nr_higroup = 'PleaseCoverageCoveredLineNr'
    local uncovered_line_nr_higroup = 'PleaseCoverageUncoveredLineNr'
    vim.api.nvim_set_hl(0, covered_line_higroup, { default = true, link = 'DiffAdd' })
    vim.api.nvim_set_hl(0, uncovered_line_higroup, { default = true, link = 'DiffDelete' })
    vim.api.nvim_set_hl(0, covered_line_nr_higroup, { default = true, link = 'DiagnosticOk' })
    vim.api.nvim_set_hl(0, uncovered_line_nr_higroup, { default = true, link = 'DiagnosticError' })

    local highlight_lines = config.get().coverage.highlighting.lines
    local highlight_line_numbers = config.get().coverage.highlighting.line_numbers
    if not highlight_lines and not highlight_line_numbers then
        return
    end

    local covered_paths = vim.tbl_map(function(file)
        return vim.fs.joinpath(root, file)
    end, vim.tbl_keys(coverage.files))

    local covered_bufs = {} ---@type table<integer, boolean>
    vim.api.nvim_create_autocmd('BufEnter', {
        desc = 'Highlight lines and line numbers of covered and uncovered lines',
        group = coverage_augroup,
        pattern = covered_paths,
        callback = function(ev)
            if covered_bufs[ev.buf] then
                return
            end
            covered_bufs[ev.buf] = true
            table.insert(covered_bufnrs, ev.buf)

            local path = vim.fs.relpath(root, ev.match)
            local file_coverage = coverage.files[path]
            for line = 1, #file_coverage do
                local line_coverage = file_coverage:sub(line, line)
                local line_hl_group ---@type string?
                local number_hl_group ---@type string?
                if line_coverage == LineCoverage.UNCOVERED then
                    line_hl_group = highlight_lines and uncovered_line_higroup or nil
                    number_hl_group = highlight_line_numbers and uncovered_line_nr_higroup or nil
                elseif line_coverage == LineCoverage.COVERED then
                    line_hl_group = highlight_lines and covered_line_higroup or nil
                    number_hl_group = highlight_line_numbers and covered_line_nr_higroup or nil
                else
                    goto continue
                end
                vim.api.nvim_buf_set_extmark(ev.buf, coverage_namespace, line - 1, 0, {
                    number_hl_group = number_hl_group,
                    line_hl_group = line_hl_group,
                })
                ::continue::
            end
        end,
    })

    local winids = vim.api.nvim_list_wins()
    for _, winid in ipairs(winids) do
        local bufnr = vim.api.nvim_win_get_buf(winid)
        vim.api.nvim_exec_autocmds('BufEnter', {
            buffer = bufnr,
            group = coverage_augroup,
        })
    end
end

local function stop_coverage_highlighting()
    if not current_coverage_state then
        return
    end

    current_coverage_state.enabled = false
    vim.api.nvim_clear_autocmds({ group = coverage_augroup })
    for _, buf in ipairs(current_coverage_state.covered_bufnrs) do
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_clear_namespace(buf, coverage_namespace, 0, -1)
        end
    end
end

---@param root string
---@param coverage _please.Coverage
---@return vim.quickfix.entry[]
local function coverage_quickfix_items(root, coverage)
    local qflist = {} ---@type vim.quickfix.entry[]
    for path, covered_percent in pairs(coverage.stats.coverage_by_file) do
        ---@type vim.quickfix.entry
        local entry = {
            filename = vim.fs.joinpath(root, path),
            text = string.format('%.2f%% covered', covered_percent):gsub('%.?0+%%', '%%'),
        }
        table.insert(qflist, entry)
    end
    table.sort(qflist, function(a, b)
        return a.filename < b.filename
    end)
    return qflist
end

---@param root string
---@param target string
---@param test_selector string?
---@param quickfix boolean
local function run_cover_command(root, target, test_selector, quickfix)
    local logging = require('_please.logging')

    local args = { 'cover', target }
    if test_selector then
        table.insert(args, test_selector)
    end

    stop_coverage_highlighting()

    start_runner(root, args, {
        on_exit = function(code, runner)
            logging.log_errors('Failed to cover', function()
                local test_failed_code = 7
                if code ~= 0 and code ~= test_failed_code then
                    return
                end

                local coverage_path = vim.fs.joinpath(root, 'plz-out/log/coverage.json')
                local coverage_blob = vim.fn.readblob(coverage_path)
                local coverage = vim.json.decode(coverage_blob) ---@type _please.Coverage

                start_coverage_highlighting(root, coverage)

                if quickfix then
                    local items = coverage_quickfix_items(root, coverage)
                    vim.fn.setqflist({}, ' ', {
                        items = items,
                        -- TODO: Delete after nvim 0.11 support dropped. nr is annotated incorrectly in nvim 0.11.
                        ---@diagnostic disable-next-line: assign-type-mismatch
                        nr = '$',
                        title = '[please.nvim] Test Coverage',
                    })
                    vim.cmd.copen() -- This causes the runner to be minimised
                    runner:maximise()
                end
            end)
        end,
    })
end

---@param root string
---@param target string
---@param test_selector string?
---@param quickfix boolean
local function save_and_run_cover_command(root, target, test_selector, quickfix)
    save_command(root, {
        type = 'cover',
        target = target,
        test_selector = test_selector,
        quickfix = quickfix,
        description = table.concat({ 'plz cover', target, test_selector }, ' '),
    })
    run_cover_command(root, target, test_selector, quickfix)
end

---@class please.cover.Opts
---@inlinedoc
---@field under_cursor boolean? Run the test under the cursor
---@field quickfix boolean? Populate the quickfix list with the coverage results and open the quickfix list

---Tests a target, calculates coverage, and highlights the covered and uncovered lines.
---
---If the current file is a `BUILD` file, tests the target which is under the cursor. Otherwise, tests the target which
---takes the current file as an input.
---
---Optionally, when in a source file, you can run only the test under the cursor. The supported languages and test types
---are the same as for [please.test()].
---
---Call [please.toggle_coverage_highlighting()] to toggle highlighting off and on.
---
---Some coverage related behaviour can be configured with [please.setup()]. See the `coverage` option.
---
---See [:Please-cover] for the equivalent `:Please` command.
---@param opts please.cover.Opts? Optional keyword arguments
function M.cover(opts)
    require('_please.logging').log_call('please.cover')

    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_errors('Failed to cover', function()
        opts = opts or {}

        vim.validate('opts', opts, 'table')
        vim.validate('opts.under_cursor', opts.under_cursor, 'boolean', true)
        vim.validate('opts.quickfix', opts.quickfix, 'boolean', true)

        local filepath = assert(current_filepath())
        local root = assert(current_repo_root(filepath))

        local targets = {} ---@type string[]
        if vim.bo.filetype == 'please' then
            local target = assert(parsing.target_under_cursor(root))
            targets = { target.build_label }
        else
            targets = assert(query.whatinputs(root, filepath))
        end

        local selector ---@type string?
        if opts.under_cursor then
            local test = assert(parsing.test_under_cursor())
            selector = test.selector
        end

        select_if_many(targets, { prompt = 'Select target to cover:' }, function(target)
            save_and_run_cover_command(root, target, selector, opts.quickfix or false)
        end)
    end)
end

---Toggles coverage highlighting.
---
---See [:Please-toggle_coverage_highlighting] for the equivalent `:Please` command.
function M.toggle_coverage_highlighting()
    require('_please.logging').log_call('please.toggle_coverage_highlighting')

    local logging = require('_please.logging')

    logging.log_errors('Failed to toggle coverage highlighting', function()
        if not current_coverage_state then
            error('coverage has not been calculated')
        end

        if current_coverage_state.enabled then
            stop_coverage_highlighting()
            logging.info('Disabled coverage highlighting')
        else
            start_coverage_highlighting(current_coverage_state.root, current_coverage_state.coverage)
            logging.info('Enabled coverage highlighting')
        end
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
        on_exit = function(code, runner)
            if code ~= 0 then
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
---Optionally, when in a source file, you can run only the test under the cursor. The supported languages and test types
---are the same as for [please.test()].
---
---See [:Please-debug] for the equivalent `:Please` command.
---@param opts please.DebugOptions? optional keyword arguments
function M.debug(opts)
    require('_please.logging').log_call('please.debug')

    local debug = require('_please.debug')
    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_errors('Failed to debug', function()
        opts = opts or {}

        vim.validate('opts', opts, 'table')
        vim.validate('opts.under_cursor', opts.under_cursor, 'boolean', true)

        local filepath = assert(current_filepath())
        local root = assert(current_repo_root(filepath))

        local targets = {} ---@type string[]
        local lang = '' ---@type string
        local extra_args = {} ---@type string[]
        if opts.under_cursor then
            local test = assert(parsing.test_under_cursor())
            extra_args = { test.selector }
            targets = assert(query.whatinputs(root, filepath))
            lang = vim.bo.filetype
        elseif vim.bo.filetype == 'please' then
            local target = assert(parsing.target_under_cursor(root))
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
    require('_please.logging').log_call('please.command')

    local logging = require('_please.logging')

    local args = { ... }
    logging.log_errors('Failed to run command', function()
        if #args == 0 then
            error('no arguments provided')
        end
        local path = current_filepath() or assert(vim.uv.cwd())
        local root = assert(current_repo_root(path))
        save_and_run_simple_command(root, args)
    end)
end

---Displays a history of previous commands run in the current repository. Selecting one runs it again.
---
---Some history related behaviour can be configured with [please.setup()]. See the `history` option.
---
---See [:Please-history] for the equivalent `:Please` command.
function M.history()
    require('_please.logging').log_call('please.history')

    local logging = require('_please.logging')

    logging.log_errors('Failed to show command history', function()
        local path = current_filepath() or assert(vim.uv.cwd())
        local root = assert(current_repo_root(path))

        local history = read_command_history()
        if not history[root] then
            logging.error('command history is empty for repo ' .. root)
            return
        end

        local function format_item(command)
            return command.description
        end
        select(
            history[root],
            { prompt = 'Pick command to run again:', format_item = format_item },
            function(command)
                if command.type == 'simple' then
                    save_and_run_simple_command(root, command.args)
                elseif command.type == 'debug' then
                    save_and_run_debug_command(root, command.lang, command.target, command.extra_args)
                elseif command.type == 'cover' then
                    save_and_run_cover_command(root, command.target, command.test_selector, command.quickfix)
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
    require('_please.logging').log_call('please.clear_history')

    local logging = require('_please.logging')

    logging.log_errors('Failed to clear command history', function()
        local path = current_filepath() or assert(vim.uv.cwd())
        local root = assert(current_repo_root(path))

        local history = read_command_history()
        if not history[root] then
            return
        end

        history[root] = nil
        write_command_history(history)
        logging.info('Cleared command history for repository %s', root)
    end)
end

---Sets the profile used by [please.build()], [please.run()], [please.test()], [please.debug()], and [please.command()].
---
---Profiles are searched for in `/etc/please`, `~/.config/please`, and the current repository.
---
---See [:Please-set_profile] for the equivalent `:Please` command.
function M.set_profile()
    require('_please.logging').log_call('please.set_profile')

    local logging = require('_please.logging')

    logging.log_errors('Failed to set profile', function()
        local path = current_filepath() or assert(vim.uv.cwd())
        local root = assert(current_repo_root(path))

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
    require('_please.logging').log_call('please.maximise_popup')

    local logging = require('_please.logging')
    local runner = require('_please.runner')

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
    require('_please.logging').log_call('please.jump_to_target')

    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_errors('Failed to jump to target', function()
        local filepath = assert(current_filepath())
        local root = assert(current_repo_root(filepath))
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
    require('_please.logging').log_call('please.look_up_target')

    local logging = require('_please.logging')
    local parsing = require('_please.parsing')

    logging.log_errors('Failed to look up target', function()
        local path = current_filepath() or assert(vim.uv.cwd())
        local root = assert(current_repo_root(path))

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

        local build_label_at_cursor = parsing.build_label_under_cursor()
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
    require('_please.logging').log_call('please.yank')

    local logging = require('_please.logging')
    local parsing = require('_please.parsing')
    local query = require('_please.query')

    logging.log_errors('Failed to yank', function()
        local filepath = assert(current_filepath())
        local root = assert(current_repo_root(filepath))

        local targets = {}
        if vim.bo.filetype == 'please' then
            local target = assert(parsing.target_under_cursor(root))
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
