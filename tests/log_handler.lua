local M = {}

---Wraps the busted it function so that any logs emitted through vim.notify during execution of the test block are
---included in the test failure.
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
            ---@diagnostic disable-next-line: unused-local, duplicate-set-field
            function vim.notify(msg, level, opts)
                local level_names = {
                    [vim.log.levels.TRACE] = 'TRACE',
                    [vim.log.levels.DEBUG] = 'DEBUG',
                    [vim.log.levels.INFO] = 'INFO',
                    [vim.log.levels.WARN] = 'WARN',
                    [vim.log.levels.ERROR] = 'ERROR',
                }
                local level_name = level_names[level] or 'UNKNOWN'
                table.insert(logs, string.format('%5s: %s', level_name, msg))
            end
            local ok, err = pcall(block)
            if ok then
                return
            end
            if #logs > 0 then
                local function errmsg_with_logs(errmsg)
                    return string.format('%s\n\nLogs:\n%s\n', errmsg, table.concat(logs, '\n'))
                end
                if type(err) == 'table' then
                    err.message = errmsg_with_logs(err.message)
                else
                    err = errmsg_with_logs(err)
                end
            end
            error(err)
        end)
    end
end

return M
