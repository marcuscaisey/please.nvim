local M = {}

---Strips the prefix from a log output by plz like '16:31:10.793 CRITICAL:' or 'Error:'
---@param err string: a line logged by plz
---@return string: the stripped line
M.strip_plz_log_prefix = function(err)
  err = err:gsub('^%d+:%d+:%d+%.%d+ %u+: ', '')
  err = err:gsub('^Error: ', '')
  return err
end

return M
