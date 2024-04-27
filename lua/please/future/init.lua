-- This module exports shims and vendorised implementations for various builtin APIs which aren't available in all
-- versions of Neovim that we support so that we can depend on the latest APIs.

local _vim = require('please.future._vim')
local fs = require('please.future._vim.fs')
local treesitter = require('please.future._vim.treesitter')
local language = require('please.future._vim.treesitter.language')

return {
  vim = {
    fs = {
      -- vim.fs.joinpath will available in nvim 0.10
      -- TODO: remove when minimum nvim version is 0.10
      joinpath = vim.fs.joinpath or fs.joinpath,
    },
    -- vim.system will be available in nvim 0.10
    -- TODO: remove when minimum nvim version is 0.10
    system = vim.system or _vim.system,
    treesitter = {
      -- vim.treesitter.get_node_at_pos was deprecated in nvim 0.9 and replaced with vim.treesitter.get_node
      -- TODO: remove when minimum nvim version is 0.9
      get_node = vim.treesitter.get_node or treesitter.get_node,
      language = {
        -- vim.treesitter.language.register will be available in nvim 0.9
        -- TODO: remove when minimum nvim version is 0.9
        register = vim.treesitter.language.register or language.register,
      },
      query = {
        -- vim.treesitter.query.parse_query was deprecated in nvim 0.9 and replaced with vim.treesitter.query.parse
        -- TODO: remove when minimum nvim version is 0.9
        ---@diagnostic disable-next-line: deprecated
        parse = vim.treesitter.query.parse or vim.treesitter.query.parse_query,
      },
    },
    -- vim.loop will be deprecated in nvim 0.10 and replaced with vim.uv
    -- TODO: remove when minimum nvim version is 0.10
    uv = vim.uv or vim.loop,
  },
}
