-- get / set allow you to deal with (1, 1)-indexed cursor positions like the VimL getcurpos / cursor functions but
-- using the nvim API nvim_win_get_cursor / nvim_win_set_cursor functions under the hood which use the less intuitive
-- (1, 0)-indexed cursor positions.
local M = {}

---Get the (1, 1)-indexed cursor position.
---@return number[] (row, col) tuple
M.get = function()
  local nvim_row, nvim_col = unpack(vim.api.nvim_win_get_cursor(0))
  return { nvim_row, nvim_col + 1 }
end

---Set the (1, 1)-indexed cursor position.
---@param position number[] (row, col) tuple
M.set = function(position)
  local row, col = unpack(position)
  vim.api.nvim_win_set_cursor(0, { row, col - 1 })
end

return M
