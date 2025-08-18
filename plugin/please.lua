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

---Returns all candidates which start with the prefix, sorted.
---@param prefix string
---@param candidates string[]
---@return string[]
local function complete_arg(prefix, candidates)
  local result = vim.tbl_filter(function(arg)
    return vim.startswith(arg, prefix)
  end, candidates)
  table.sort(result)
  return result
end

local cmds = please
---@type table<string, string[]>
local cmd_opts = {
  test = { 'under_cursor' },
  debug = { 'under_cursor' },
}
local var_arg_cmds = { 'command' }

local cmd_names = vim.tbl_keys(cmds)
vim.api.nvim_create_user_command('Please', function(args)
  local cmd_name = args.fargs[1]
  local cmd_args = { unpack(args.fargs, 2) }

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
  ---@param arg_lead string the leading portion of the argument currently being completed on
  ---@param cmd_line string the entire command line
  ---@return string[]
  complete = function(arg_lead, cmd_line)
    local cmd_line_words = vim.split(cmd_line, ' ')

    -- If there's only two words in the command line, then we're completing the command name. i.e. If cmd_line looks
    -- like 'Please te'.
    if #cmd_line_words == 2 then
      return complete_arg(arg_lead, cmd_names)
    end

    -- cmd_line looks like 'Please test ...'
    local cmd_name = cmd_line_words[2]
    local cmd_opts = cmd_opts[cmd_name]
    if not cmd_opts then
      return {}
    end

    -- Filter out options which have already been provided.
    local cur_opts = { unpack(cmd_line_words, 3) }
    local remaining_opts = vim.tbl_filter(function(opt)
      return not vim.list_contains(cur_opts, opt)
    end, cmd_opts)
    return complete_arg(arg_lead, remaining_opts)
  end,
  desc = 'Run a please.nvim command.',
})

vim.g.loaded_please = true
