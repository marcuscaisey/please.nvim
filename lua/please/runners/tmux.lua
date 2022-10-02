local logging = require('please.logging')

local tmux = {}

---Runs a command with the given args in tmux.
---@param cmd string: Command to run.
---@param args string[]: Args to pass to the command.
---@param opts table
---@field tmux_pre string[]: prefix to the tmux command (e.g. for setting options).
---@field tmux_args string[]: Args to pass to tmux.
tmux.run = function(cmd, args, opts)
  logging.debug('runners.tmux called with cmd=%s, args=%s, opts=%s', cmd, vim.inspect(args), vim.inspect(opts))

  local tmux_env = os.getenv('TMUX')
  if tmux_env == nil then
    logging.error('unable to get current tmux session')
    return
  end

  if opts == nil then
    opts = {
      tmux_args = { 'split-window' },
    }
  end

  local socket = vim.split(tmux_env, ',')[1]
  local tmux_cmd = string.format(
    "%s tmux -S %s %s '%s %s ; echo Press any key to exit; read ans'",
    table.concat(opts.tmux_pre or {}, ' '),
    socket,
    table.concat(opts.tmux_args or { 'split-window' }, ' '),
    cmd,
    table.concat(args, ' ')
  )
  logging.debug('executing tmux_cmd=%s', tmux_cmd)
  local handle = assert(io.popen(tmux_cmd), string.format('unable to execute: [%s]', tmux_cmd))
  handle:close()
end

return tmux
