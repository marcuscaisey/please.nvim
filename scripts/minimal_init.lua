vim.g.loaded_python3_provider = 0

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
