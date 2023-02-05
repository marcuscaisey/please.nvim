-- get / set allow you to deal with (1, 1)-indexed cursor positions like the VimL getcurpos / cursor functions but
-- using the nvim API nvim_win_get_cursor / nvim_win_set_cursor functions under the hood which use the less intuitive
-- (1, 0)-indexed cursor positions.
local M = {}

---@class please.cursor.Position
---@field row integer: 1-based row number
---@field col integer: 1-based column number

---Get the cursor position.
---@return please.cursor.Position
M.get = function()
  local nvim_row, nvim_col = unpack(vim.api.nvim_win_get_cursor(0))
  return { row = nvim_row, col = nvim_col + 1 }
end

---Set the cursor position.
---@param pos please.cursor.Position
M.set = function(pos)
  vim.api.nvim_win_set_cursor(0, { pos.row, pos.col - 1 })
end

return M
