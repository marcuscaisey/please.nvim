---@mod please.runners.popup POPUP COMMANDS

local logging = require('please.logging')
local cursor = require('please.cursor')
local future = require('please.future')

local popup = {}

local group = vim.api.nvim_create_augroup('please.nvim', { clear = true })

local close_win = function(winid)
  -- If we close multiple windows by calling this function multiple times, then sometimes the ones after the first are
  -- invalid by the time we get to calling nvim_win_close. I'm not sure why this is but telescope.nvim does it as well
  -- which is good enough for me.
  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
end

local cached_popup = {
  valid = false,
  lines = {},
  cursor = {},
}

local prev_winid ---@type number
local prev_cursor ---@type please.cursor.Position

local ansi = {
  bold = '\x1b[1m',
  italic = '\x1b[3m',
  black = '\x1b[30m',
  red = '\x1b[31m',
  green = '\x1b[32m',
  yellow = '\x1b[33m',
  blue = '\x1b[34m',
  magenta = '\x1b[35m',
  cyan = '\x1b[36m',
  white = '\x1b[37m',
  default = '\x1b[39m',
  reset = '\x1b[0m',
  move_cursor_home = '\x1b[H',
  erase_in_display = '\x1b[J',
}

---@return number bufnr
---@return number fg_winid
---@return number bg_winid
local function open_float()
  local width_pct = 0.8
  local height_pct = 0.8

  local bg_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = bg_bufnr })
  local bg_width = math.floor(width_pct * vim.o.columns)
  local bg_height = math.floor(height_pct * vim.o.lines)
  local bg_config = {
    relative = 'editor',
    width = bg_width,
    height = bg_height,
    row = math.floor((vim.o.lines - bg_height) / 2),
    col = math.floor((vim.o.columns - bg_width) / 2),
    focusable = false,
    style = 'minimal',
    noautocmd = true,
  }
  local bg_winid = vim.api.nvim_open_win(bg_bufnr, false, bg_config)

  local fg_bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = fg_bufnr })
  local fg_width = bg_width - 8
  local fg_height = bg_height - 2
  local fg_config = {
    relative = 'editor',
    width = fg_width,
    height = fg_height,
    row = math.floor((vim.o.lines - fg_height) / 2),
    col = math.floor((vim.o.columns - fg_width) / 2),
    focusable = true,
    style = 'minimal',
    noautocmd = true,
  }
  local fg_winid = vim.api.nvim_open_win(fg_bufnr, true, fg_config)

  return fg_bufnr, fg_winid, bg_winid
end

