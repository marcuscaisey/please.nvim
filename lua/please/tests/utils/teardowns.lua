---@class TeardownFuncs A thin table wrapper which contains a group of teardown functions which provides methods for adding functions and calling them all.
TeardownFuncs = {}

function TeardownFuncs:new()
  local obj = {
    teardowns = {},
  }
  self.__index = self
  return setmetatable(obj, self)
end

---Add a teardown function to the group.
function TeardownFuncs:add(teardown)
  table.insert(self.teardowns, teardown)
end

---Call all teardown functions and reset the group to empty.
function TeardownFuncs:teardown()
  for _, teardown in ipairs(self.teardowns) do
    teardown()
  end
  self.teardowns = {}
end

return TeardownFuncs
