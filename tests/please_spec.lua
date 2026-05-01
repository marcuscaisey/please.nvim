local stub = require('luassert.stub')
local please = require('please')
local config = require('_please.config')
local debug = require('_please.debug')
local runner = require('_please.runner')
local logging = require('_please.logging')
local temptree = require('tests.temptree')
local log_handler = require('tests.log_handler')

logging.toggle_debug()

local it = log_handler.wrap_it(it)

-- When this test file is run multiple times in parallel (in a non-sandboxed environment), at least one of the runs
-- usually fails because some functionality being tested relies on use of the clipboard which is being shared between
-- all of the runs. We override the default clipboard provider so that each run uses its own in memory clipboard instead
-- of the system one.
local clipboard_lines
vim.g.clipboard = {
    name = 'fake',
    copy = {
        ['*'] = function(lines)
            clipboard_lines = lines
        end,
        ['+'] = function(lines)
            clipboard_lines = lines
        end,
    },
    paste = {
        ['*'] = function()
            return clipboard_lines
        end,
        ['+'] = function()
            return clipboard_lines
        end,
    },
}

local default_opts = config.get()

local RunnerSpy = {}
RunnerSpy.__index = RunnerSpy

---@param code integer?
function RunnerSpy:new(code)
    if code == nil then
        code = 0
    end
    local o = { _root = nil, _args = nil, _called = false, _minimise_called = false }
    stub(runner.Runner, 'start', function(root, args, opts)
        o._root = root
        o._args = args
        o._called = true
        if opts and opts.on_exit then
            opts.on_exit(code, o)
        end
        return o
    end)
    return setmetatable(o, self)
end

function RunnerSpy:destroy() end

function RunnerSpy:minimise()
    self._minimise_called = true
end

function RunnerSpy:maximise()
    self._maximise_called = true
end

function RunnerSpy:assert_called_with(root, args)
    assert.is_true(self._called, 'Runner.start has not been called')
    assert.equal(root, self._root, 'incorrect root passed to Runner.start')
    assert.same(args, self._args, 'incorrect args passed to Runner.start')
end

function RunnerSpy:assert_minimise_called()
    assert.is_true(self._minimise_called, 'Runner.minimise has not been called')
end

function RunnerSpy:assert_minimise_not_called()
    assert.is_false(self._minimise_called, 'Runner.minimise has been called')
end

function RunnerSpy:assert_maximise_called()
    assert.is_true(self._maximise_called, 'Runner.maximise has not been called')
end

local SelectFake = {}
SelectFake.__index = SelectFake

function SelectFake:new()
    local o = { _called = false, _items = nil, _formatted_items = nil, _opts = nil, _on_choice = nil }
    stub(vim.ui, 'select', function(items, opts, on_choice)
        o._items = items
        o._opts = opts
        o._on_choice = on_choice
        o._formatted_items = vim.tbl_map(opts.format_item or tostring, items)
        o._called = true
    end)
    return setmetatable(o, self)
end

function SelectFake:assert_items(items)
    self:assert_called()
    assert.same(items, self._formatted_items, 'incorrect items passed to vim.ui.select')
end

function SelectFake:assert_prompt(prompt)
    self:assert_called()
    assert.is_not_nil(self._opts.prompt, 'incorrect prompt opt passed to vim.ui.select')
    assert.equal(prompt, self._opts.prompt, 'incorrect prompt opt passed to vim.ui.select')
end

function SelectFake:choose_item(item)
    self:assert_called()
    assert.is_true(
        vim.tbl_contains(self._formatted_items, item),
        string.format(
            'cannot choose item "%s" which was not passed to vim.ui.select, available choices are: %s',
            item,
            vim.inspect(self._formatted_items)
        )
    )
    for i, v in ipairs(self._formatted_items) do
        if v == item then
            self._on_choice(self._items[i], i)
        end
    end
end

function SelectFake:assert_called()
    assert.is_true(self._called, 'vim.ui.select has not been called')
end

function SelectFake:assert_not_called()
    assert.is_false(self._called, 'vim.ui.select has been called')
end

local InputFake = {}
InputFake.__index = InputFake

function InputFake:new()
    local o = { _called = false, _opts = nil, _on_confirm = nil }
    stub(vim.ui, 'input', function(opts, on_confirm)
        o._opts = opts
        o._on_confirm = on_confirm
        o._called = true
    end)
    return setmetatable(o, self)
end

function InputFake:assert_prompt(prompt)
    self:assert_called()
    assert.is_not_nil(self._opts.prompt, 'expected prompt opt passed to vim.ui.input')
    assert.equal(prompt, self._opts.prompt, 'incorrect prompt opt passed to vim.ui.input')
end

function InputFake:enter_input(input)
    self:assert_called()
    self._on_confirm(input)
end

function InputFake:assert_called()
    assert.is_true(self._called, 'vim.ui.input has not been called')
end

local DebugLauncherSpy = {}
DebugLauncherSpy.__index = DebugLauncherSpy

function DebugLauncherSpy:new(lang)
    local o = { _lang = lang, _root = nil, _target = nil, _extra_args = nil, _called = false }
    debug.launchers[lang] = function(root, target, extra_args)
        o._root = root
        o._target = target
        o._extra_args = extra_args
        o._called = true
        return true
    end
    return setmetatable(o, self)
end

function DebugLauncherSpy:assert_called_with(root, target, extra_args)
    assert.is_true(self._called, string.format('%s debug launcher has not been called', self._lang))
    assert.equal(root, self._root, string.format('incorrect root passed to %s debug launcher', self._lang))
    assert.equal(target, self._target, string.format('incorrect target passed to %s debug launcher', self._lang))
    assert.same(
        extra_args,
        self._extra_args,
        string.format('incorrect extra_args passed to %s debug launcher', self._lang)
    )
end

function DebugLauncherSpy:assert_not_called()
    assert.is_false(self._called, string.format('%s debug launcher has been called', self._lang))
end

describe('build', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            BUILD = [[
                export_file(
                    name = "foo1",
                    src = "foo1.txt",
                )

                filegroup(
                    name = "foo1_and_foo2",
                    srcs = [
                        "foo1.txt",
                        "foo2.txt",
                    ],
                )
            ]],
            ['foo1.txt'] = 'foo1 content',
            ['foo2.txt'] = 'foo2 content',
        })
    end

    describe('in source file', function()
        it('should build target which uses file as input', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()

            -- GIVEN we're editing a file
            vim.cmd('edit ' .. root .. '/foo2.txt')
            -- WHEN we call build
            please.build()
            -- THEN the target which the file is an input for is built
            runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })
        end)

        it('should prompt to choose which target to build if there is more than one', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()
            local select_fake = SelectFake:new()

            -- GIVEN we're editing a file referenced by multiple targets
            vim.cmd('edit ' .. root .. '/foo1.txt')
            -- WHEN we call build
            please.build()
            -- THEN we're prompted to choose which target to build
            select_fake:assert_prompt('Select target to build:')
            select_fake:assert_items({ '//:foo1', '//:foo1_and_foo2' })
            -- WHEN we select one of the targets
            select_fake:choose_item('//:foo1_and_foo2')
            -- THEN the target is built
            runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })
        end)
    end)

    describe('in BUILD file', function()
        it('should build target under cursor', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()

            -- GIVEN we're editing a BUILD file and our cursor is inside a target
            vim.cmd('edit ' .. root .. '/BUILD')
            vim.api.nvim_win_set_cursor(0, { 6, 4 }) -- inside definition of :foo1_and_foo2
            -- WHEN we call build
            please.build()
            -- THEN the target under the cursor is built
            runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })
        end)
    end)

    it('should add entry to command history', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local select_fake = SelectFake:new()

        -- GIVEN we've built a target
        vim.cmd('edit ' .. root .. '/foo2.txt')
        please.build()
        -- WHEN we call history
        please.history()
        -- THEN we're prompted to pick a command to run again
        select_fake:assert_prompt('Pick command to run again:')
        select_fake:assert_items({ 'plz build //:foo1_and_foo2' })
        -- WHEN we select the build command
        select_fake:choose_item('plz build //:foo1_and_foo2')
        -- THEN the target is built again
        runner_spy:assert_called_with(root, { 'build', '//:foo1_and_foo2' })
    end)
