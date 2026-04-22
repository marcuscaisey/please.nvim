vim.g.loaded_python3_provider = 0
vim.g.mapleader = ' '
vim.o.signcolumn = 'yes'

-- please.nvim
vim.pack.add({ 'https://github.com/marcuscaisey/please.nvim' })
-- vim.cmd('set runtimepath^=.')
local please = require('please')
please.setup({
    -- max_history_items = 20,
    -- configure_gopls = true,
    -- configure_golangci_lint_langserver = true,
    -- configure_basedpyright = true,
    -- configure_pyright = true,
    puku_command = { 'plz', 'puku' },
})
vim.keymap.set('n', '<leader>pb', '<Cmd>Please build<CR>')
vim.keymap.set('n', '<leader>pr', '<Cmd>Please run<CR>')
vim.keymap.set('n', '<leader>pt', '<Cmd>Please test<CR>')
vim.keymap.set('n', '<leader>pct', '<Cmd>Please test under_cursor<CR>')
vim.keymap.set('n', '<leader>pd', '<Cmd>Please debug<CR>')
vim.keymap.set('n', '<leader>pcd', '<Cmd>Please debug under_cursor<CR>')
vim.keymap.set('n', '<leader>ph', '<Cmd>Please history<CR>')
vim.keymap.set('n', '<leader>pch', '<Cmd>Please clear_history<CR>')
vim.keymap.set('n', '<leader>pp', '<Cmd>Please set_profile<CR>')
vim.keymap.set('n', '<leader>pm', '<Cmd>Please maximise_popup<CR>')
vim.keymap.set('n', '<leader>pj', '<Cmd>Please jump_to_target<CR>')
vim.keymap.set('n', '<leader>pl', '<Cmd>Please look_up_target<CR>')
vim.keymap.set('n', '<leader>py', '<Cmd>Please yank<CR>')

-- LSP
vim.pack.add({ 'https://github.com/neovim/nvim-lspconfig', 'https://github.com/mason-org/mason.nvim' })
vim.lsp.enable({
    'basedpyright',
    'golangci_lint_ls',
    'gopls',
    -- 'pyright',
})
local mason = require('mason')
local mason_registry = require('mason-registry')
mason.setup()
local servers = {
    'basedpyright',
    'gopls',
    'golangci-lint-langserver',
    -- 'pyright',
}
local servers_to_install = vim.tbl_filter(function(server)
    return not mason_registry.is_installed(server)
end, servers)
if #servers_to_install > 0 then
    vim.cmd.MasonInstall({ args = servers_to_install })
end

-- Tree-sitter
vim.pack.add({ 'https://github.com/nvim-treesitter/nvim-treesitter' })
local treesitter = require('nvim-treesitter')
treesitter.install({ 'go', 'ini', 'python' })
vim.api.nvim_create_autocmd('FileType', { command = 'lua pcall(vim.treesitter.start)' })

-- DAP
vim.pack.add({
    'https://github.com/mfussenegger/nvim-dap',
    'https://github.com/nvim-neotest/nvim-nio',
    'https://github.com/rcarriga/nvim-dap-ui',
})
local dap = require('dap')
local dapui = require('dapui')
dap.listeners.before.attach.dapui_config = dapui.open
dap.listeners.before.launch.dapui_config = dapui.open
dap.listeners.before.event_terminated.dapui_config = dapui.close
dap.listeners.before.event_exited.dapui_config = dapui.close
dapui.setup()

-- fzf
vim.pack.add({ 'https://github.com/ibhagwan/fzf-lua' })
local fzf = require('fzf-lua')
fzf.setup({ ui_select = true })
