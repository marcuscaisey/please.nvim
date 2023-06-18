-- This module exports shims for various builtin APIs which aren't available in all versions of Neovim that we support
-- so that we can depend on the latest APIs.
return {
  vim = {
    treesitter = {
      query = {
        -- TODO: vim.treesitter.query.parse_query is deprecated since nvim 0.9, remove when minimum nvim version is 0.10
        ---@diagnostic disable-next-line: deprecated
        parse = vim.treesitter.query.parse or vim.treesitter.query.parse_query,
      },
    },
  },
}