end)

describe('run', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            BUILD = [[
                export_file(
                    name = "foo1",
                    src = "foo1.txt",
                )

                filegroup(
                    name = "foo1_and_foo2",
                    srcs = [
                        "foo1.txt",
                        "foo2.txt",
                    ],
                )
            ]],
            ['foo1.txt'] = 'foo1 content',
            ['foo2.txt'] = 'foo2 content',
        })
    end

    describe('in source file', function()
        it('should run target which uses file as input', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()
            local input_fake = InputFake:new()

            -- GIVEN we're editing a file
            vim.cmd('edit ' .. root .. '/foo2.txt')
            -- WHEN we call run
            please.run()
            -- THEN we're prompted to enter arguments for the program
            input_fake:assert_prompt('Enter program arguments: ')
            -- WHEN we enter some program arguments
            input_fake:enter_input('--foo foo --bar bar')
            -- THEN the target which the file is an input for is run with those arguments
            runner_spy:assert_called_with(root, { 'run', '//:foo1_and_foo2', '--', '--foo', 'foo', '--bar', 'bar' })
        end)

        it('should prompt to choose which target to run if there is more than one', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()
            local select_fake = SelectFake:new()
            local input_fake = InputFake:new()

            -- GIVEN we're editing a file referenced by multiple targets
            vim.cmd('edit ' .. root .. '/foo1.txt')
            -- WHEN we call run
            please.run()
            -- THEN we're prompted to choose which target to run
            select_fake:assert_prompt('Select target to run:')
            select_fake:assert_items({ '//:foo1', '//:foo1_and_foo2' })
            -- WHEN we select one of the targets
            select_fake:choose_item('//:foo1_and_foo2')
            -- THEN we're prompted to enter arguments for the program
            input_fake:assert_prompt('Enter program arguments: ')
            -- WHEN we enter some program arguments
            input_fake:enter_input('--foo foo --bar bar')
            -- THEN the target is run with those arguments
            runner_spy:assert_called_with(root, { 'run', '//:foo1_and_foo2', '--', '--foo', 'foo', '--bar', 'bar' })
        end)
    end)

    describe('in BUILD file', function()
        it('should run target under cursor', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()
            local input_fake = InputFake:new()

            -- GIVEN we're editing a BUILD file and our cursor is inside a target
            vim.cmd('edit ' .. root .. '/BUILD')
            vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- in definition of :foo1
            -- WHEN we call run
            please.run()
            -- THEN we're prompted to enter arguments for the program
            input_fake:assert_prompt('Enter program arguments: ')
            -- WHEN we enter some program arguments
            input_fake:enter_input('--foo foo --bar bar')
            -- THEN the target is run with those arguments
            runner_spy:assert_called_with(root, { 'run', '//:foo1', '--', '--foo', 'foo', '--bar', 'bar' })
        end)
    end)

    it('should add entry to command history', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local input_fake = InputFake:new()
        local select_fake = SelectFake:new()

        -- GIVEN that we've run a target
        vim.cmd('edit ' .. root .. '/foo2.txt')
        please.run()
        input_fake:enter_input('--foo foo --bar bar')
        -- WHEN we call history
        please.history()
        -- THEN we're prompted to pick a command to run again
        select_fake:assert_prompt('Pick command to run again:')
        select_fake:assert_items({ 'plz run //:foo1_and_foo2 -- --foo foo --bar bar' })
        -- WHEN we select the run command
        select_fake:choose_item('plz run //:foo1_and_foo2 -- --foo foo --bar bar')
        -- THEN the target is run again with the same arguments
        runner_spy:assert_called_with(root, { 'run', '//:foo1_and_foo2', '--', '--foo', 'foo', '--bar', 'bar' })
    end)

    it('should not include program args in command history entry when none are passed as input', function()
        local root = create_temp_tree()
        local input_fake = InputFake:new()
        local select_fake = SelectFake:new()

        -- GIVEN we've run a target and passed no arguments
        vim.cmd('edit ' .. root .. '/BUILD')
        vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- in definition of :foo1
        please.run()
        input_fake:enter_input('')
        -- WHEN we call history
        please.history()
        -- THEN the command history entry should not include the empty program args
        select_fake:assert_prompt('Pick command to run again:')
        select_fake:assert_items({ 'plz run //:foo1' })
    end)
end)

describe('test', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            ['foo/'] = {
                BUILD = [[
                    filegroup(
                        name = "foo1_test",
                        srcs = ["foo1_test.go"],
                    )

                    filegroup(
                        name = "foo1_and_foo2_test",
                        srcs = [
                            "foo1_test.go",
                            "foo2_test.go",
                        ],
                    )
                ]],
                ['foo1_test.go'] = [[
                    package foo_test

                    import "testing"

                    func TestPasses(t *testing.T) {
                    }

                    func TestFails(t *testing.T) {
                        t.Fatal("oh no")
                    }
                ]],
                ['foo2_test.go'] = [[
                    package foo_test

                    import "testing"

                    func TestPasses(t *testing.T) {
                    }

                    func TestFails(t *testing.T) {
                        t.Fatal("oh no")
                    }
                ]],
            },
        })
    end

    describe('in source file', function()
        it('should test target which uses file as input', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()

            -- GIVEN we're editing a file
            vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
            -- WHEN we call test
            please.test()
            -- THEN the target which the file is an input for is tested
            runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test' })
        end)

        it('should prompt to choose which target to test if there is more than one', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()
            local select_fake = SelectFake:new()

            -- GIVEN we're editing a file referenced by multiple targets
            vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
            -- WHEN we call test
            please.test()
            -- THEN we're prompted to choose which target to test
            select_fake:assert_prompt('Select target to test:')
            select_fake:assert_items({ '//foo:foo1_and_foo2_test', '//foo:foo1_test' })
            -- WHEN we select one of the targets
            select_fake:choose_item('//foo:foo1_and_foo2_test')
            -- THEN the test is run
            runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test' })
        end)

        describe('with under_cursor=true', function()
            it('should run test under the cursor', function()
                local root = create_temp_tree()
                local runner_spy = RunnerSpy:new()

                -- GIVEN we're editing a test file and the cursor is inside a test function
                vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
                vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
                -- WHEN we call test with under_cursor=true
                please.test({ under_cursor = true })
                -- THEN the test under the cursor is run
                runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })
            end)

            it('should add entry to command history', function()
                local root = create_temp_tree()
                local runner_spy = RunnerSpy:new()
                local select_fake = SelectFake:new()

                -- GIVEN we've tested the function under the cursor
                vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
                vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
                please.test({ under_cursor = true })
                -- WHEN we call history
                please.history()
                -- THEN we're prompted to pick a command to run again
                select_fake:assert_prompt('Pick command to run again:')
                select_fake:assert_items({ 'plz test //foo:foo1_and_foo2_test ^TestFails$' })
                -- WHEN we select the test command
                select_fake:choose_item('plz test //foo:foo1_and_foo2_test ^TestFails$')
                -- THEN the test is run again
                runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test', '^TestFails$' })
            end)
        end)
    end)

    describe('in BUILD file', function()
        it('should test target under cursor', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()

            -- GIVEN we're editing a BUILD file and our cursor is inside a target
            vim.cmd('edit ' .. root .. '/foo/BUILD')
            vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1_test
            -- WHEN we call test
            please.test()
            -- THEN the target is tested
            runner_spy:assert_called_with(root, { 'test', '//foo:foo1_test' })
        end)
    end)

    it('should add entry to command history', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local select_fake = SelectFake:new()

        -- GIVEN we've tested a file
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.test()
        -- WHEN we call history
        please.history()
        -- THEN we're prompted to pick a command to run again
        select_fake:assert_prompt('Pick command to run again:')
        select_fake:assert_items({ 'plz test //foo:foo1_and_foo2_test' })
        -- WHEN we select the test command
        select_fake:choose_item('plz test //foo:foo1_and_foo2_test')
        -- THEN the target is tested again
        runner_spy:assert_called_with(root, { 'test', '//foo:foo1_and_foo2_test' })
    end)
