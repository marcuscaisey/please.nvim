local M = {}

local debug_enabled = false

---@return boolean
function M.toggle_debug()
  debug_enabled = not debug_enabled
  return debug_enabled
end

---@param msg string
---@param ... string
---@return string
function M.format(msg, ...)
  local formatted_msg = string.format(msg, ...)
  return string.format('[please.nvim]: %s', formatted_msg)
end

local function log(msg, level, ...)
  local formatted_msg = M.format(msg, ...)
  if vim.in_fast_event() then
    vim.schedule(function()
      vim.notify(formatted_msg, level)
    end)
  else
    vim.notify(formatted_msg, level)
  end
end

function M.debug(msg, ...)
  if debug_enabled then
    log(msg, vim.log.levels.DEBUG, ...)
  end
end

function M.info(msg, ...)
  log(msg, vim.log.levels.INFO, ...)
end

function M.warn(msg, ...)
  log(msg, vim.log.levels.WARN, ...)
end

function M.error(msg, ...)
  log(msg, vim.log.levels.ERROR, ...)
end

---Runs the given function and logs any errors raised, prefixed with the provided message.
---Intended to be used in combination with assert to clean up repetitive error handling.
---If debug logs are enabled, then the file and line number of the error are also included in the log.
---
---*Before*
---```
---local function print_baz(foo)
---  local bar, err = get_bar(foo)
---  if err then
---    logging.error('failed to print baz: %s', err)
---    return
---  end
---  local baz, err = get_baz(bar)
---  if err then
---    logging.error('failed to print baz: %s', err)
---    return
---  end
---  print(baz)
---end
---```
---
---*After*
---```
---local function get_baz(foo)
---  logging.log_errors('failed to get baz', function()
---    local bar = assert(get_bar(foo))
---    local baz = assert(get_baz(bar))
---    print(baz)
---  end)
---end)
---```
---@param err_msg string
---@param f function
function M.log_errors(err_msg, f)
  local ok, err = pcall(f)
  if not ok then
    if debug_enabled then
      M.error('%s: %s', err_msg, err)
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
    local user_msg = err:match('.-:%d+: (.+)') or err
    M.error('%s: %s', err_msg, user_msg)
  end
end

---Logs the args passed to a func at debug level.
---@param func_name string the name of the called function (this can't be consistently introspected)
function M.log_call(func_name)
  if not debug_enabled then
    return
  end

  local args = {}
  local i = 1
  while true do
    local name, value = debug.getlocal(2, i)
    if not name then
      break
    end
    table.insert(args, string.format('%s=%s', name, vim.inspect(value)))
    i = i + 1
  end

  if #args > 0 then
    M.debug('%s called with %s', func_name, table.concat(args, ', '))
  else
    M.debug('%s called', func_name)
  end
end

return M
