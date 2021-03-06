-- The plan is to provide multiple runners which accept cmd / args for running commands in different ways like opening
-- in a new tmux pane or using the in built terminal etc
local Job = require 'plenary.job'
local plenary_popup = require 'plenary.popup'
local logging = require 'please.logging'
local cursor = require 'please.cursor'

local popup = {}

local group = vim.api.nvim_create_augroup('please.nvim', { clear = true })

local close_win = function(winid)
  -- If we close multiple windows then sometimes the ones after the first are invalid by the time we get to calling
  -- nvim_win_close. I'm not sure why this is but telescope.nvim does it as well which is good enough for me.
  if vim.api.nvim_win_is_valid(winid) then
    vim.api.nvim_win_close(winid, true)
  end
end

local cached_popup = {
  valid = false,
  lines = {},
  cursor = {},
}

---Runs a command with the given args in a terminal in a popup.
---The output of the command is automatically scrolled through.
---The popup can be exited with q or by focusing on another window.
---@param cmd string: Command to run.
---@param args string[]: Args to pass to the command.
popup.run = function(cmd, args)
  logging.debug('runners.popup called with cmd=%s, args=%s', cmd, vim.inspect(args))

  -- reset before we start running the command in case it doesn't finish successfully, otherwise we could restore the
  -- output from the popup run previous to this one
  cached_popup = {
    valid = false,
    lines = {},
    cursor = {},
  }

  local width = 0.8
  local height = 0.8
  local term_win_opts = {
    minwidth = math.ceil(vim.o.columns * width),
    minheight = math.ceil(vim.o.lines * height),
    focusable = true,
  }
  local bg_win_opts = {
    minwidth = term_win_opts.minwidth + 8,
    minheight = term_win_opts.minheight + 2,
  }

  local bg_winid = plenary_popup.create({}, bg_win_opts)
  local term_winid = plenary_popup.create({}, term_win_opts)
  local term_bufnr = vim.fn.winbufnr(term_winid)
  local term_chan_id = vim.api.nvim_open_term(term_bufnr, {})

  -- we can still be outputting from the command after it's been shut down, so we need to check this before we send on a
  -- potentially closed channel
  local is_shutdown = false

  local is_complete = false
  local output_lines = {}
  local output_line = function(line, opts)
    opts = opts or { new_line = true }
    if opts.new_line then
      line = line .. '\r\n'
    end
    table.insert(output_lines, line)
    vim.api.nvim_chan_send(term_chan_id, line)
  end

  local first_stdout_line_written = false
  local on_stdout = vim.schedule_wrap(function(_, line)
    if not is_shutdown and line then
      if not first_stdout_line_written then
        first_stdout_line_written = true
        -- please usually outputs these control sequences to reset the text style and clear the screen before printing
        -- stdout, but they don't seem to be getting output for us...
        line = '\x1b[0m\x1b[H\x1b[J' .. line
      end
      output_line(line)
    end
  end)

  local on_stderr = vim.schedule_wrap(function(_, line)
    if not is_shutdown and line then
      output_line(line)
    end
  end)

  local on_exit = vim.schedule_wrap(function()
    if not is_shutdown then
      output_line '\r\n[1mCommand:'
      output_line(string.format('[0m%s %s', cmd, table.concat(args, ' ')), { new_line = false })
      is_complete = true
    end
  end)

  local job = Job:new {
    command = cmd,
    args = args,
    on_stdout = on_stdout,
    on_stderr = on_stderr,
    on_exit = on_exit,
  }

  -- move the cursor to the last line so that the output automatically scrolls
  vim.api.nvim_feedkeys('G', 'n', false)

  -- disable i -> terminal mode mapping since it's easy to get stuck in terminal mode without any indication that you
  -- need to press <c-\><c-n> to get out
  vim.keymap.set('n', 'i', '<nop>', { buffer = term_bufnr })

  local close = function()
    if is_complete and not is_shutdown then
      cached_popup = {
        valid = true,
        lines = output_lines,
        cursor = cursor.get(),
      }
    end
    is_shutdown = true
    close_win(term_winid)
    close_win(bg_winid)
    -- Calling shutdown in the handler adds a bit of delay before the popup closes for some reason, as if its waiting
    -- for the end of the shutdown call. Maybe it is. Either way, scheduling the shutdown gets rid of the delay.
    vim.schedule(function()
      job:shutdown()
    end)
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

  job:start()
end

---Shows the output from a previous popup in a new popup, restoring the previous cursor position as well.
---Only popups who's command ran to completion can be restore, otherwise no popup will be opened.
---The popup can be exited with q or by focusing on another window.
popup.restore = function()
  logging.debug 'runners.restore called'

  if not cached_popup.valid then
    logging.error 'no popup to restore'
    return
  end

  local width = 0.8
  local height = 0.8
  local term_win_opts = {
    minwidth = math.ceil(vim.o.columns * width),
    minheight = math.ceil(vim.o.lines * height),
    focusable = true,
  }
  local bg_win_opts = {
    minwidth = term_win_opts.minwidth + 8,
    minheight = term_win_opts.minheight + 2,
  }

  local bg_winid = plenary_popup.create({}, bg_win_opts)
  local term_winid = plenary_popup.create({}, term_win_opts)
  local term_bufnr = vim.fn.winbufnr(term_winid)
  local term_chan_id = vim.api.nvim_open_term(term_bufnr, {})

  vim.api.nvim_chan_send(term_chan_id, table.concat(cached_popup.lines))

  -- we have to wait for the character which the cursor was previously on to be populated in the terminal buffer before
  -- we can move the cursor back to it
  local cached_row, cached_col = unpack(cached_popup.cursor)
  vim.wait(500, function()
    -- [cached_row-1, cached_row) gets us the cached_row'th line (cached_row is 1-based, nvim_buf_get_lines is 0-based)
    local term_buf_line = vim.api.nvim_buf_get_lines(term_bufnr, cached_row - 1, cached_row, false)[1]
    return term_buf_line and #term_buf_line >= cached_col
  end)
  cursor.set(cached_popup.cursor)

  local close = function()
    cached_popup.cursor = cursor.get()
    close_win(term_winid)
    close_win(bg_winid)
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
