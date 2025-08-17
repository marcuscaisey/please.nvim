local min_nvim_version = '0.11.0'
if vim.fn.has(string.format('nvim-%s', min_nvim_version)) == 0 then
  vim.notify(string.format('please.nvim requires at least Neovim %s', min_nvim_version), vim.log.levels.ERROR)
  return
end

if vim.g.loaded_please then
  return
end

local please = require('please')
local logging = require('please.logging')

-- configure all of the file names / extensions which should correspond to the please filetype
local function configure_filetype()
  vim.filetype.add({
    extension = {
      build_defs = 'please',
      build = 'please',
    },
    filename = {
      BUILD = function(path)
        if vim.fs.root(path, '.plzconfig') then
          return 'please'
        end
        return 'bzl'
      end,
      ['BUILD.plz'] = 'please',
    },
    pattern = {
      ['%.plzconfig.*'] = 'dosini',
    },
  })
end

-- return all args from available_args which:
-- - start with arg_lead
-- - are not contained in exclude
local function complete_arg(arg_lead, available_args, exclude)
  exclude = exclude or {}
  return vim.tbl_filter(function(arg)
    return vim.startswith(arg, arg_lead) and not vim.tbl_contains(exclude, arg)
  end, available_args)
end

-- create the Please user command
local function create_user_command()
  local cmds = {}
  for k, v in pairs(please) do
    cmds[k] = v
  end
  ---@type table<string, string[]>
  local cmd_opts = {
    test = { 'under_cursor' },
    debug = { 'under_cursor' },
  }
  local var_arg_cmds = { 'command' }

  local cmd_names = vim.tbl_keys(cmds)
  table.sort(cmd_names)
  vim.api.nvim_create_user_command('Please', function(args)
    local cmd_name = args.fargs[1]
    local cmd_args = { unpack(args.fargs, 2) } -- first farg is the command name so ignore that

    local cmd = cmds[cmd_name]
    if not cmd then
      logging.error("'%s' is not a 'Please' command", cmd_name)
      return
    end

    if vim.list_contains(var_arg_cmds, cmd_name) then
      cmd(unpack(cmd_args))
    elseif cmd_opts[cmd_name] then
      local valid_opts = cmd_opts[cmd_name]
      local opts = {}
      for _, arg in ipairs(cmd_args) do
        if not vim.list_contains(valid_opts, arg) then
          local args = { arg, cmd_name, table.concat(valid_opts, "', '") }
          logging.error("'%s' is not a valid 'Please %s' option. Valid options: '%s'.", unpack(args))
          return
        end
        opts[arg] = true
      end
      cmd(opts)
    else
      if #cmd_args > 0 then
        logging.error("'Please %s' does not accept arguments", cmd_name)
        return
      end
      cmd()
    end
  end, {
    nargs = '+',
    complete = function(arg_lead, cmd_line)
      -- See :help :command-completion-customlist for detailed description of this func. arg_lead is the arg that we're
      -- currently completing and cmd_line is a string of the whole current command line. i.e. if we've typed 'Please
      -- test un', then arg_lead='un' and cmd_line='Please test un'.
      local cmd_line_words = vim.split(cmd_line, ' ')
      -- If there's only two words in the command line, then we must be completing the command name. i.e. if cmd_line is
      -- like 'Please te'.
      local completing_cmd_name = #cmd_line_words == 2

      if completing_cmd_name then
        return complete_arg(arg_lead, cmd_names)
      else
        -- cmd_line looks like 'Please test ...'
        local cmd_name = cmd_line_words[2]
        local cmd_opts = cmd_opts[cmd_name]
        if cmd_opts then
          -- We want to exclude the args which already exist in cmd_line. We don't include the last cmd_line word in
          -- this list since that's the one that we're currently completing.
          local exclude = { unpack(cmd_line_words, 2, #cmd_line_words - 1) }
          return complete_arg(arg_lead, cmd_opts, exclude)
        end
      end
    end,
    desc = 'Run a please.nvim command.',
  })
end

configure_filetype()
create_user_command()

vim.g.loaded_please = true
