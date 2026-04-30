local M = {}

local function check_general()
    local plz = require('_please.plz')

    vim.health.start('General')
    if vim.fn.executable(plz) == 1 then
        local cmd = { plz, '--version' }
        local res = vim.system(cmd):wait()
        if res.code == 0 then
            local path = vim.fn.exepath(plz)
            local version = vim.trim(res.stdout)
            vim.health.ok(string.format('%s (%s)', version, path))
        else
            vim.health.warn(
                string.format('found `%s` but failed to run `%s`', plz, table.concat(cmd, ' ')),
                { res.stderr }
            )
        end
    else
        vim.health.error(
            string.format('%s not available', plz),
            'Install please: https://please.build/quickstart.html#installing'
        )
    end

    local min_nvim_version = '0.11.0'
    local nvim_version_out = vim.api.nvim_exec2('version', { output = true }).output
    local nvim_version = nvim_version_out:match('NVIM (v[^\n]+)') or 'unknown'
    if vim.fn.has(string.format('nvim-%s', min_nvim_version)) == 1 then
        vim.health.ok(string.format('Neovim version >= %s (%s)', min_nvim_version, nvim_version))
    else
        vim.health.error(
            string.format('Neovim version < %s (%s)', min_nvim_version, nvim_version),
            string.format('Upgrade to Neovim %s or newer', min_nvim_version)
        )
    end
end

local function check_configuration()
    local config = require('_please.config')
    vim.health.start('Configuration')
    local settings = vim.tbl_keys(config.get())
    table.sort(settings)
    for _, setting in ipairs(settings) do
        vim.health.info(string.format('%s: %s', setting, vim.inspect(config.get()[setting])))
    end
end

local function check_tree_sitter()
    vim.health.start('Tree-Sitter')
    local lang_needed_fors = {
        python = [[
Needed for:
  - |:Please-test-under_cursor|, |:Please-cover-under_cursor|, and
    |:Please-debug-under_cursor| in Python files.
  - |:Please-jump_to_target| and |:Please-look_up_target|.
  - |:Please-build|, |:Please-run|, |:Please-test|, |:Please-debug|, and
    |:Please-yank| in BUILD files.]],
        go = [[
Needed for |:Please-test-under_cursor|, |:Please-cover-under_cursor|, and
|:Please-debug-under_cursor| in Go files.]],
    }
    for lang, needed_for in pairs(lang_needed_fors) do
        if vim.treesitter.language.add(lang) then
            vim.health.ok(string.format('%s parser available', lang))
        else
            vim.health.warn(string.format('%s parser not available.\n%s', lang, needed_for), ':help treesitter-parsers')
        end
    end
end

local function check_debugging()
    vim.health.start('Debugging')
    if pcall(require, 'dap') then
        vim.health.ok(string.format('nvim-dap available'))
    else
        vim.health.warn(
            'nvim-dap not available.\nNeeded for |:Please-debug|.',
            'Install nvim-dap: https://github.com/mfussenegger/nvim-dap'
        )
    end
end

function M.check()
    check_general()
    check_configuration()
    check_tree_sitter()
    check_debugging()
end

return M
