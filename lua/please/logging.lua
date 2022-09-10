local M = {}

local enabled = false

M.toggle_debug = function()
  if enabled then
    M.info 'debug logs disabled'
    enabled = false
  else
    M.info 'debug logs enabled'
    enabled = true
  end
end

local log = function(msg, level, ...)
  local formatted_msg = string.format(msg, ...)
  formatted_msg = string.format('[please.nvim]: %s', formatted_msg)
  vim.schedule(function()
    vim.notify(formatted_msg, level)
  end)
end

M.debug = function(msg, ...)
  if enabled then
    log(msg, vim.log.levels.DEBUG, ...)
  end
end

M.info = function(msg, ...)
  log(msg, vim.log.levels.INFO, ...)
end

M.warn = function(msg, ...)
  log(msg, vim.log.levels.WARN, ...)
end

M.error = function(msg, ...)
  log(msg, vim.log.levels.ERROR, ...)
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
    if enabled then
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
