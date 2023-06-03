describe('describe', function()
  local levels_by_value = {}
  for level, value in pairs(vim.log.levels) do
    levels_by_value[value] = level
  end
  local sorted_values = vim.tbl_values(vim.log.levels)
  table.sort(sorted_values)

  for _, value in pairs(sorted_values) do
    it(string.format('passes - %s', levels_by_value[value]), function()
      vim.notify(levels_by_value[value] .. ' log', value)
    end)
  end
end)
