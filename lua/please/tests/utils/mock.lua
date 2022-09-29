local stub = require 'luassert.stub'
local runners = require 'please.runners'

local M = {}

M.PlzPopup = {}

function M.PlzPopup:new(root)
  assert.is_not_nil(root, 'root must be passed to MockM.PlzPopup')
  local obj = {
    _root = root,
    _called = false,
    _cmd = nil,
    _args = nil,
  }
  obj._stubbed_popup = stub(runners, 'popup', function(cmd, args)
    obj._cmd, obj._args = cmd, args
    obj._called = true
  end)
  self.__index = self
  return setmetatable(obj, self)
end

function M.PlzPopup:assert_called_with(args)
  if not self._called then
    error 'cannot assert on popup args before it has been called'
  end
  assert.are.equal('plz', self._cmd, 'incorrect command passed to popup')
  assert.are.same(
    { '--repo_root', self._root, '--interactive_output', '--colour', unpack(args) },
    self._args,
    'incorrect args passed to popup'
  )
end

function M.PlzPopup:revert()
  self._stubbed_popup:revert()
end

M.Select = {}

function M.Select:new()
  local obj = {
    _called = false,
    _items = nil,
    _formatted_items = nil,
    _opts = nil,
    _on_choice = nil,
  }
  obj._stubbed_select = stub(vim.ui, 'select', function(items, opts, on_choice)
    obj._items, obj._opts, obj._on_choice = items, opts, on_choice
    obj._formatted_items = vim.tbl_map(opts.format_item or tostring, items)
    obj._called = true
  end)
  self.__index = self
  return setmetatable(obj, self)
end

function M.Select:assert_items(items)
  if not self._called then
    error 'cannot assert on vim.ui.select items before it has been called'
  end
  assert.are.same(items, self._formatted_items, 'incorrect items passed to vim.ui.select')
end

function M.Select:assert_prompt(prompt)
  if not self._called then
    error 'cannot assert on vim.ui.select prompt before it has been called'
  end
  assert.is_not_nil(self._opts.prompt, 'expected prompt opt passed to vim.ui.select')
  assert.are.equal(prompt, self._opts.prompt, 'incorrect prompt opt passed to vim.ui.select')
end

function M.Select:choose_item(item)
  if not self._called then
    error 'cannot choose vim.ui.select item before it has been called'
  end
  if not vim.tbl_contains(self._formatted_items, item) then
    error(
      string.format(
        'cannot choose item "%s" which was not passed to vim.ui.select, available choices are: %s',
        item,
        vim.inspect(self._formatted_items)
      )
    )
  end
  for i, v in ipairs(self._formatted_items) do
    if v == item then
      self._on_choice(self._items[i], i)
    end
  end
end

function M.Select:revert()
  self._stubbed_select:revert()
end

M.Input = {}

function M.Input:new()
  local obj = {
    _called = false,
    _opts = nil,
    _on_confirm = nil,
    _stubbed_input = nil,
  }
  obj._stubbed_input = stub(vim.ui, 'input', function(opts, on_confirm)
    obj._opts, obj._on_confirm = opts, on_confirm
    obj._called = true
  end)
  self.__index = self
  return setmetatable(obj, self)
end

function M.Input:assert_prompt(prompt)
  if not self._called then
    error 'cannot assert on vim.ui.input prompt before it has been called'
  end
  assert.is_not_nil(self._opts.prompt, 'expected prompt opt passed to vim.ui.input')
  assert.are.equal(prompt, self._opts.prompt, 'incorrect prompt opt passed to vim.ui.input')
end

function M.Input:enter_input(input)
  if not self._called then
    error 'cannot enter vim.ui.input input before it has been called'
  end
  self._on_confirm(input)
end

function M.Input:revert()
  self._stubbed_input:revert()
end

return M
