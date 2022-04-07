local stub = require 'luassert.stub'
local input = require 'please.input'

describe('select_if_required', function()
  it('should call vim.ui.select if more than one item is provided', function()
    local items = { 'a', 'b' }
    local prompt = 'prompt title'
    local callback = function(item)
      print(item)
    end

    local called_items, called_opts, called_callback
    local stubbed_select = stub(vim.ui, 'select', function(items, opts, callback)
      called_items, called_opts, called_callback = items, opts, callback
    end)

    input.select_if_required(items, prompt, callback)

    assert.are.same(items, called_items, 'incorrect items passed to vim.ui.select')
    assert.are.same({ prompt = prompt }, called_opts, 'incorrect opts passed to vim.ui.select')
    assert.are.equal(callback, called_callback, 'callback called with incorrect arg')

    stubbed_select:revert()
  end)

  it('should call callback and not vim.ui.select if one item is provided', function()
    local items = { 'a' }
    local prompt = 'prompt title'

    local passed_callback_arg
    input.select_if_required(items, prompt, function(item)
      passed_callback_arg = item
    end)

    assert.are.equal(passed_callback_arg, items[1], 'callback called with incorrect arg')
  end)

  it('should raise error if no items provided', function()
    local items = {}
    local prompt = 'prompt title'

    assert.has_error(function()
      input.select_if_required(items, prompt, function(item)
        print(item)
      end)
    end, 'at least one item must be provided, got none')
  end)
end)
