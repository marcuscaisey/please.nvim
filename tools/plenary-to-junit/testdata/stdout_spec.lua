describe('describe', function()
  it('passes', function()
    print('passes stdout')
  end)

  it('fails 1', function()
    print('fails 1 stdout')
    error('error message')
  end)

  -- We have this to test that we're not mixing up the failure output from fails 1 with the stdout of fails 2
  it('fails 2', function()
    print('fails 2 output')
    error('error message')
  end)

  pending('skips', function()
    print('skips stdout')
  end)

  print('errors stdout')
  error('error message')
end)
