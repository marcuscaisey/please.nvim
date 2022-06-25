local runners = require 'please.runners'

local start_winid = vim.api.nvim_get_current_win()

local tables_equal = function(t1, t2)
  if #t1 ~= #t2 then
    return false
  end
  for i, t1_v in ipairs(t1) do
    if t2[i] ~= t1_v then
      return false
    end
  end
  return true
end

local get_win_lines = function(winid, num_lines)
  num_lines = num_lines or -1
  local bufnr = vim.api.nvim_win_get_buf(winid)
  return vim.api.nvim_buf_get_lines(bufnr, 0, num_lines, false)
end

local assert_win_lines = function(expected_lines, winid, opts)
  opts = opts or {}

  local actual_lines, actual_lines_correct
  vim.wait(opts.timeout or 500, function()
    actual_lines = get_win_lines(winid, #expected_lines)
    actual_lines_correct = tables_equal(expected_lines, actual_lines)

    return actual_lines_correct
  end)

  assert(
    actual_lines_correct,
    string.format(
      'incorrect lines in buffer, expected %s, got %s',
      vim.inspect(expected_lines),
      vim.inspect(actual_lines)
    )
  )
end

local wait_for_win_lines = function(winid, opts)
  local current_win_lines = get_win_lines(winid)
  local lines_changed = false

  -- Wait for at most timeout milliseconds after each change to the win lines for another one. Assuming that if no
  -- changes come within that time, then there won't be anymore.
  while lines_changed do
    vim.wait(opts.timeout or 500, function()
      local new_win_lines = get_win_lines(winid)
      lines_changed = not tables_equal(new_win_lines, current_win_lines)
      return lines_changed
    end)
  end

  return current_win_lines
end

local wait_for_new_win = function(timeout)
  local current_winid
  local new_win_opened
  vim.wait(timeout or 500, function()
    current_winid = vim.api.nvim_get_current_win()
    new_win_opened = current_winid ~= start_winid
    return new_win_opened
  end)
  assert(new_win_opened, 'expected new window to be opened')
  return current_winid
end

local wait_for_win = function(winid, timeout)
  local current_winid
  local current_win_correct
  vim.wait(timeout or 500, function()
    current_winid = vim.api.nvim_get_current_win()
    current_win_correct = current_winid == winid
    return current_win_correct
  end)
  assert(current_win_correct, string.format('expected current window to be %d, was %d', winid, current_winid))
end

describe('popup', function()
  before_each(function()
    vim.api.nvim_set_current_win(start_winid)
  end)

  it('should output stdout from command in new window', function()
    local cmd = 'bash'
    local args = { '-c', 'for i in $(seq 1 5); do echo line $i; done' }

    runners.popup(cmd, args)

    local popup_winid = wait_for_new_win()
    assert_win_lines({ 'line 1', 'line 2', 'line 3', 'line 4', 'line 5' }, popup_winid)
  end)

  it('should output stderr from command in new window', function()
    local cmd = 'bash'
    local args = { '-c', 'for i in $(seq 1 5); do echo line $i >&2; done' }

    runners.popup(cmd, args)

    local popup_winid = wait_for_new_win()
    assert_win_lines({ 'line 1', 'line 2', 'line 3', 'line 4', 'line 5' }, popup_winid)
  end)

  it('outputs stdout and stderr together', function()
    local cmd = 'bash'
    local args = { '-c', 'echo stdout; echo stderr >&2' }

    runners.popup(cmd, args)

    local popup_winid = wait_for_new_win()
    assert_win_lines({ 'stdout', 'stderr' }, popup_winid)
  end)

  it('should close when q is pressed', function()
    local cmd = 'ls'
    local args = {}

    runners.popup(cmd, args)
    local popup_winid = wait_for_new_win()

    vim.api.nvim_feedkeys('q', 'x', false)

    wait_for_win(start_winid)
    assert.is_false(vim.api.nvim_win_is_valid(popup_winid), 'expected popup window to not be valid')
  end)

  it('should close when focus is lost', function()
    local cmd = 'ls'
    local args = {}

    runners.popup(cmd, args)
    local popup_winid = wait_for_new_win()

    vim.api.nvim_set_current_win(start_winid)

    assert.is_false(vim.api.nvim_win_is_valid(popup_winid), 'expected popup window to not be valid')
  end)

  it('should kill the running command when q is pressed', function()
    local cmd = 'bash'
    local args = { '-c', 'for i in $(seq 1 1000); do echo line $i && sleep 0.1; done' }

    runners.popup(cmd, args)
    wait_for_new_win()

    vim.api.nvim_feedkeys('q', 'x', false)

    wait_for_win(start_winid)
    -- If the command is still running, then it should keep outputting to the popup which now doesn't exist, resulting
    -- in errors. We do some waiting here to give it a chance to actually output some stuff before the test finishes.
    vim.wait(1000, function()
      return false
    end)
  end)

  it('should kill the running command when focus is lost', function()
    local cmd = 'bash'
    local args = { '-c', 'for i in $(seq 1 1000); do echo line $i && sleep 0.1; done' }

    runners.popup(cmd, args)
    local popup_winid = wait_for_new_win()

    vim.api.nvim_set_current_win(start_winid)

    assert.is_false(vim.api.nvim_win_is_valid(popup_winid), 'expected popup window to not be valid')
    -- If the command is still running, then it should keep outputting to the popup which now doesn't exist, resulting
    -- in errors. We do some waiting here to give it a chance to actually output some stuff before the test finishes.
    vim.wait(1000, function()
      return false
    end)
  end)

  -- TODO: get this test working, it passes atm but it also passes when i is not mapped to <nop>. for some reason, even
  -- i is not sending the buffer into terminal mode like it should
  -- it('i does not enter terminal mode', function()
  --   local cmd = 'ls'
  --   local args = {}

  --   runners.popup(cmd, args)
  --   wait_for_new_win()

  --   vim.api.nvim_feedkeys('i', 'x', false)
  --   -- if the above i entered terminal mode, then the q below would not exit the pop
  --   vim.api.nvim_feedkeys('q', 'x', false)

  --   wait_for_win(start_winid)
  -- end)

  -- TODO: get this test working, vim.api.nvim_win_get_cursor(popup_winid)[1] is returning 1 everytime
  -- it('should move cursor to last line of new window', function()
  --   local cmd = 'bash'
  --   local args = { '-c', 'for i in $(seq 1 5); do echo line $i; done' }

  --   runners.popup(cmd, args)

  --   local popup_winid = wait_for_new_win()
  --   assert_win_lines({ 'line 1', 'line 2', 'line 3', 'line 4', 'line 5' }, popup_winid)
  --   local last_buf_line = vim.api.nvim_buf_line_count(vim.fn.winbufnr(popup_winid))
  --   local current_cursor_line = vim.api.nvim_win_get_cursor(popup_winid)[1]
  --   assert.are.equal(last_buf_line, current_cursor_line, 'incorrect cursor line')
  -- end)

  it('should output the command and args after it exits', function()
    local cmd = 'bash'
    local args = { '-c', 'echo "hello"' }

    runners.popup(cmd, args)

    local popup_winid = wait_for_new_win()
    assert_win_lines({ 'hello', '', 'Command:', 'bash -c echo "hello"' }, popup_winid)
  end)
end)

describe('resume_popup', function()
  it('should show output from closed popup in new window', function()
    runners.popup('bash', { '-c', 'echo "hello"' })
    local popup_winid = wait_for_new_win()
    local popup_lines = wait_for_win_lines(popup_winid)

    vim.api.nvim_feedkeys('q', 'x', false)
    wait_for_win(start_winid)

    local err = runners.resume_popup()
    assert.is_nil(err, 'expected no error')

    local resumed_popup_winid = wait_for_new_win()
    assert.are_not.equal(
      popup_winid,
      resumed_popup_winid,
      'expected popup winid and resumed popup winid to be different'
    )
    assert_win_lines(popup_lines, resumed_popup_winid)
  end)
end)
