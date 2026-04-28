local M = {}

---@class _please.config.Config
---@field formatting _please.config.FormattingConfig Configuration affecting formatting.
---@field history _please.config.HistoryConfig Configuration affecting [:Please-history].
---@field lsp _please.config.LSPConfig Configuration affecting LSP.

---@class _please.config.FormattingConfig
---@field puku_command string[]? Command to execute puku. nil means that puku formatting is not enabled.

---@class _please.config.HistoryConfig
---@field max_items integer The maximum number of history items to store for each repository.

---@class _please.config.LSPConfig
---@field gopls boolean Whether to configure the gopls language server for use in a Please repository.
---@field golangci_lint_langserver boolean Whether to configure the golangci-lint-langserver language server for use in a Please repository.
---@field basedpyright boolean Whether to configure the basedpyright language server for use in a Please repository.
---@field pyright boolean Whether to configure the pyright language server for use in a Please repository.

---@type _please.config.Config
local config = {
    formatting = { puku_command = nil },
    history = { max_items = 20 },
    lsp = {
        gopls = true,
        golangci_lint_langserver = true,
        basedpyright = true,
        pyright = true,
    },
}

---@param opts please.Opts
function M.update(opts)
    vim.validate('opts', opts, 'table')
    vim.validate('opts.history.max_items', vim.tbl_get(opts, 'history', 'max_items'), 'number', true)
    vim.validate('opts.lsp.gopls', vim.tbl_get(opts, 'lsp', 'gopls'), 'boolean', true)
    vim.validate(
        'opts.lsp.golangci_lint_langserver',
        vim.tbl_get(opts, 'lsp', 'golangci_lint_langserver'),
        'boolean',
        true
    )
    vim.validate('opts.lsp.basedpyright', vim.tbl_get(opts, 'lsp', 'basedpyright'), 'boolean', true)
    vim.validate('opts.lsp.pyright', vim.tbl_get(opts, 'lsp', 'pyright'), 'boolean', true)
    vim.validate('opts.formatting.puku_command', vim.tbl_get(opts, 'formatting', 'puku_command'), 'table', true)
    config = vim.tbl_deep_extend('force', config, opts)
end

---@return _please.config.Config
function M.get()
    return config
end

return M
