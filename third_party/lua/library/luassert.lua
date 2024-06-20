---@meta

---Assert that `value == true`.
---@param value any The value to confirm is `true`.
---@param msg string? An optional message to display if the assertion fails.
function assert.is_true(value, msg) end

---Assert that `type(value) == "nil"`.
---@param value any The value to confirm is of type `nil`.
---@param msg string? An optional message to display if the assertion fails.
function assert.is_nil(value, msg) end

---Assert that `type(value) ~= "nil"`.
---@param value any The value to confirm is not of type `nil`.
---@param msg string? An optional message to display if the assertion fails.
function assert.is_not_nil(value, msg) end
