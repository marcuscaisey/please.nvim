local M = {}

---Wrapper around vim.ui.select which only calls it if more than one item is provided, otherwise vim.ui.select is
---skipped and the provided callback is just called with the only item.
---@param items string[]: items to choose between
---@param prompt string: prompt to show in the select popup
---@param callback fun(selected_item:string) function to call with the selected item
M.select_if_required = function(items, prompt, callback)
  if #items == 0 then
    error 'at least one item must be provided, got none'
  elseif #items > 1 then
    vim.ui.select(items, { prompt = prompt }, callback)
  else
    callback(items[1])
  end
end

return M
