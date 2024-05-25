-- Exports a single function which creates the Please user command.
-- complete and user_command return closures since we need to depend on the commands list exported by please.plugin,
-- however that module imports this one, creating a cycle. We therefore take in a list of commands and their options as
-- parameters to avoid importing them.

local logging = require('please.logging')

local M = {}

-- return all args from available_args which:
-- - start with arg_lead
-- - are not contained in exclude
local function complete_arg(arg_lead, available_args, exclude)
  exclude = exclude or {}
  return vim.tbl_filter(function(arg)
    return vim.startswith(arg, arg_lead) and not vim.tbl_contains(exclude, arg)
  end, available_args)
end

-- complete args to the Please command
local function complete(cmd_names, cmd_name_to_opts)
  -- sort all of the commands and opts here so that we only have to do it once (assumes that complete_arg doesn't mess
  -- with the order)
  table.sort(cmd_names)
  for cmd_name in pairs(cmd_name_to_opts) do
    table.sort(cmd_name_to_opts[cmd_name])
  end

  -- See :help :command-completion-customlist for detailed description of this func. arg_lead is the arg that we're
  -- currently completing and cmd_line is a string of the whole current command line. i.e. if we've typed
  -- 'Please test un', then arg_lead='un' and cmd_line='Please test un'.
  return function(arg_lead, cmd_line)
    local cmd_line_words = vim.split(cmd_line, ' ')
    -- If there's only two words in the command line, then we must be completing the command name. i.e. if cmd_line is
    -- like 'Please te'
    local completing_cmd_name = #cmd_line_words == 2

    if completing_cmd_name then
      return complete_arg(arg_lead, cmd_names)
    else
      -- cmd_line looks like 'Please test ...'
      local cmd_name = cmd_line_words[2]
      local cmd_opts = cmd_name_to_opts[cmd_name]
      if cmd_opts then
        -- We want to exclude the args which already exist in cmd_line. We don't include the last cmd_line word in this
        -- list since that's the one that we're currently completing.
        local exclude = { unpack(cmd_line_words, 2, #cmd_line_words - 1) }
        return complete_arg(arg_lead, cmd_opts, exclude)
      end
    end
  end
end

-- run a please.nvim command
local function user_command(cmds, cmd_name_to_positional_args)
  -- See :help nvim_create_user_command for detailed description of opts. We only use fargs anyway which is just the
  -- list of args passed to the command.
  return function(opts)
    local cmd_name = opts.fargs[1]

    local cmd = cmds[cmd_name]
    if not cmd then
      logging.error("'%s' is not a Please command", cmd_name)
      return
    end

    local args = { unpack(opts.fargs, 2) } -- first farg is the command name so ignore that
    local cmd_args = {}
    if cmd_name_to_positional_args[cmd_name] then
      cmd_args = args
    else
      local opts = {}
      for _, arg in ipairs(args) do
        opts[arg] = true
      end
      cmd_args = { opts }
    end
    cmd(unpack(cmd_args))
  end
end

function M.create_user_command(cmds, cmd_name_to_opts, cmd_name_to_positional_args)
  local cmd_names = vim.tbl_keys(cmds)
  vim.api.nvim_create_user_command('Please', user_command(cmds, cmd_name_to_positional_args), {
    nargs = '+',
    complete = complete(cmd_names, cmd_name_to_opts),
    force = true, -- allows us to recreate the command on plugin reload
    desc = 'Run a please.nvim command.',
  })
end

return M
