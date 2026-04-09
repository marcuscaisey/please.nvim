vim.g.mapleader = ' '

-- please.nvim
vim.pack.add({ 'https://github.com/marcuscaisey/please.nvim' })

-- LSP
vim.pack.add({ 'https://github.com/neovim/nvim-lspconfig' })
vim.lsp.enable({ 'gopls', 'basedpyright' })

-- Tree-sitter
vim.pack.add({ 'https://github.com/nvim-treesitter/nvim-treesitter' })
local treesitter = require('nvim-treesitter')
treesitter.install({ 'go', 'python' })
vim.api.nvim_create_autocmd('FileType', { command = 'lua pcall(vim.treesitter.start)' })

-- DAP
vim.pack.add({
    'https://github.com/mfussenegger/nvim-dap',
    'https://github.com/nvim-neotest/nvim-nio',
    'https://github.com/rcarriga/nvim-dap-ui',
})
local dapui = require('dapui')
dapui.setup()
local dap = require('dap')
dap.listeners.before.attach.dapui_config = dapui.open
dap.listeners.before.launch.dapui_config = dapui.open
dap.listeners.before.event_terminated.dapui_config = dapui.close
dap.listeners.before.event_exited.dapui_config = dapui.close
