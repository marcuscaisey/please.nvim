local logging = require('please.logging')
local plz = require('please.plz')

local hl_ns = vim.api.nvim_create_namespace('please.nvim')
local banner_help_hl_group = 'PleaseNvimRunnerBannerHelp'
vim.cmd.highlight(banner_help_hl_group .. ' guifg=Pink')

---A Please command runner that displays its output in a floating window.
---@class please.Runner
---@field private _bufnr integer
---@field private _winid integer
---@field private _augroup integer
---@field private _stopped boolean
---@field private _job_id integer
---@field private _job_exited boolean
---@field private _on_success fun()?
---@field private _minimised boolean
---@field private _prev_cursor_position integer[]
local Runner = {}
Runner.__index = Runner

local ANSI_REPLACEMENTS = {
  DEFAULT = '\x1b[39m',
  RESET = '\x1b[0m',
  ITALIC = '\x1b[3m',
  BLACK = '\x1b[30m',
  RED = '\x1b[31m',
  GREEN = '\x1b[32m',
  YELLOW = '\x1b[33m',
  BLUE = '\x1b[34m',
  MAGENTA = '\x1b[35m',
  CYAN = '\x1b[36m',
  WHITE = '\x1b[37m',
}

---Wraps string.format and replaces ${STYLE} strings with their respective ANSI escape sequences.
---For example ${YELLOW} is replaced by \x1b[33m.
---@param s string
---@param ... any
---@return string
local function format(s, ...)
  s = s:gsub('${(%u+)}', ANSI_REPLACEMENTS)
  return string.format(s, ...)
end

---@param bufnr integer
---@param augroup integer
---@return integer winid
local function open_win(bufnr, augroup)
  local width_pct = 0.9
  local height_pct = 0.9
  local padding_top_bottom = 2
  local padding_left_right = 4

  local bg_bufnr = vim.api.nvim_create_buf(
    false, -- listed
    true -- scratch
  )
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

  local fg_width = bg_width - 2 * padding_left_right
  local fg_height = bg_height - 2 * padding_top_bottom
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
  local fg_winid = vim.api.nvim_open_win(bufnr, true, fg_config)

  local banner_msg = [[press q to quit / press m to minimise / call require('please').maximise_popup() to maximise]]
  local indent = padding_left_right + math.floor((fg_width - #banner_msg) / 2)
  vim.api.nvim_buf_set_lines(bg_bufnr, 0, 1, false, { string.rep(' ', indent) .. banner_msg })
  vim.hl.range(bg_bufnr, hl_ns, banner_help_hl_group, { 0, indent + 6 }, { 0, indent + 7 }) -- q
  vim.hl.range(bg_bufnr, hl_ns, banner_help_hl_group, { 0, indent + 24 }, { 0, indent + 25 }) -- m
  vim.hl.range(bg_bufnr, hl_ns, banner_help_hl_group, { 0, indent + 45 }, { 0, indent + 79 }) -- require('please').maximise_popup()

  vim.api.nvim_create_autocmd('WinLeave', {
    group = augroup,
    buffer = bufnr,
    desc = 'Close the foreground and background windows when the foreground window is left.',
    callback = function()
      vim.api.nvim_win_close(fg_winid, false)
      vim.api.nvim_win_close(bg_winid, false)
    end,
    once = true,
  })

  return fg_winid
end

local function move_cursor_to_last_line()
  -- Move the cursor to the last line so that the output automatically scrolls
  vim.api.nvim_feedkeys('G', 'nx', false)
end

---@class please.RunnerOpts
---@inlinedoc
---@field on_success fun(runner:please.Runner)?

---Runs a command and displays it in a floating window.
---@param root string
---@param args string[]
---@param opts please.RunnerOpts?
---@return please.Runner
function Runner.start(root, args, opts)
  logging.log_call('please.Runner:new')

  local runner = setmetatable({}, Runner)

  local bufnr = vim.api.nvim_create_buf(
    false, -- listed
    true -- scratch
  )

  local augroup = vim.api.nvim_create_augroup('please.nvim_runner' .. bufnr, {})

  local winid = open_win(bufnr, augroup)
  local term_chan_id = vim.api.nvim_open_term(bufnr, {})

  ---@param data string
  local print_to_term = vim.schedule_wrap(function(data)
    vim.api.nvim_chan_send(term_chan_id, data)
  end)

  local cmd_string = table.concat({ plz, unpack(args) }, ' ')
  print_to_term(format('${BLUE}%s\n\n', cmd_string))

  local job_id = vim.fn.jobstart({ plz, unpack({ '--repo_root', root, unpack(args) }) }, {
    pty = true,
    width = vim.api.nvim_win_get_width(winid),
    height = vim.api.nvim_win_get_height(winid),
    ---@param data string[]
    on_stdout = function(_, data, _)
      local eof = vim.deep_equal(data, { '' })
      if eof then
        return
      end
      print_to_term(table.concat(data, '\n'))
    end,
    ---@param code integer
    on_exit = function(_, code, _)
      ---@diagnostic disable-next-line: invisible
      runner._job_exited = true
      ---@diagnostic disable-next-line: invisible
      if runner._minimised and not runner._stopped then
        logging.info('%s exited with code %d', cmd_string, code)
      end
      local colour
      if code == 0 then
        colour = '${GREEN}'
        ---@diagnostic disable-next-line: invisible
        if runner._on_success then
          ---@diagnostic disable-next-line: invisible
          vim.schedule_wrap(runner._on_success)(runner)
        end
      else
        colour = '${RED}'
      end
      print_to_term(format('\n' .. colour .. 'Exited with code %d', code))
    end,
  })

  move_cursor_to_last_line()

  -- It's easy to get stuck in terminal mode without any indication that you need to press <c-\><c-n> to get out
  vim.api.nvim_create_autocmd('TermEnter', {
    group = augroup,
    buffer = bufnr,
    desc = 'Exit terminal mode',
    callback = function()
      vim.cmd.stopinsert()
    end,
  })

  vim.keymap.set('n', 'q', function()
    ---@diagnostic disable-next-line: invisible
    runner:_stop()
    runner:minimise()
  end, { buffer = bufnr })

  vim.keymap.set('n', 'm', function()
    runner:minimise()
  end, { buffer = bufnr })

  vim.api.nvim_create_autocmd('WinLeave', {
    group = augroup,
    buffer = runner._bufnr,
    desc = 'Set minimised flag and save cursor position',
    callback = function()
      ---@diagnostic disable-next-line: invisible
      runner._minimised = true
      ---@diagnostic disable-next-line: invisible
      runner._prev_cursor_position = vim.api.nvim_win_get_cursor(0)
    end,
  })

  opts = opts or {}
  runner._bufnr = bufnr
  runner._winid = winid
  runner._augroup = augroup
  runner._stopped = false
  runner._job_id = job_id
  runner._job_exited = false
  runner._on_success = opts.on_success
  runner._minimised = false
  runner._prev_cursor_position = { 1, 0 }

  return runner
end

---Minimises the floating window.
function Runner:minimise()
  if not self._winid then
    error('minimise called on Runner that has not been started')
  end
  if not self._minimised then
    vim.api.nvim_win_close(self._winid, false)
  end
end

---Maximises the floating window.
function Runner:maximise()
  if not self._bufnr then
    error('maximise called on Runner that has not been started')
  end
  self._minimised = false
  self._winid = open_win(self._bufnr, self._augroup)
  if self._job_exited then
    vim.api.nvim_win_set_cursor(0, self._prev_cursor_position)
  else
    move_cursor_to_last_line()
  end
end

---Stops the command, closes the floating window, and cleans up created autocmds.
function Runner:destroy()
  self:_stop()
  self:minimise()
  vim.api.nvim_del_augroup_by_id(self._augroup)
end

---@private
function Runner:_stop()
  if not self._job_id then
    error('stop called on Runner that has not been started')
  end
  self._stopped = true
  vim.fn.jobstop(self._job_id)
end

return Runner