end)

---@class extmark
---@field [1] integer row
---@field [2] integer col
---@field [3] extmark_details?

---@class extmark_details : vim.api.keyset.extmark_details
---@field ns_id integer?

---@param path string
---@return extmark[]
local function extmarks(path)
    local bufnr = vim.fn.bufnr(path)
    local nvim_extmarks = vim.api.nvim_buf_get_extmarks(bufnr, -1, 0, -1, { details = true })
    local extmarks = {} ---@type extmark[]
    for _, value in ipairs(nvim_extmarks) do
        local row, col, details = value[2], value[3], value[4]
        details.ns_id = nil
        table.insert(extmarks, { row, col, details })
    end
    return extmarks
end

describe('cover', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            ['foo/'] = {
                BUILD = [[
                    filegroup(
                        name = "foo1_test",
                        srcs = ["foo1_test.go"],
                    )

                    filegroup(
                        name = "foo1_and_foo2_test",
                        srcs = [
                            "foo1_test.go",
                            "foo2_test.go",
                        ],
                    )
                ]],
                ['foo.go'] = [[
                    package foo

                    func Foo() string {
                        return "Foo"
                    }

                    func Foobar() string {
                        return "Foobar"
                    }
                ]],
                ['bar.go'] = [[
                    package foo

                    func Bar() string {
                        return "Bar"
                    }
                ]],
                ['baz.go'] = [[
                    package foo

                    func Baz() string {
                        return "Baz"
                    }
                ]],
                ['foobaz.go'] = [[
                    package foo

                    func Foobaz() string {
                        return "Foobaz"
                    }
                ]],
                ['foo1_test.go'] = [[
                    package foo_test

                    import "testing"

                    func TestPasses(t *testing.T) {
                    }

                    func TestFails(t *testing.T) {
                        t.Fatal("oh no")
                    }
                ]],
                ['foo2_test.go'] = [[
                    package foo_test

                    import "testing"

                    func TestPasses(t *testing.T) {
                    }

                    func TestFails(t *testing.T) {
                        t.Fatal("oh no")
                    }
                ]],
            },
            ['plz-out/'] = {
                ['log/'] = {
                    ['coverage.json'] = [[
                        {
                            "tests": {
                                "//foo:foo1_and_foo2_test": {
                                    "foo/foo.go": "NNCCCNUUU",
                                    "foo/bar.go": "NNUUU",
                                    "foo/baz.go": "NNUUU"
                                }
                            },
                            "files": {
                                "foo/foo.go": "NNCCCNUUU",
                                "foo/bar.go": "NNUUU",
                                "foo/baz.go": "NNUUU"
                            },
                            "stats": {
                                "total_coverage": 25,
                                "coverage_by_file": {
                                    "foo/foo.go": 50,
                                    "foo/bar.go": 0,
                                    "foo/baz.go": "0"
                                },
                                "coverage_by_directory": {
                                    "foo": 25
                                }
                            }
                        }
                    ]],
                },
            },
        })
    end
    local foobaz_go_coverage_json = [[
        {
            "tests": {
                "//foo:foo1_and_foo2_test": {
                    "foo/foobaz.go": "NNUUU"
                }
            },
            "files": {
                "foo/foobaz.go": "NNUUU"
            },
            "stats": {
                "total_coverage": 0,
                "coverage_by_file": {
                    "foo/foobaz.go": 0
                },
                "coverage_by_directory": {
                    "foo": 0
                }
            }
        }
    ]]
    local foobaz_go_coverage_json_lines = vim.split(foobaz_go_coverage_json, '\n', { plain = true })

    ---@type extmark[]
    local expected_foo_go_extmarks = {
        { 2, 0, { number_hl_group = 'PleaseCoverageCoveredLineNr', priority = 4096, right_gravity = true } },
        { 3, 0, { number_hl_group = 'PleaseCoverageCoveredLineNr', priority = 4096, right_gravity = true } },
        { 4, 0, { number_hl_group = 'PleaseCoverageCoveredLineNr', priority = 4096, right_gravity = true } },
        { 6, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
        { 7, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
        { 8, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
    }
    ---@type extmark[]
    local expected_bar_go_extmarks = {
        { 2, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
        { 3, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
        { 4, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
    }
    local expected_baz_go_extmarks = vim.deepcopy(expected_bar_go_extmarks)
    local expected_foobaz_go_extmarks = vim.deepcopy(expected_bar_go_extmarks)

    ---@param root string
    ---@return vim.quickfix.entry[]
    local function expected_qflist(root)
        return {
            {
                bufnr = vim.fn.bufnr(root .. '/foo/bar.go'),
                col = 0,
                end_col = 0,
                end_lnum = 0,
                lnum = 0,
                module = '',
                nr = 0,
                pattern = '',
                text = '0% covered',
                type = '',
                valid = 0,
                vcol = 0,
            },
            {
                bufnr = vim.fn.bufnr(root .. '/foo/baz.go'),
                col = 0,
                end_col = 0,
                end_lnum = 0,
                lnum = 0,
                module = '',
                nr = 0,
                pattern = '',
                text = '0% covered',
                type = '',
                valid = 0,
                vcol = 0,
            },
            {
                bufnr = vim.fn.bufnr(root .. '/foo/foo.go'),
                col = 0,
                end_col = 0,
                end_lnum = 0,
                lnum = 0,
                module = '',
                nr = 0,
                pattern = '',
                text = '50% covered',
                type = '',
                valid = 0,
                vcol = 0,
            },
        }
    end

    describe('in source file', function()
        it('should cover target which uses file as input', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()

            -- GIVEN we're editing a file
            vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
            -- WHEN we call cover
            please.cover()
            -- THEN the target which the file is an input for is covered
            runner_spy:assert_called_with(root, { 'cover', '//foo:foo1_and_foo2_test' })
        end)

        it('should prompt to choose which target to cover if there is more than one', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()
            local select_fake = SelectFake:new()

            -- GIVEN we're editing a file referenced by multiple targets
            vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
            -- WHEN we call cover
            please.cover()
            -- THEN we're prompted to choose which target to cover
            select_fake:assert_prompt('Select target to cover:')
            select_fake:assert_items({ '//foo:foo1_and_foo2_test', '//foo:foo1_test' })
            -- WHEN we select one of the targets
            select_fake:choose_item('//foo:foo1_and_foo2_test')
            -- THEN the target is covered
            runner_spy:assert_called_with(root, { 'cover', '//foo:foo1_and_foo2_test' })
        end)

        describe('with under_cursor=true', function()
            it('should run test under the cursor', function()
                local root = create_temp_tree()
                local runner_spy = RunnerSpy:new()

                -- GIVEN we're editing a test file and the cursor is inside a test function
                vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
                vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
                -- WHEN we call cover with under_cursor=true
                please.cover({ under_cursor = true })
                -- THEN the test under the cursor is run
                runner_spy:assert_called_with(root, { 'cover', '//foo:foo1_and_foo2_test', '^TestFails$' })
            end)

            it('should add entry to command history', function()
                local root = create_temp_tree()
                local runner_spy = RunnerSpy:new()
                local select_fake = SelectFake:new()

                -- GIVEN we've covered the test under the cursor
                vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
                vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
                please.cover({ under_cursor = true })
                -- WHEN we call history
                please.history()
                -- THEN we're prompted to pick a command to run again
                select_fake:assert_prompt('Pick command to run again:')
                select_fake:assert_items({ 'plz cover //foo:foo1_and_foo2_test ^TestFails$' })
                -- WHEN we select the cover command
                select_fake:choose_item('plz cover //foo:foo1_and_foo2_test ^TestFails$')
                -- THEN the test is covered again
                runner_spy:assert_called_with(root, { 'cover', '//foo:foo1_and_foo2_test', '^TestFails$' })
            end)
        end)
    end)

    describe('with quickfix=true', function()
        it('should populate quickfix with the coverage results', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()

            -- GIVEN we're editing a file
            vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
            -- WHEN we call cover with quickfix=true
            please.cover({ quickfix = true })
            finally(function()
                vim.cmd.cclose()
            end)
            -- THEN the test under the cursor is covered
            runner_spy:assert_called_with(root, { 'cover', '//foo:foo1_and_foo2_test' })
            -- THEN the quickfix is populated with the coverage results
            local qflist = vim.fn.getqflist({ items = 0, title = 0, winid = 0 })
            assert.same(expected_qflist(root), qflist.items, 'incorrect quickfix list items')
            assert.equal('[please.nvim] Test Coverage', qflist.title, 'incorrect quickfix list title')
            -- THEN the quickfix list is open
            assert.is_true(qflist.winid > 0, 'expected quickfix list to be open')
            -- THEN the runner is maximised
            runner_spy:assert_maximise_called()
        end)

        it('should add entry to command history', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()
            local select_fake = SelectFake:new()

            -- GIVEN we've covered a target and populated the quickfix list
            vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
            please.cover({ quickfix = true })
            finally(function()
                vim.cmd.cclose()
            end)
            -- GIVEN the quickfix list has been closed and reset
            vim.cmd.cclose()
            vim.fn.setqflist({})
            -- WHEN we call history
            please.history()
            -- THEN we're prompted to pick a command to run again
            select_fake:assert_prompt('Pick command to run again:')
            select_fake:assert_items({ 'plz cover //foo:foo1_and_foo2_test' })
            -- WHEN we select the cover command
            select_fake:choose_item('plz cover //foo:foo1_and_foo2_test')
            -- THEN the target is covered again
            runner_spy:assert_called_with(root, { 'cover', '//foo:foo1_and_foo2_test' })
            -- THEN the quickfix is populated with the coverage results
            local qflist = vim.fn.getqflist({ items = 0, title = 0, winid = 0 })
            assert.same(expected_qflist(root), qflist.items, 'incorrect quickfix list items')
            assert.equal('[please.nvim] Test Coverage', qflist.title, 'incorrect quickfix list title')
            -- THEN the quickfix list is open
            assert.is_true(qflist.winid > 0, 'expected quickfix list to be open')
            -- THEN the runner is maximised
            runner_spy:assert_maximise_called()
        end)
    end)

    describe('in BUILD file', function()
        it('should cover target under cursor', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()

            -- GIVEN we're editing a BUILD file and our cursor is inside a target
            vim.cmd('edit ' .. root .. '/foo/BUILD')
            vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1_test
            -- WHEN we call cover
            please.cover()
            -- THEN the target is covered
            runner_spy:assert_called_with(root, { 'cover', '//foo:foo1_test' })
        end)
    end)

    it('should highlight line numbers when plz cover exits with 0 status', function()
        local root = create_temp_tree()
        RunnerSpy:new(0)

        -- GIVEN we've opened some files in multiple windows that coverage will be calculated for
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        vim.cmd('vsp ' .. root .. '/foo/bar.go')
        -- GIVEN we're editing a file in another window
        vim.cmd('vsp ' .. root .. '/foo/foo2_test.go')
        -- WHEN we cover a target
        please.cover()
        -- THEN the current buffer contains no extmarks
        local foo2_test_go_extmarks = extmarks(root .. '/foo/foo2_test.go')
        assert.same({}, foo2_test_go_extmarks, 'expected no extmarks in foo/foo2_test.go')
        -- THEN the buffers of the other open windows contain extmarks highlighting the covered and uncovered line numbers
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        local bar_go_extmarks = extmarks(root .. '/foo/bar.go')
        assert.same(expected_foo_go_extmarks, foo_go_extmarks, 'incorrect extmarks in foo/foo.go')
        assert.same(expected_bar_go_extmarks, bar_go_extmarks, 'incorrect extmarks in foo/bar.go')
        -- WHEN we open another file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/baz.go')
        -- THEN the buffer contains extmarks highlighting the covered and uncovered line numbers
        local baz_go_extmarks = extmarks(root .. '/foo/baz.go')
        assert.same(expected_baz_go_extmarks, baz_go_extmarks, 'incorrect extmarks in foo/baz.go')
        -- WHEN we open another file which coverage was not calculated for
        vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
        -- THEN the buffer contains no extmarks
        local foo1_test_go_extmarks = extmarks(root .. '/foo/foo1_test.go')
        assert.same({}, foo1_test_go_extmarks, 'expected no extmarks in foo/foo1_test.go')
    end)

    it('should highlight line numbers when plz cover exits with 7 status', function()
        local root = create_temp_tree()
        RunnerSpy:new(7)

        -- GIVEN we've covered a target
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.cover()
        -- WHEN we open a file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- THEN the buffer contains extmarks highlighting the covered and uncovered line numbers
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.same(expected_foo_go_extmarks, foo_go_extmarks, 'incorrect extmarks in foo/foo.go')
    end)

    it('should not highlight anything when plz cover exits with 1 status', function()
        local root = create_temp_tree()
        RunnerSpy:new(1)

        -- GIVEN we've covered a target
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.cover()
        -- WHEN we open the files that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        vim.cmd('edit ' .. root .. '/foo/bar.go')
        -- THEN neither buffer contains any extmarks
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        local bar_go_extmarks = extmarks(root .. '/foo/bar.go')
        assert.same({}, foo_go_extmarks, 'expected no extmarks in foo/foo.go')
        assert.same({}, bar_go_extmarks, 'expected no extmarks in foo/bar.go')
    end)

    it('should highlight lines only if lines set in options and lines_numbers not', function()
        local expected_foo_go_extmarks = vim.deepcopy(expected_foo_go_extmarks)
        for _, extmark in ipairs(expected_foo_go_extmarks) do
            local details = extmark[3] or {}
            if details.number_hl_group == 'PleaseCoverageCoveredLineNr' then
                details.line_hl_group = 'PleaseCoverageCoveredLine'
            elseif details.number_hl_group == 'PleaseCoverageUncoveredLineNr' then
                details.line_hl_group = 'PleaseCoverageUncoveredLine'
            else
                error(string.format('unexpected number_hl_group: %q', details.number_hl_group))
            end
            details.number_hl_group = nil
        end

        local root = create_temp_tree()
        RunnerSpy:new(0)

        please.setup({
            coverage = {
                highlighting = { lines = true, line_numbers = false },
            },
        })
        finally(function()
            please.setup(default_opts)
        end)

        -- GIVEN we've covered a target
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.cover()
        -- WHEN we open a file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- THEN the buffer contains extmarks highlighting the covered and uncovered lines
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.same(expected_foo_go_extmarks, foo_go_extmarks, 'incorrect extmarks in foo/foo.go')
    end)

    it('should highlight lines and line numbers if both set in options', function()
        local expected_foo_go_extmarks = vim.deepcopy(expected_foo_go_extmarks)
        for _, extmark in ipairs(expected_foo_go_extmarks) do
            local details = extmark[3] or {}
            if details.number_hl_group == 'PleaseCoverageCoveredLineNr' then
                details.line_hl_group = 'PleaseCoverageCoveredLine'
            elseif details.number_hl_group == 'PleaseCoverageUncoveredLineNr' then
                details.line_hl_group = 'PleaseCoverageUncoveredLine'
            else
                error(string.format('unexpected number_hl_group: %q', details.number_hl_group))
            end
        end

        local root = create_temp_tree()
        RunnerSpy:new(0)

        please.setup({
            coverage = {
                highlighting = { lines = true, line_numbers = true },
            },
        })
        finally(function()
            please.setup(default_opts)
        end)

        -- GIVEN we've covered a target
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.cover()
        -- WHEN we open a file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- THEN the buffer contains extmarks highlighting the covered and uncovered lines and line numbers
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.same(expected_foo_go_extmarks, foo_go_extmarks, 'incorrect extmarks in foo/foo.go')
    end)

    it('should not highlight anything if lines and line_numbers not set in options', function()
        local root = create_temp_tree()
        RunnerSpy:new(0)

        please.setup({
            coverage = {
                highlighting = { lines = false, line_numbers = false },
            },
        })
        finally(function()
            please.setup(default_opts)
        end)

        -- GIVEN we've covered a target
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.cover()
        -- WHEN we open a file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- THEN the buffer contains no extmarks
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.same({}, foo_go_extmarks, 'expected no extmarks in foo/foo.go')
    end)

    it('should clear highlights created by previous cover call', function()
        local root = create_temp_tree()
        RunnerSpy:new(0)

        -- GIVEN we've covered a target
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.cover()
        -- GIVEN we've opened a file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- GIVEN the buffer contains extmarks
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.is_true(#foo_go_extmarks > 0, 'expected extmarks in foo/foo.go')
        -- GIVEN the files that coverage will be calculated for has changed
        vim.fn.writefile(foobaz_go_coverage_json_lines, root .. '/plz-out/log/coverage.json')
        -- GIVEN we've covered the target again
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.cover()
        -- WHEN we open a file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foobaz.go')
        -- THEN the buffer contains extmarks highlighting the covered and uncovered line numbers
        local foobaz_go_extmarks = extmarks(root .. '/foo/foobaz.go')
        assert.same(expected_foobaz_go_extmarks, foobaz_go_extmarks, 'incorrect extmarks in foo/foobaz.go')
        -- THEN the extmarks have been removed from the previously highlighted buffer
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.same({}, foo_go_extmarks, 'expected no extmarks in foo/foo.go')
        -- WHEN we open the file that was previously highlighted
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- THEN the buffer contains no extmarks
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.same({}, foo_go_extmarks, 'expected no extmarks in foo/foo.go')
    end)

    it('should add entry to command history', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local select_fake = SelectFake:new()

        -- GIVEN we've covered a target
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.cover()
        -- GIVEN we've opened a file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- GIVEN the buffer contains extmarks
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.is_true(#foo_go_extmarks > 0, 'expected extmarks in foo/foo.go')
        -- GIVEN the files that coverage will be calculated for has changed
        vim.fn.writefile(foobaz_go_coverage_json_lines, root .. '/plz-out/log/coverage.json')
        -- WHEN we call history
        please.history()
        -- THEN we're prompted to pick a command to run again
        select_fake:assert_prompt('Pick command to run again:')
        select_fake:assert_items({ 'plz cover //foo:foo1_and_foo2_test' })
        -- WHEN we select the cover command
        select_fake:choose_item('plz cover //foo:foo1_and_foo2_test')
        -- THEN the target is covered again
        runner_spy:assert_called_with(root, { 'cover', '//foo:foo1_and_foo2_test' })
        -- WHEN we open a file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foobaz.go')
        -- THEN the buffer contains extmarks highlighting the covered and uncovered line numbers
        local foobaz_go_extmarks = extmarks(root .. '/foo/foobaz.go')
        assert.same(expected_foobaz_go_extmarks, foobaz_go_extmarks, 'incorrect extmarks in foo/foobaz.go')
        -- THEN the extmarks have been removed from the previously highlighted buffer
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.same({}, foo_go_extmarks, 'expected no extmarks in foo/foo.go')
    end)
end)

describe('toggle_coverage_highlighting', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            ['foo/'] = {
                BUILD = [[
                    filegroup(
                        name = "foo_test",
                        srcs = [
                            "foo1_test.go",
                            "foo2_test.go",
                        ],
                    )
                ]],
                ['foo.go'] = [[
                    package foo

                    func Foo() string {
                        return "Foo"
                    }

                    func Foobar() string {
                        return "Foobar"
                    }
                ]],
                ['bar.go'] = [[
                    package foo

                    func Bar() string {
                        return "Bar"
                    }
                ]],
                ['baz.go'] = [[
                    package foo

                    func Baz() string {
                        return "Baz"
                    }
                ]],
                ['foo1_test.go'] = [[
                    package foo_test
                ]],
                ['foo2_test.go'] = [[
                    package foo_test
                ]],
            },
            ['plz-out/'] = {
                ['log/'] = {
                    ['coverage.json'] = [[
                        {
                            "tests": {
                                "//foo:foo1_test": {
                                    "foo/foo.go": "NNCCCNUUU",
                                    "foo/bar.go": "NNUUU",
                                    "foo/baz.go": "NNUUU"
                                }
                            },
                            "files": {
                                "foo/foo.go": "NNCCCNUUU",
                                "foo/bar.go": "NNUUU",
                                "foo/baz.go": "NNUUU"
                            },
                            "stats": {
                                "total_coverage": 25,
                                "coverage_by_file": {
                                    "foo/foo.go": 50,
                                    "foo/bar.go": 0,
                                    "foo/baz.go": "0"
                                },
                                "coverage_by_directory": {
                                    "foo": 25
                                }
                            }
                        }
                    ]],
                },
            },
        })
    end

    ---@type extmark[]
    local expected_foo_go_extmarks = {
        { 2, 0, { number_hl_group = 'PleaseCoverageCoveredLineNr', priority = 4096, right_gravity = true } },
        { 3, 0, { number_hl_group = 'PleaseCoverageCoveredLineNr', priority = 4096, right_gravity = true } },
        { 4, 0, { number_hl_group = 'PleaseCoverageCoveredLineNr', priority = 4096, right_gravity = true } },
        { 6, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
        { 7, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
        { 8, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
    }
    ---@type extmark[]
    local expected_bar_go_extmarks = {
        { 2, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
        { 3, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
        { 4, 0, { number_hl_group = 'PleaseCoverageUncoveredLineNr', priority = 4096, right_gravity = true } },
    }

    it('disbales coverage highlighting when enabled', function()
        local root = create_temp_tree()
        RunnerSpy:new(0)

        -- GIVEN we've covered a target
        vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
        please.cover()
        -- GIVEN we've opened a file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- GIVEN the buffer contains extmarks
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.is_true(#foo_go_extmarks > 0, 'expected extmarks in foo/foo.go')
        -- GIVEN we've opened another file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/bar.go')
        -- GIVEN the buffer contains extmarks
        local bar_go_extmarks = extmarks(root .. '/foo/bar.go')
        assert.is_true(#bar_go_extmarks > 0, 'expected extmarks in foo/bar.go')
        -- WHEN we call toggle_coverage_highlighting
        please.toggle_coverage_highlighting()
        -- THEN the extmarks have been removed from the current buffer
        local bar_go_extmarks = extmarks(root .. '/foo/bar.go')
        assert.same({}, bar_go_extmarks, 'expected no extmarks in foo/bar.go')
        -- WHEN we open the file that was previously highlighted
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- THEN the buffer contains no extmarks
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.same({}, foo_go_extmarks, 'expected no extmarks in foo/foo.go')
        -- WHEN we open another file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/baz.go')
        -- THEN the buffer contains no extmarks
        local baz_go_extmarks = extmarks(root .. '/foo/baz.go')
        assert.same({}, baz_go_extmarks, 'expected no extmarks in foo/baz.go')
        -- WHEN we open another file which coverage was not calculated for
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        -- THEN the buffer contains no extmarks
        local foo1_test_go_extmarks = extmarks(root .. '/foo/foo2_test.go')
        assert.same({}, foo1_test_go_extmarks, 'expected no extmarks in foo/foo2_test.go')
    end)

    it('enables coverage highlighting when disabled', function()
        local root = create_temp_tree()
        RunnerSpy:new(0)

        -- GIVEN we've covered a target
        vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
        please.cover()
        -- GIVEN we've disabled coverage highlighting
        please.toggle_coverage_highlighting()
        -- GIVEN we've opened a file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- GIVEN the buffer contains no extmarks
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.same({}, foo_go_extmarks, 'expected extmarks in foo/foo.go')
        -- WHEN we call toggle_coverage_highlighting
        please.toggle_coverage_highlighting()
        -- THEN the buffer contains extmarks highlighting the covered and uncovered line numbers
        local foo_go_extmarks = extmarks(root .. '/foo/foo.go')
        assert.same(expected_foo_go_extmarks, foo_go_extmarks, 'incorrect extmarks in foo/foo.go')
        -- WHEN we open another file that coverage was calculated for
        vim.cmd('edit ' .. root .. '/foo/bar.go')
        -- THEN the buffer contains extmarks highlighting the covered and uncovered line numbers
        local bar_go_extmarks = extmarks(root .. '/foo/bar.go')
        assert.same(expected_bar_go_extmarks, bar_go_extmarks, 'incorrect extmarks in foo/bar.go')
        -- WHEN we open another file which coverage was not calculated for
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        -- THEN the buffer contains no extmarks
        local foo1_test_go_extmarks = extmarks(root .. '/foo/foo2_test.go')
        assert.same({}, foo1_test_go_extmarks, 'expected no extmarks in foo/foo2_test.go')
    end)
end)

describe('debug', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            ['foo/'] = {
                BUILD = [[
                    # debug command expects rule names to have format $lang_xxx
                    go_binary = genrule
                    go_test = gentest

                    go_binary(
                        name = "foo",
                        srcs = ["foo.go"],
                        cmd = None
                    )

                    go_test(
                        name = "foo1_test",
                        srcs = ["foo1_test.go"],
                        test_cmd = "",
                    )

                    go_test(
                        name = "foo1_and_foo2_test",
                        srcs = [
                            "foo1_test.go",
                            "foo2_test.go",
                        ],
                        test_cmd = "",
                    )
                ]],
                ['foo.go'] = [[
                    package foo

                    import "fmt"

                    func main() {
                        fmt.Println("Hello, World!")
                    }
                ]],
                ['foo1_test.go'] = [[
                    package foo_test

                    import "testing"

                    func TestPasses(t *testing.T) {
                    }

                    func TestFails(t *testing.T) {
                        t.Fatal("oh no")
                    }
                ]],
                ['foo2_test.go'] = [[
                    package foo_test

                    import "testing"

                    func TestPasses(t *testing.T) {
                    }

                    func TestFails(t *testing.T) {
                        t.Fatal("oh no")
                    }
                ]],
            },
        })
    end

    describe('in source file', function()
        it('should debug target which uses file as input', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()
            local debug_launcher_spy = DebugLauncherSpy:new('go')

            -- GIVEN we're editing a file
            vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
            -- WHEN we call debug
            please.debug()
            -- THEN the target which the file is an input for is built with dbg config
            runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
            -- THEN the runner is minimised
            runner_spy:assert_minimise_called()
            -- THEN the debug launcher is called
            debug_launcher_spy:assert_called_with(root, '//foo:foo1_and_foo2_test', {})
        end)

        it('should prompt to choose which target to debug if there is more than one', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()
            local select_fake = SelectFake:new()
            local debug_launcher_spy = DebugLauncherSpy:new('go')

            -- GIVEN we're editing a file referenced by multiple targets
            vim.cmd('edit ' .. root .. '/foo/foo1_test.go')
            -- WHEN we call debug
            please.debug()
            -- THEN we're prompted to choose which target to debug
            select_fake:assert_prompt('Select target to debug:')
            select_fake:assert_items({ '//foo:foo1_and_foo2_test', '//foo:foo1_test' })
            -- WHEN we select one of the targets
            select_fake:choose_item('//foo:foo1_and_foo2_test')
            -- THEN the target is built with dbg config
            runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
            -- THEN the runner is minimised
            runner_spy:assert_minimise_called()
            -- THEN the debug launcher is called
            debug_launcher_spy:assert_called_with(root, '//foo:foo1_and_foo2_test', {})
        end)

        describe('with under_cursor=true', function()
            it('should debug test under cursor', function()
                local root = create_temp_tree()
                local runner_spy = RunnerSpy:new()
                local debug_launcher_spy = DebugLauncherSpy:new('go')

                -- GIVEN we're editing a test file and the cursor is inside a test function
                vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
                vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
                -- WHEN we call debug with under_cursor=true
                please.debug({ under_cursor = true })
                -- THEN the test target is built with dbg config
                runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
                -- THEN the runner is minimised
                runner_spy:assert_minimise_called()
                -- THEN the debug launcher is called with the test under the cursor
                debug_launcher_spy:assert_called_with(root, '//foo:foo1_and_foo2_test', { '^TestFails$' })
            end)

            it('should add entry to command history', function()
                local root = create_temp_tree()
                local runner_spy = RunnerSpy:new()
                local select_fake = SelectFake:new()
                local debug_launcher_spy = DebugLauncherSpy:new('go')

                -- GIVEN we've debugged the function under the cursor
                vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
                vim.api.nvim_win_set_cursor(0, { 9, 4 }) -- inside body of TestFails
                please.debug({ under_cursor = true })
                -- WHEN we call history
                please.history()
                -- THEN we're prompted to pick a command to run again
                select_fake:assert_prompt('Pick command to run again:')
                select_fake:assert_items({ 'plz debug //foo:foo1_and_foo2_test ^TestFails$' })
                -- WHEN we select the debug command
                select_fake:choose_item('plz debug //foo:foo1_and_foo2_test ^TestFails$')
                -- THEN the test target is built with dbg config
                runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
                -- THEN the runner is minimised
                runner_spy:assert_minimise_called()
                -- THEN the debug launcher is called
                debug_launcher_spy:assert_called_with(root, '//foo:foo1_and_foo2_test', { '^TestFails$' })
            end)
        end)
    end)

    describe('in BUILD file', function()
        it('should debug target under cursor', function()
            local root = create_temp_tree()
            local runner_spy = RunnerSpy:new()
            local debug_launcher_spy = DebugLauncherSpy:new('go')

            -- GIVEN we're editing a BUILD file and our cursor is inside a target
            vim.cmd('edit ' .. root .. '/foo/BUILD')
            vim.api.nvim_win_set_cursor(0, { 12, 4 }) -- inside definition of :foo1_test
            -- WHEN we call debug
            please.debug()
            -- THEN the target is built with dbg config
            runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_test' })
            -- THEN the runner is minimised
            runner_spy:assert_minimise_called()
            -- THEN the debug launcher is called
            debug_launcher_spy:assert_called_with(root, '//foo:foo1_test', {})
        end)
    end)

    it('should prompt for arguments for non-test target', function()
        local root = create_temp_tree()
        local input_fake = InputFake:new()
        local runner_spy = RunnerSpy:new()
        local debug_launcher_spy = DebugLauncherSpy:new('go')

        -- GIVEN we're editing a file which is an input to a non-test target
        vim.cmd('edit ' .. root .. '/foo/foo.go')
        -- WHEN we call debug
        please.debug()
        -- THEN we're prompted to enter arguments for the program
        input_fake:assert_prompt('Enter program arguments: ')
        -- WHEN we enter some program arguments
        input_fake:enter_input('--foo foo --bar bar')
        -- THEN the target which the file is an input for is built with dbg config
        runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo' })
        -- THEN the runner is minimised
        runner_spy:assert_minimise_called()
        -- THEN the debug launcher is called with those arguments
        debug_launcher_spy:assert_called_with(root, '//foo', { '--', '--foo', 'foo', '--bar', 'bar' })
    end)

    it('should not minimise runner when building target fails', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new(1)
        local debug_launcher_spy = DebugLauncherSpy:new('go')

        -- GIVEN we're editing a file
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        -- WHEN we call debug
        please.debug()
        -- THEN the runner is not minimised
        runner_spy:assert_minimise_not_called()
        -- THEN the debug launcher is not called
        debug_launcher_spy:assert_not_called()
    end)

    it('should add entry to command history', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local select_fake = SelectFake:new()
        local debug_launcher_spy = DebugLauncherSpy:new('go')

        -- GIVEN we've debugged a file
        vim.cmd('edit ' .. root .. '/foo/foo2_test.go')
        please.debug()
        -- WHEN we call history
        please.history()
        -- THEN we're prompted to pick a command to run again
        select_fake:assert_prompt('Pick command to run again:')
        select_fake:assert_items({ 'plz debug //foo:foo1_and_foo2_test' })
        -- WHEN we select the debug command
        select_fake:choose_item('plz debug //foo:foo1_and_foo2_test')
        -- THEN the target is built again with dbg config
        runner_spy:assert_called_with(root, { 'build', '--config', 'dbg', '//foo:foo1_and_foo2_test' })
        -- THEN the runner is minimised
        runner_spy:assert_minimise_called()
        -- THEN the debug launcher is called
        debug_launcher_spy:assert_called_with(root, '//foo:foo1_and_foo2_test', {})
    end)
end)

describe('command', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            BUILD = [[
                export_file(
                    name = "foo",
                    src = "foo.txt",
                )
            ]],
            ['foo.txt'] = 'foo content',
        })
    end

    it('should call plz with the provided arguments', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()

        -- GIVEN we're editing a file
        vim.cmd('edit ' .. root .. '/foo.txt')
        -- WHEN we call command with some arguments
        please.command('build', '//:foo')
        -- THEN plz is called with those arguments
        runner_spy:assert_called_with(root, { 'build', '//:foo' })
    end)

    it('should add entry to command history', function()
        local root = create_temp_tree()
        local runner_spy = RunnerSpy:new()
        local select_fake = SelectFake:new()

        -- GIVEN we've run a command
        vim.cmd('edit ' .. root .. '/foo.txt')
        please.command('build', '//:foo')
        -- WHEN we call history
        please.history()
        -- THEN we're prompted to pick a command to run again
        select_fake:assert_prompt('Pick command to run again:')
        select_fake:assert_items({ 'plz build //:foo' })
        -- WHEN we select the command
        select_fake:choose_item('plz build //:foo')
        -- THEN the command is run again
        runner_spy:assert_called_with(root, { 'build', '//:foo' })
    end)
end)

describe('history', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            BUILD = [[
                export_file(
                    name = "foo1",
                    src = "foo1.txt",
                )

                export_file(
                    name = "foo2",
                    src = "foo2.txt",
                )

                export_file(
                    name = "foo3",
                    src = "foo3.txt",
                )
            ]],
            ['foo1.txt'] = 'foo1 content',
            ['foo2.txt'] = 'foo2 content',
            ['foo3.txt'] = 'foo3 content',
        })
    end

    it('should order items from most to least recent', function()
        local root = create_temp_tree()
        local select_fake = SelectFake:new()

        -- GIVEN we've built three targets, one after the other
        for _, filename in ipairs({ 'foo1.txt', 'foo2.txt', 'foo3.txt' }) do
            vim.cmd('edit ' .. root .. '/' .. filename)
            please.build()
        end
        -- WHEN we call history
        please.history()
        -- THEN the commands to build each target are ordered from most to least recent
        select_fake:assert_items({ 'plz build //:foo3', 'plz build //:foo2', 'plz build //:foo1' })
    end)

    it('should move rerun command to the top of history', function()
        local root = create_temp_tree()
        local select_fake = SelectFake:new()

        -- GIVEN we've built three targets, one after the other
        for _, filename in ipairs({ 'foo1.txt', 'foo2.txt', 'foo3.txt' }) do
            vim.cmd('edit ' .. root .. '/' .. filename)
            please.build()
        end
        -- WHEN we call history
        please.history()
        -- AND rerun the second command
        select_fake:assert_items({ 'plz build //:foo3', 'plz build //:foo2', 'plz build //:foo1' })
        select_fake:choose_item('plz build //:foo2')
        -- THEN it has been moved to the top of the history
        please.history()
        select_fake:assert_items({ 'plz build //:foo2', 'plz build //:foo3', 'plz build //:foo1' })
    end)

    it('should display the n most recent items', function()
        local root = create_temp_tree()
        local select_fake = SelectFake:new()

        -- GIVEN we've built three targets, one after the other
        please.setup({ max_history_items = 2 })
        finally(function()
            please.setup(default_opts)
        end)
        for _, filename in ipairs({ 'foo1.txt', 'foo2.txt', 'foo3.txt' }) do
            vim.cmd('edit ' .. root .. '/' .. filename)
            please.build()
        end
        -- WHEN we call history
        please.history()
        -- THEN the commands to build the two most recently built target are ordered from most to least recent
        select_fake:assert_items({ 'plz build //:foo3', 'plz build //:foo2' })
    end)
end)

describe('clear_history', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            BUILD = [[
                export_file(
                    name = "foo1",
                    src = "foo1.txt",
                )

                export_file(
                    name = "foo2",
                    src = "foo2.txt",
                )
            ]],
            ['foo1.txt'] = 'foo1 content',
            ['foo2.txt'] = 'foo2 content',
        })
    end

    it('should delete all stored commands', function()
        local root = create_temp_tree()
        local select_fake = SelectFake:new()

        -- GIVEN we've built a target
        vim.cmd('edit ' .. root .. '/' .. 'foo1.txt')
        please.build()
        -- WHEN we call clear_history
        please.clear_history()
        -- THEN history does not prompt for a command to run again because the stored commands have been deleted
        please.history()
        select_fake:assert_not_called()
        -- WHEN we build another target
        vim.cmd('edit ' .. root .. '/' .. 'foo2.txt')
        please.build()
        -- WHEN we call history
        please.history()
        -- THEN the command to build the new target is the only one displayed
        select_fake:assert_items({ 'plz build //:foo2' })
    end)
end)

describe('jump_to_target', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            BUILD = [[
                export_file(
                    name = "foo1",
                    src = "foo1.txt",
                )

                filegroup(
                    name = "foo1_and_foo2",
                    srcs = [
                        "foo1.txt",
                        "foo2.txt",
                    ],
                )
            ]],
            ['foo1.txt'] = 'foo1 content',
            ['foo2.txt'] = 'foo2 content',
        })
    end

    it('should jump from file to target which uses it as an input', function()
        local root = create_temp_tree()

        -- GIVEN we're editing a file
        vim.cmd('edit ' .. root .. '/foo2.txt')
        -- WHEN we call jump_to_target
        please.jump_to_target()
        -- THEN the BUILD file containing the target for the file is opened
        assert.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
        -- AND the cursor is moved to the target
        assert.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')
    end)

    it('should prompt to choose which target to jump to if there is more than one', function()
        local root = create_temp_tree()
        local select_fake = SelectFake:new()

        -- GIVEN we're editing a file referenced by multiple targets
        vim.cmd('edit ' .. root .. '/foo1.txt')
        -- WHEN we call jump_to_target
        please.jump_to_target()
        -- THEN we're prompted to choose which target to jump to
        select_fake:assert_prompt('Select target to jump to:')
        select_fake:assert_items({ '//:foo1', '//:foo1_and_foo2' })
        -- WHEN we select one of the targets
        select_fake:choose_item('//:foo1_and_foo2')
        -- THEN the BUILD file containing the chosen target is opened
        assert.equal(root .. '/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
        -- AND the cursor is moved to the target
        assert.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')
    end)
end)

describe('look_up_target', function()
    it('should jump to target which uses it as an input', function()
        local root = temptree.create({
            '.plzconfig',
            ['pkg/'] = {
                BUILD = [[
                    export_file(
                        name = "foo1",
                        src = "foo1.txt",
                    )

                    export_file(
                        name = "foo2",
                        src = "foo2.txt",
                    )
                ]],
                'foo1.txt',
                'foo2.txt',
            },
        })
        local input_fake = InputFake:new()

        -- GIVEN we're editing a file
        vim.cmd('edit ' .. root .. '/foo1.txt')
        -- WHEN we call look_up_target
        please.look_up_target()
        -- THEN we're prompted to enter the target to look up
        input_fake:assert_prompt('Enter target to look up: ')
        -- WHEN we enter a target
        input_fake:enter_input('//pkg:foo2')
        vim.wait(500)
        -- THEN the BUILD file containing the target is opened
        assert.equal(root .. '/pkg/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
        -- AND the cursor is moved to the target
        assert.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')
    end)

    it('should jump to target under cursor', function()
        local root = temptree.create({
            '.plzconfig',
            ['pkg/'] = {
                BUILD = [[
                    export_file(
                        name = "foo1",
                        src = "foo1.txt",
                    )

                    export_file(
                        name = "foo2",
                        src = "foo2.txt",
                    )
                ]],
                ['foo1.txt'] = [[
                    line before
                    before //pkg:foo2 after
                    line after
                ]],
                'foo2.txt',
            },
        })

        -- GIVEN we're editing a file and our cursor is inside a build label
        vim.cmd('edit ' .. root .. '/pkg/foo1.txt')
        vim.api.nvim_win_set_cursor(0, { 2, 12 }) -- inside //pkg:foo2
        -- WHEN we call look_up_target
        please.look_up_target()
        -- THEN the BUILD file containing the target is opened
        assert.equal(root .. '/pkg/BUILD', vim.api.nvim_buf_get_name(0), 'incorrect BUILD file')
        -- AND the cursor is moved to the target
        assert.same({ 6, 0 }, vim.api.nvim_win_get_cursor(0), 'incorrect cursor position')
    end)
end)

describe('yank', function()
    local function create_temp_tree()
        return temptree.create({
            '.plzconfig',
            BUILD = [[
                export_file(
                    name = "foo1",
                    src = "foo1.txt",
                )

                filegroup(
                    name = "foo1_and_foo2",
                    srcs = [
                        "foo1.txt",
                        "foo2.txt",
                    ],
                )
            ]],
            ['foo1.txt'] = 'foo1 content',
            ['foo2.txt'] = 'foo2 content',
        })
    end

    describe('in source file', function()
        it('should yank build label of target which uses file as input', function()
            local root = create_temp_tree()

            -- GIVEN we're editing a file
            vim.cmd('edit ' .. root .. '/foo2.txt')
            -- WHEN we call yank
            please.yank()
            -- THEN the build label of the target which the file is an input for is yanked into the " and * registers
            assert.equal('//:foo1_and_foo2', vim.fn.getreg('"'), 'incorrect value in " register')
            assert.equal('//:foo1_and_foo2', vim.fn.getreg('*'), 'incorrect value in * register')
        end)

        it("should prompt to choose which target's build label to yank if there is more than one", function()
            local root = create_temp_tree()
            local select_fake = SelectFake:new()

            -- GIVEN we're editing a file referenced by multiple targets
            vim.cmd('edit ' .. root .. '/foo1.txt')
            -- WHEN we call yank
            please.yank()
            -- THEN we're prompted to choose which build label to yank
            select_fake:assert_prompt('Select build label to yank:')
            select_fake:assert_items({ '//:foo1', '//:foo1_and_foo2' })
            -- WHEN we select one of the build labels
            select_fake:choose_item('//:foo1_and_foo2')
            -- THEN the build label is yanked into the " and * registers
            assert.equal('//:foo1_and_foo2', vim.fn.getreg('"'), 'incorrect value in " register')
            assert.equal('//:foo1_and_foo2', vim.fn.getreg('*'), 'incorrect value in * register')
        end)
    end)

    describe('in BUILD file', function()
        it('should yank target under cursor', function()
            local root = create_temp_tree()

            -- GIVEN we're editing a BUILD file and our cursor is inside a target
            vim.cmd('edit ' .. root .. '/BUILD')
            vim.api.nvim_win_set_cursor(0, { 2, 4 }) -- inside definition of :foo1
            -- WHEN we call yank
            please.yank()
            -- THEN the target's build label is yanked into the " and * register
            local unnamed = vim.fn.getreg('"')
            local star = vim.fn.getreg('*')
            assert.equal('//:foo1', unnamed, 'incorrect value in " register')
            assert.equal('//:foo1', star, 'incorrect value in * register')
        end)
    end)
end)
