describe('describe 1 has error', function()
  error('error message')
end)

describe('describe 2', function()
  it('passes', function() end)

  it('fails', function()
    error('error message')
  end)
end)
