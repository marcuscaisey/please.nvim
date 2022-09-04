local M = {}

local debug = false

M.toggle_debug = function()
  if debug then
    M.info 'debug logs disabled'
    debug = false
  else
    M.info 'debug logs enabled'
    debug = true
  end
end

local format_log = function(msg, ...)
  local formatted_msg = string.format(msg, ...)
  return string.format('[please.nvim]: %s', formatted_msg)
end

-- TODO: use vim.notify for logging? that handles something to do with logging levels, not sure what effect they have
-- though

M.debug = function(msg, ...)
  if debug then
    local formatted_msg = format_log(msg, ...)
    vim.schedule(function()
      print(formatted_msg)
    end)
  end
end

M.info = function(msg, ...)
  local formatted_msg = format_log(msg, ...)
  vim.schedule(function()
    print(formatted_msg)
  end)
end

M.warn = function(msg, ...)
  local formatted_msg = format_log(msg, ...)
  vim.schedule(function()
    vim.api.nvim_echo({ { formatted_msg, 'WarningMsg' } }, true, {})
  end)
end

M.error = function(msg, ...)
  local formatted_msg = format_log(msg, ...)
  vim.schedule(function()
    vim.api.nvim_echo({ { formatted_msg, 'ErrorMsg' } }, true, {})
  end)
end

---Wraps a function and logs any errors raised inside it. Intended to be used in combination with assert to clean up
---repetitive error handling. If debug logs are enabled, then the file and line number of the error are also included in
---the log.
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
  local ok, err = pcall(f)
  if not ok then
    if debug then
      M.error(err)
      return
    end
    -- strips filename / location from error messages, i.e. transforms "foo/bar:27: error occurred" -> "error occurred"
    --
    -- some errors won't contain this information so default back to the whole error in this case (assert called with
    -- the result of a function which returns three values i.e.
    -- function foo()
    --   return nil, nil, 'error message'
    -- end
    -- won't raise an error filename / location)
    local user_msg = err:match '.-:%d+: (.+)' or err
    M.error(user_msg)
  end
end

return M
