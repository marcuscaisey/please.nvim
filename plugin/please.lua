local min_nvim_version = '0.11.0'
if vim.fn.has(string.format('nvim-%s', min_nvim_version)) == 0 then
    vim.notify(string.format('please.nvim requires at least Neovim %s', min_nvim_version), vim.log.levels.ERROR)
    return
end

if vim.g.loaded_please then
    return
end

---Port of the Go standard library os.UserCacheDir function.
---@return string?
---@return string? errmsg
local function user_cache_dir()
    local dir = ''

    local sysname = vim.uv.os_uname().sysname
    if sysname == 'Windows_NT' then
        dir = vim.env.LOCALAPPDATA
        if not dir or dir == '' then
            return nil, '%LocalAppData% is not defined'
        end
    elseif sysname == 'Darwin' then
        dir = vim.env.HOME
        if not dir or dir == '' then
            return nil, '$HOME is not defined'
        end
        dir = dir .. '/Library/Caches'
    else -- Unix
        dir = vim.env.XDG_CACHE_HOME
        if not dir or dir == '' then
            dir = vim.env.HOME
            if not dir or dir == '' then
                return nil, 'neither $XDG_CACHE_HOME nor $HOME are defined'
            end
            dir = dir .. '/.cache'
        elseif not vim.startswith(dir, '/') then
            return nil, 'path in $XDG_CACHE_HOME is relative'
        end
    end

    return dir
end

---@param path string
---@return string?
local function build_defs_filetype_matcher(path)
    if vim.fs.root(path, '.plzconfig') then
        return 'please'
    end
    local user_cache_dir = user_cache_dir()
    if not user_cache_dir then
        return nil
    end
    local plz_cache_dir = vim.fs.joinpath(user_cache_dir, 'please')
    if vim.fs.dirname(path) == plz_cache_dir then
        return 'please'
    end
end

vim.filetype.add({
    extension = {
        build = build_defs_filetype_matcher,
        build_defs = build_defs_filetype_matcher,
    },
    pattern = {
        ['%.plzconfig.*'] = 'dosini',
    },
})

local build_file_names_by_root = {} ---@type table<string, string[]>

vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    desc = 'Set filetype to please if file is a build file',
    group = vim.api.nvim_create_augroup('please.set_build_file_filetype', {}),
    callback = function(ev)
        local root = vim.fs.root(ev.match, '.plzconfig')
        if not root then
            return
        end

        local query = require('_please.query')

        local build_file_names = build_file_names_by_root[root]
        if not build_file_names then
            local build_file_names_from_config, err = query.config(root, 'parse.buildfilename')
            if err then
                build_file_names = { 'BUILD', 'BUILD.plz' }
                local logging = require('_please.logging')
                logging.debug(
                    'Resolving build file names in repository "%s": %s. Falling back to %s.',
                    root,
                    err,
                    vim.inspect(build_file_names)
                )
            else ---@cast build_file_names_from_config -?
                build_file_names = build_file_names_from_config
            end
            build_file_names_by_root[root] = build_file_names
        end

        local filename = vim.fs.basename(ev.match)
        if vim.list_contains(build_file_names, filename) then
            vim.bo[ev.buf].filetype = 'please'
        end
    end,
})

vim.treesitter.language.register('python', 'please')

vim.lsp.config('please', {
    cmd = { 'plz', 'tool', 'lps' },
    filetypes = { 'please' },
    root_markers = { '.plzconfig' },
    workspace_required = true,
})

---@param dir string
---@return boolean
local function dir_is_plz_root(dir)
    return vim.uv.fs_stat(vim.fs.joinpath(dir, '.plzconfig')) ~= nil
end

---@type table<integer, boolean>
local seen_go_clients = {}

