local Job = require 'plenary.job'
local popup = require 'plenary.popup'

local runners = {}

---Runs a command with the given args in a terminal in a popup.
---The output of the command is automatically scrolled through.
---The popup can be exited with q.
---@param cmd string: Command to run.
---@param args string[]: Args to pass to the command.
runners.popup = function(cmd, args)
  local width = 0.8
  local height = 0.8

  local opts = {
    minwidth = math.ceil(vim.o.columns * width),
    minheight = math.ceil(vim.o.lines * height),
  }

  local winnr = popup.create('', opts)
  local bufnr = vim.fn.winbufnr(winnr)

  local term_chan_id = vim.api.nvim_open_term(bufnr, {})

  local is_shutdown = false

  local outputter = vim.schedule_wrap(function(_, line)
    if line then
      -- we can still be outputting from the command after it's been shut down, so we need to check before we send on a
      -- potentially closed channel
      if not is_shutdown then
        -- Prepend everything with the style reset sequence to get rid of any residual styling from a previous line. If
        -- there are any ANSI sequences in the line, then they'll just "override" the reset and still work. Potentially
        -- could do this on just stdout since that seems to be the only place affected by styles from previous lines.
        vim.api.nvim_chan_send(term_chan_id, '\x1b[0m' .. line .. '\r\n')
      end
    end
  end)

  local job = Job:new {
    command = cmd,
    args = args,
    on_stdout = outputter,
    on_stderr = outputter,
  }

  -- move the cursor to the last line so that the output automatically scrolls
  vim.api.nvim_feedkeys('G', 'n', false)

  -- disable i -> terminal mode mapping since it's easy to get stuck in terminal mode without any indication that you
  -- need to press <c-\><c-n> to get out
  vim.keymap.set('n', 'i', '<nop>', { buffer = bufnr })

  -- when closing the popup, shutdown the job as well
  local close = function()
    is_shutdown = true
    vim.api.nvim_win_close(winnr, false)
    -- Calling shutdown in the handler adds a bit of delay before the popup closes for some reason, as if its waiting
    -- for the end of the shutdown call. Maybe it is. Either way, scheduling the shutdown gets rid of the delay.
    vim.schedule(function()
      job:shutdown()
    end)
  end
  -- close popup on q
  vim.keymap.set('n', 'q', close, { buffer = bufnr })
  -- close popup when focus lost
  vim.api.nvim_create_autocmd({ 'WinLeave' }, {
    group = vim.api.nvim_create_augroup('please.nvim', { clear = true }),
    buffer = bufnr,
    desc = 'close the popup when focus is lost',
    callback = close,
    once = true,
  })

  job:start()
end

return runners
