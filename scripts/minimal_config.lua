vim.g.mapleader = ' '

-- please.nvim
vim.cmd('set runtimepath^=.')
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
