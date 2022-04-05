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

  local job_id = vim.api.nvim_open_term(bufnr, {})

  -- move the cursor to the last line so that the output automatically scrolls
  vim.api.nvim_feedkeys('G', 'n', false)

  -- allow quitting with q
  vim.keymap.set('n', 'q', '<cmd>:q<cr>', { buffer = bufnr })
  -- disable i -> terminal mode mapping since it's easy to get stuck in terminal mode without any indication that you
  -- need to press <c-\><c-n> to get out
  vim.keymap.set('n', 'i', '<nop>', { buffer = bufnr })

  local outputter = vim.schedule_wrap(function(_, line)
    if line then
      vim.api.nvim_chan_send(job_id, line .. '\r\n')
    end
  end)

  local job = Job:new {
    command = cmd,
    args = args,
    on_stdout = outputter,
    on_stderr = outputter,
  }
  job:start()
end

return runners
