local M = {}

---Wraps the busted it function so that any messages emitted through vim.notify or print during execution of the test
---block are included in the test failure.
---@param it fun(name:string, block:fun())
---@return fun(name:string, block:fun())
function M.wrap_it(it)
    ---Define a test that will pass, fail, or error.
    ---
    ---You can also use `spec()` and `test()` as aliases.
    ---
    ---## Example
    ---```
    ---describe("Test something", function()
    ---    it("Runs a test", function()
    ---        assert.is.True(10 == 10)
    ---    end)
    ---end)
    ---```
    ---@param name string
    ---@param block fun()
    return function(name, block)
        it(name, function()
            local logs = {}
            local original_notify = vim.notify
            ---@diagnostic disable-next-line: unused-local, duplicate-set-field
            vim.notify = function(msg, level, opts)
                local level_names = {
                    [vim.log.levels.TRACE] = 'TRACE',
                    [vim.log.levels.DEBUG] = 'DEBUG',
                    [vim.log.levels.INFO] = 'INFO',
                    [vim.log.levels.WARN] = 'WARN',
                    [vim.log.levels.ERROR] = 'ERROR',
                }
                local level_name = level_names[level] or 'INFO'
                table.insert(logs, string.format('%5s: %s', level_name, msg))
            end

            local stdout_lines = {}
            local original_print = print
            print = function(...)
                local args_strings = {}
                for i, arg in ipairs({ ... }) do
                    args_strings[i] = tostring(arg)
                end
                local line = table.concat(args_strings, ' ')
                table.insert(stdout_lines, line)
            end

            local ok, err = xpcall(block, function(err)
                local function wrap_err(errmsg)
                    local logs_section = ''
                    if #logs > 0 then
                        logs_section = string.format('\n\nLogs:\n%s', table.concat(logs, '\n'))
                    end

                    local stdout_section = ''
                    if #stdout_lines > 0 then
                        stdout_section = string.format('\n\nstdout:\n%s', table.concat(stdout_lines, '\n'))
                    end

                    local traceback = debug.traceback('', 4)
                    local end_idx = traceback:find('\n%s*%[C]')
                    traceback = traceback:sub(1, end_idx)
                    local count = 1
                    while count > 0 do
                        traceback, count = traceback:gsub('\n%s+third_party/lua/.-\n', '\n')
                    end

                    return string.format('%s%s%s\n%s', errmsg, logs_section, stdout_section, traceback)
                end
                if type(err) == 'table' then
                    err.message = wrap_err(err.message)
                else
                    err = wrap_err(err)
                end
                return err
            end)

            vim.notify = original_notify
            print = original_print

            if ok then
                return
            end
            error(err)
        end)
    end
end

return M
