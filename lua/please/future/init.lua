-- This module exports shims and vendorised implementations for various builtin APIs which aren't available in all
-- versions of Neovim that we support so that we can depend on the latest APIs.

local _vim = require('please.future._vim')
local fs = require('please.future._vim.fs')

return {
  vim = {
    fs = {
      -- TODO: remove when minimum nvim version is 0.10
      joinpath = vim.fs.joinpath or fs.joinpath,
      -- TODO: remove when minimum nvim version is 0.10
      root = vim.fs.root or fs.root,
    },
    -- TODO: remove when minimum nvim version is 0.10
    system = vim.system or _vim.system,
    -- TODO: remove when minimum nvim version is 0.10
    uv = vim.uv or vim.loop,
  },
}
