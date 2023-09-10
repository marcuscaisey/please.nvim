local future = require('please.future')
local logging = require('please.logging')
local plz = require('please.plz')

local augroup = vim.api.nvim_create_augroup('please_nvim_runner', { clear = true })

vim.cmd.highlight('PleaseNvimRunnerBannerHelp guifg=Pink')

---A plz command runner that displays its output in a floating window.
---@class please.Runner
---@field private _root string
---@field private _args string[]
---@field private _bufnr integer?
---@field private _winid integer?
---@field private _stopped boolean
---@field private _cmd_system_obj vim.SystemObj?
---@field private _cmd_exited boolean
---@field private _on_success fun()?
---@field private _minimised boolean
---@field private _prev_cursor integer[]
local Runner = {}
Runner.__index = Runner

---@param root string
---@param args string[]
---@return please.Runner
function Runner:new(root, args)
  logging.log_call('runner.Runner:new')
  local runner = {
    _root = root,
    _args = args,
    _stopped = false,
    _minimised = false,
    _cmd_exited = false,
    _prev_cursor = { 1, 0 },
  }
  return setmetatable(runner, Runner)
end

---Sets a callback to be called when the command exits with a code of 0.
---@param cb fun()
function Runner:on_success(cb)
  self._on_success = cb
end

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

---@param bufnr integer Buffer to display.
---@return integer winid ID of the window.
local function open_win(bufnr)
  local width_pct = 0.8
  local height_pct = 0.8
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
  vim.api.nvim_buf_add_highlight(bg_bufnr, -1, 'PleaseNvimRunnerBannerHelp', 0, indent + 6, indent + 7) -- q
  vim.api.nvim_buf_add_highlight(bg_bufnr, -1, 'PleaseNvimRunnerBannerHelp', 0, indent + 24, indent + 25) -- m
  vim.api.nvim_buf_add_highlight(bg_bufnr, -1, 'PleaseNvimRunnerBannerHelp', 0, indent + 45, indent + 79) -- require('please').maximise_popup()

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

---Starts the command and displays its output in a floating window.
---@return please.Runner
function Runner:start()
  logging.log_call('Runner:start')

  self._bufnr = vim.api.nvim_create_buf(
    false, -- listed
    true -- scratch
  )

  self._winid = open_win(self._bufnr)
  local term_chan_id = vim.api.nvim_open_term(self._bufnr, {})

  local function print_to_term(data)
    if data then
      vim.schedule(function()
        local data = data:gsub('\n', '\r\n')
        vim.api.nvim_chan_send(term_chan_id, data)
      end)
    end
  end

  local cmd_string = table.concat({ plz, unpack(self._args) }, ' ')
  print_to_term(format('${BLUE}%s\n\n', cmd_string))

  ---@param out vim.SystemCompleted
  local function on_exit(out)
    self._cmd_exited = true
    if self._minimised and not self._stopped then
      logging.info('%s exited with code %d', cmd_string, out.code)
    end
    local colour
    if out.code == 0 then
      colour = '${GREEN}'
      if self._on_success then
        vim.schedule(self._on_success)
      end
    else
      colour = '${RED}'
    end
    print_to_term(format('\n' .. colour .. 'Exited with code %d', out.code))
  end
  self._cmd_system_obj = future.vim.system(
    { plz, unpack({ '--repo_root', self._root, '--interactive_output', '--colour', unpack(self._args) }) },
    {
      stdout = function(_, data)
        print_to_term(data)
      end,
      stderr = function(_, data)
        print_to_term(data)
      end,
    },
    on_exit
  )

  move_cursor_to_last_line()

  -- It's easy to get stuck in terminal mode without any indication that you need to press <c-\><c-n> to get out
  vim.api.nvim_create_autocmd('TermEnter', {
    group = augroup,
    buffer = self._bufnr,
    desc = "Exit terminal mode if it's entered.",
    callback = function()
      vim.cmd.stopinsert()
    end,
  })

  vim.keymap.set('n', 'q', function()
    self:stop()
    self:minimise()
  end, { buffer = self._bufnr })

  vim.keymap.set('n', 'm', function()
    self:minimise()
  end, { buffer = self._bufnr })

  vim.api.nvim_create_autocmd('WinLeave', {
    group = augroup,
    buffer = self._bufnr,
    callback = function()
      self._minimised = true
      self._prev_cursor = vim.api.nvim_win_get_cursor(0)
    end,
  })

  return self
end

---Stops the command.
function Runner:stop()
  if not self._cmd_system_obj then
    error('stop called on Runner that has not been started')
  end
  self._stopped = true
  self._cmd_system_obj:kill(15) -- SIGTERM
end

---Minimises the floating window.
function Runner:minimise()
  if not self._winid then
    error('minimise called on Runner that has not been started')
  end
  vim.api.nvim_win_close(self._winid, false)
end

---Maximises the floating window.
function Runner:maximise()
  if not self._bufnr then
    error('maximise called on Runner that has not been started')
  end
  self._minimised = false
  self._winid = open_win(self._bufnr)
  if self._cmd_exited then
    vim.api.nvim_win_set_cursor(0, self._prev_cursor)
  else
    move_cursor_to_last_line()
  end
end

return Runner
