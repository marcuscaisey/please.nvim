local M = {}

---@class _please.config.Config
---@field max_history_items integer The maximum number of history items to store for each repository.
---@field configure_gopls boolean Whether to configure the gopls language server for use in a Please repository. .
---@field configure_golangci_lint_langserver boolean Whether to configure the golangci-lint-langserver language server for use in a Please repository. .
---@field configure_basedpyright boolean Whether to configure the basedpyright language server for use in a Please repository. .
---@field configure_pyright boolean Whether to configure the pyright language server for use in a Please repository. .
---@field puku_command string[]? Command to execute puku.

---@type _please.config.Config
local config = {
    max_history_items = 20,
    configure_gopls = true,
    configure_golangci_lint_langserver = true,
    configure_basedpyright = true,
    configure_pyright = true,
    puku_command = nil,
}

---@param opts please.Opts
function M.update(opts)
    vim.validate('opts', opts, 'table')
    vim.validate('opts.max_history_items', opts.max_history_items, 'number', true)
    vim.validate('opts.configure_gopls', opts.configure_gopls, 'boolean', true)
    vim.validate('opts.configure_golangci_lint_langserver', opts.configure_golangci_lint_langserver, 'boolean', true)
    vim.validate('opts.configure_basedpyright', opts.configure_basedpyright, 'boolean', true)
    vim.validate('opts.configure_pyright', opts.configure_pyright, 'boolean', true)
    vim.validate('opts.puku_command', opts.puku_command, 'table', true)
    config = vim.tbl_deep_extend('force', config, opts)
end

---@return _please.config.Config
function M.get()
    return config
end

return M