vim.api.nvim_create_autocmd('LspAttach', {
    desc = 'Configure gopls and golangci-lint-langserver for use in a Please repository',
    group = vim.api.nvim_create_augroup('please.go_lsp_config', {}),
    pattern = '*.go',
    callback = function(ev)
        if seen_go_clients[ev.data.client_id] then
            return
        end
        seen_go_clients[ev.data.client_id] = true

        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client or not client.root_dir or not dir_is_plz_root(client.root_dir) then
            return
        end

        local config = require('_please.config')
        if
            not (client.name == 'gopls' and config.get().configure_gopls)
            and not (client.name == 'golangci_lint_ls' and config.get().configure_golangci_lint_langserver)
        then
            return
        end

        local logging = require('_please.logging')
        local query = require('_please.query')

        local goroot, err = query.goroot(client.root_dir)
        if err then ---@cast goroot -?
            logging.debug('configuring %s in repository "%s": %s', client.name, client.root_dir, err)
            return
        end

        local config = vim.deepcopy(client.config)

        local path = vim.tbl_get(config, 'cmd_env', 'PATH') or vim.env.PATH
        config.cmd_env = vim.tbl_deep_extend('force', config.cmd_env or {}, {
            PATH = string.format('%s/bin:%s', goroot, path),
        })

        if client.name == 'gopls' then
            local directory_filters = vim.deepcopy(vim.tbl_get(client.settings, 'gopls', 'directoryFilters'))
                or { '-**/node_modules' }
            local plz_out_filter = '-plz-out'
            if not vim.list_contains(directory_filters, plz_out_filter) then
                table.insert(directory_filters, plz_out_filter)
            end
            config.settings = vim.tbl_deep_extend('force', client.settings, {
                gopls = { directoryFilters = directory_filters },
            })
        end

        local client_id = vim.lsp.start(config, {
            bufnr = ev.buf,
            reuse_client = function()
                return false
            end,
        })
        if client_id then
            seen_go_clients[client_id] = true
            client:stop(true)
        end
    end,
})

---@type table<integer, boolean>
local seen_python_clients = {}

vim.api.nvim_create_autocmd('LspAttach', {
    desc = 'Configure pyright and basedpyright for use in a Please repository',
    group = vim.api.nvim_create_augroup('please.python_lsp_config', {}),
    pattern = '*.py',
    callback = function(ev)
        if seen_python_clients[ev.data.client_id] then
            return
        end
        seen_python_clients[ev.data.client_id] = true

        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client or not client.root_dir or not dir_is_plz_root(client.root_dir) then
            return
        end

        local config = require('_please.config')
        if
            not (client.name == 'pyright' and config.get().configure_pyright)
            and not (client.name == 'basedpyright' and config.get().configure_basedpyright)
        then
            return
        end

        local section = client.name == 'basedpyright' and 'basedpyright' or 'python'

        local extra_paths = vim.deepcopy(vim.tbl_get(client.settings, section, 'analysis', 'extraPaths')) or {}
        local venv_path = 'plz-out/python/venv'
        if not vim.list_contains(extra_paths, venv_path) then
            table.insert(extra_paths, 1, venv_path)
        end

        local exclude = vim.deepcopy(vim.tbl_get(client.settings, section, 'analysis', 'exclude'))
            or { '**/node_modules', '**/__pycache__', '**/.*' }
        local plz_out_path = 'plz-out'
        if not vim.list_contains(exclude, plz_out_path) then
            table.insert(exclude, plz_out_path)
        end

        client.settings = vim.tbl_deep_extend('force', client.settings, {
            [section] = {
                analysis = {
                    extraPaths = extra_paths,
                    exclude = exclude,
                },
            },
        })
        client:notify('workspace/didChangeConfiguration', { settings = vim.NIL })
    end,
})

vim.api.nvim_create_autocmd('BufWritePost', {
    desc = 'Run puku fmt on saved file in a Please repository',
    group = vim.api.nvim_create_augroup('please.puku_fmt', {}),
    pattern = '*.go',
    callback = function(ev)
        local root = vim.fs.root(ev.match, '.plzconfig')
        if not root then
            return
        end

        local config = require('_please.config')
        local puku_command = config.get().puku_command
        if not puku_command then
            return
        end

        local logging = require('_please.logging')
        local cmd = vim.deepcopy(puku_command)
        vim.list_extend(cmd, { 'fmt', ev.match })
        local ok, err = pcall(vim.system, cmd, { cwd = root }, function(res)
            local output = res.code == 0 and vim.trim(res.stdout) or vim.trim(res.stderr)
            if output ~= '' then
                logging.info('puku: %s', output)
            end
        end)
        if not ok then
            logging.debug('Failed to format BUILD files with "%s": %s', table.concat(cmd, ' '), err)
        end
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
local hidden_cmds = { 'setup' }

vim.api.nvim_create_user_command('Please', function(args)
    local please = require('please')
    local logging = require('_please.logging')

    local cmd_name = args.fargs[1]
    local cmd_args = { unpack(args.fargs, 2) }

    local cmd = please[cmd_name]
    if not cmd or vim.tbl_contains(hidden_cmds, cmd_name) then
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
            local please = require('please')
            local cmd_names = vim.tbl_filter(function(cmd_name)
                return not vim.tbl_contains(hidden_cmds, cmd_name)
            end, vim.tbl_keys(please))
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
