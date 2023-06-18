-- This module exports shims for various builtin APIs which aren't available in all versions of Neovim that we support
-- so that we can depend on the latest APIs.

-- vim.treesitter.query.parse_query was deprecated in nvim 0.9 and replaced with vim.treesitter.query.parse
-- TODO: remove when minimum nvim version is 0.9
---@diagnostic disable-next-line: deprecated
local parse = vim.treesitter.query.parse or vim.treesitter.query.parse_query

-- vim.treesitter.get_node_at_pos was deprecated in nvim 0.9 and replaced with vim.treesitter.get_node
-- TODO: remove when minimum nvim version is 0.9
local get_node = vim.treesitter.get_node
  or function()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    -- nvim_win_get_cursor is (1,0)-indexed and get_node_at_pos is (0,0)-indexed
    ---@diagnostic disable-next-line: deprecated
    return vim.treesitter.get_node_at_pos(0, row - 1, col, {})
  end

-- vim.fs.joinpath will available in nvim 0.10
-- TODO: remove when minimum nvim version is 0.10
local joinpath = vim.fs.joinpath or function(...)
  return (table.concat({ ... }, '/'):gsub('//+', '/'))
end

return {
  vim = {
    treesitter = {
      query = {
        parse = parse,
      },
      get_node = get_node,
    },
    fs = {
      joinpath = joinpath,
    },
  },
}
