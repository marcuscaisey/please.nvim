local M = {}

---Strips the prefix from a log output by plz like '16:31:10.793 CRITICAL:' or 'Error:'
---@param line string: a line logged by plz
---@return string: the stripped line
function M.strip_plz_log_prefix(line)
  line = line:gsub('^%d+:%d+:%d+%.%d+ %u+: ', '')
  line = line:gsub('^Error: ', '')
  return line
end

return M
