local M = {}

M.error = function(msg)
  vim.api.nvim_err_writeln(string.format('[please.nvim]: %s', msg))
end

---Wraps a function and logs any errors raised inside it. Intended to be used in combination with assert to clean up
---repetitive error handling.
---
---*Before*
---```
---local print_baz = function(foo)
---  local bar, err = get_bar(foo)
---  if err then
---    print(err)
---    return
---  end
---  local baz, err = get_baz(bar)
---  if err then
---    print(err)
---    return
---  end
---  print(baz)
---end
---```
---
---*After*
---```
---local get_baz = function(foo)
---  logging.log_errors(function()
---    local bar = assert(get_bar(foo))
---    local baz = assert(get_baz(bar))
---    print(baz)
---  end)
---end
---```
---@param f function
---@return function
M.log_errors = function(f)
  -- strips filename / location from error messages, i.e. transforms "foo/bar:27: error occurred" -> "error occurred"
  local err_msg_handler = function(err)
    return err:match '.-:%d+: (.+)'
  end

  local ok, err = xpcall(f, err_msg_handler)
  if not ok then
    M.error(err)
  end
end

return M
