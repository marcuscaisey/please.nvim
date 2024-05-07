describe('describe 1', function()
  it('passes', function() end)

  it('raises error', function()
    error('error message')
  end)

  it('asserts with no message', function()
    assert.equal(1, 2)
  end)

  it('asserts with message', function()
    assert.equal(1, 2, 'failure message')
  end)

  pending('skips', function()
    error('should not be raised')
  end)
end)

describe('describe 2', function()
  it('passes', function() end)

  it('fails', function()
    error('error message')
  end)
end)
