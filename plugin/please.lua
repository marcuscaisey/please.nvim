local min_nvim_version = '0.11.1'
if vim.fn.has(string.format('nvim-%s', min_nvim_version)) == 0 then
    vim.notify(string.format('please.nvim requires at least Neovim %s', min_nvim_version), vim.log.levels.ERROR)
    return
end

if vim.g.loaded_please then
    return
end

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

---@type table<integer, boolean>
local seen_go_clients = {}

vim.api.nvim_create_autocmd('LspAttach', {
    desc = 'Configure gopls to use appropriate GOROOT when started in a Please repository',
    group = vim.api.nvim_create_augroup('please.nvim_gopls_config', {}),
    pattern = '*.go',
    callback = function(ev)
        if seen_go_clients[ev.data.client_id] then
            return
        end
        seen_go_clients[ev.data.client_id] = true

        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client or client.name ~= 'gopls' or not client.root_dir then
            return
        end

        local plz_root = vim.fs.root(client.root_dir, '.plzconfig')
        if not plz_root then
            return
        end

        local logging = require('_please.logging')
        local query = require('_please.query')

        local goroot, err = query.goroot(plz_root)
        if err then ---@cast goroot -?
            logging.warn('configuring gopls in repository "%s": %s', plz_root, err)
            return
        end

        client.settings = vim.tbl_deep_extend('force', client.settings, { gopls = { env = { GOROOT = goroot } } })
        client:notify('workspace/didChangeConfiguration', { settings = vim.NIL })
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
