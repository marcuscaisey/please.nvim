local min_nvim_version = '0.11.1'
if vim.fn.has(string.format('nvim-%s', min_nvim_version)) == 0 then
  vim.notify(string.format('please.nvim requires at least Neovim %s', min_nvim_version), vim.log.levels.ERROR)
  return
end

if vim.g.loaded_please then
  return
end

---@param modname string
---@return unknown
local function require_on_index(modname)
  return setmetatable({}, {
    __index = function(_, k)
      return require(modname)[k]
    end,
  })
end

---@module 'please'
local please = require_on_index('please')
---@module 'please.query'
local query = require_on_index('please.query')
---@module 'please.logging'
local logging = require_on_index('please.logging')

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

vim.treesitter.language.register('python', 'please')

vim.lsp.config('please', {
  cmd = { 'plz', 'tool', 'lps' },
  filetypes = { 'please' },
  root_markers = { '.plzconfig' },
  workspace_required = true,
})

---@type table<integer, string>
local buf_goroots = {}

vim.api.nvim_create_autocmd('VimEnter', {
  group = vim.api.nvim_create_augroup('please.nvim_gopls_config', {}),
  desc = 'Configure gopls language server to use appropriate GOROOT when started in a Please repository',
  callback = function()
    if not vim.lsp.config.gopls then
      return
    end
    local original_cmd = vim.lsp.config.gopls.cmd
    if type(original_cmd) ~= 'table' then
      return
    end
    local original_root_dir = vim.lsp.config.gopls.root_dir
    if not original_root_dir then
      return
    end
    ---@type vim.lsp.Config
    local config = {
      root_dir = function(bufnr, cb)
        local filename = vim.api.nvim_buf_get_name(bufnr)
        local plz_root = vim.fs.root(filename, '.plzconfig')
        if not plz_root then
          if type(original_root_dir) == 'string' then
            cb(original_root_dir)
          else
            original_root_dir(bufnr, cb)
          end
          return
        end
        -- If this call is not scheduled, two FileType events fire causing root_dir to be called twice. Not sure why...
        vim.schedule(function()
          query.with_goroot(plz_root, function(goroot, err)
            if goroot then
              buf_goroots[bufnr] = goroot
            else
              logging.warn('starting gopls in repository "%s": %s', plz_root, err)
            end
            if type(original_root_dir) == 'string' then
              cb(original_root_dir)
            else
              original_root_dir(bufnr, cb)
            end
          end)
        end)
      end,
      cmd = function(dispatchers)
        local config = vim.lsp.config.gopls
        local bufnr = vim.api.nvim_get_current_buf()
        local goroot = buf_goroots[bufnr]
        if goroot then
          config = vim.deepcopy(config)
          config.cmd_env = config.cmd_env or {}
          config.cmd_env.GOROOT = goroot
        end
        return vim.lsp.rpc.start(original_cmd, dispatchers, {
          cwd = config.cmd_cwd,
          env = config.cmd_env,
          detached = config.detached,
        })
      end,
    }
    vim.lsp.config('gopls', config)
  end,
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

---@type table<string, string[]>
local cmd_opts = {
  test = { 'under_cursor' },
  debug = { 'under_cursor' },
}
local var_arg_cmds = { 'command' }

vim.api.nvim_create_user_command('Please', function(args)
  local cmd_name = args.fargs[1]
  local cmd_args = { unpack(args.fargs, 2) }

  local cmd = please[cmd_name]
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
      -- Lazily required please module defined above is only required on index. Require it here since vim.tbl_keys will
      -- not trigger this.
      local cmd_names = vim.tbl_keys(require('please'))
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