---@private
---Runs a command with the given args in a terminal in a popup.
---The output of the command is automatically scrolled through.
---The popup can be exited with q or by focusing on another window.
---@param cmd string: Command to run.
---@param args string[]?: Args to pass to the command.
---@param opts table?
---  * {on_success} (function): callback which is called if the command is successful
popup.run = function(cmd, args, opts)
  args = args or {}
  opts = opts or {}

  logging.log_call('popup.run')

  -- reset before we start running the command, otherwise if it doesn't finish successfully and we restore, we will
  -- restore the output from the popup run previous to this one
  cached_popup = {
    valid = false,
    output = '',
    cursor = {},
  }

  prev_winid = vim.api.nvim_get_current_win()
  prev_cursor = cursor.get()
  local term_bufnr, term_winid, bg_winid = open_float()
  local term_chan_id = vim.api.nvim_open_term(term_bufnr, {})

  -- we can still be outputting from the command after it's been shut down, so we need to check this before we send on a
  -- potentially closed channel
  local is_shutdown = false

  -- we need to track if the command completes so that we only cache the popup if this is the case
  local is_complete = false

  local output_data = function(data)
    data = data:gsub('\n', '\r\n')
    cached_popup.output = cached_popup.output .. data
    vim.schedule(function()
      vim.api.nvim_chan_send(term_chan_id, data)
    end)
  end

  local close_windows = function()
    close_win(term_winid)
    close_win(bg_winid)
    -- It's possible that the previous window doesn't exist anymore
    if pcall(vim.api.nvim_set_current_win, prev_winid) then
      -- It's also possible that if it did exist, it doesn't by the time that we attempt to set the cursor
      pcall(cursor.set, prev_cursor)
    end
  end

  local on_exit = vim.schedule_wrap(function(obj)
    if not is_shutdown then
      output_data('\n')
      output_data(ansi.italic .. ansi.yellow .. cmd .. ' ' .. table.concat(args, ' ') .. '\n')
      output_data('\n')
      output_data(ansi.default .. 'Press ' .. ansi.magenta .. 'q' .. ansi.default .. ' to quit' .. '\n')
      output_data(
        'Call '
          .. ansi.magenta
          .. 'Please restore_popup'
          .. ansi.default
          .. ' or '
          .. ansi.magenta
          .. [[require('please.runners.popup').restore()]]
          .. ansi.default
          .. ' to restore'
      )
      is_complete = true
      cached_popup.valid = true
    end

    if opts.on_success and obj.code == 0 then
      opts.on_success(close_windows)
    end
  end)

  local on_output = function(_, data)
    if not is_shutdown and data then
      output_data(data)
    end
  end
  local system_obj = future.vim.system({ cmd, unpack(args) }, { stdout = on_output, stderr = on_output }, on_exit)

  -- move the cursor to the last line so that the output automatically scrolls
  vim.api.nvim_feedkeys('G', 'n', false)

  -- disable i -> terminal mode mapping since it's easy to get stuck in terminal mode without any indication that you
  -- need to press <c-\><c-n> to get out
  vim.keymap.set('n', 'i', '<nop>', { buffer = term_bufnr })

  local close = function()
    if is_complete and not is_shutdown then
      cached_popup.cursor = cursor.get()
    end
    is_shutdown = true
    close_windows()
    system_obj:kill(15) -- SIGTERM
  end
  -- close popup on q
  vim.keymap.set('n', 'q', close, { buffer = term_bufnr })
  -- close popup when focus lost
  vim.api.nvim_create_autocmd({ 'WinLeave' }, {
    group = group,
    buffer = term_bufnr,
    desc = 'close the popup when focus is lost',
    callback = close,
    once = true,
  })
end

---Shows the output from a previous popup in a new popup, restoring the
---previous cursor position as well. Only popups who's command ran to
---completion can be restored, otherwise no popup will be opened.
popup.restore = function()
  logging.log_call('runners.restore')

  if not cached_popup.valid then
    logging.error('no popup to restore')
    return
  end

  prev_winid = vim.api.nvim_get_current_win()
  prev_cursor = cursor.get()
  local term_bufnr, term_winid, bg_winid = open_float()
  local term_chan_id = vim.api.nvim_open_term(term_bufnr, {})

  vim.api.nvim_chan_send(term_chan_id, cached_popup.output)

  -- we have to wait for the character which the cursor was previously on to be populated in the terminal buffer before
  -- we can move the cursor back to it
  vim.wait(500, function()
    -- [cached_row-1, cached_row) gets us the cached_row'th line (cached_row is 1-based, nvim_buf_get_lines is 0-based)
    local term_buf_line =
      vim.api.nvim_buf_get_lines(term_bufnr, cached_popup.cursor.row - 1, cached_popup.cursor.row, false)[1]
    return term_buf_line and #term_buf_line >= cached_popup.cursor.col
  end)
  cursor.set(cached_popup.cursor)

  local close = function()
    cached_popup.cursor = cursor.get()
    close_win(term_winid)
    close_win(bg_winid)
    -- It's possible that the previous window doesn't exist anymore
    if pcall(vim.api.nvim_set_current_win, prev_winid) then
      -- It's also possible that if it did exist, it doesn't by the time that we attempt to set the cursor
      pcall(cursor.set, prev_cursor)
    end
  end
  -- close popup on q
  vim.keymap.set('n', 'q', close, { buffer = term_bufnr })
  -- close popup when focus lost
  vim.api.nvim_create_autocmd({ 'WinLeave' }, {
    group = group,
    buffer = term_bufnr,
    desc = 'close the popup when focus is lost',
    callback = close,
    once = true,
  })
end

return popup
