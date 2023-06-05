local popup = require('please.runners.popup')
local cursor = require('please.cursor')

---@generic T
---@param t1 T[]
---@param t2 T[]
---@return boolean
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

---@param winid number
---@param num_lines number?
---@return string[]
local get_win_lines = function(winid, num_lines)
  num_lines = num_lines or -1
  local bufnr = vim.api.nvim_win_get_buf(winid)
  return vim.api.nvim_buf_get_lines(bufnr, 0, num_lines, false)
end

---@param lines string[]
---@param width number
---@return string[]
local wrap_lines = function(lines, width)
  local wrapped_lines = {}
  for _, line in ipairs(lines) do
    for i = 1, math.ceil(#lines / width), 1 do
      table.insert(wrapped_lines, line:sub((i - 1) * width, i * width))
    end
  end
  return wrapped_lines
end

---@param expected_lines string[]
---@param winid number
local assert_win_lines = function(expected_lines, winid)
  -- lines exceeding the width of the window will be wrapped when output, so we need to wrap expected_lines to match
  local win_width = vim.fn.winwidth(winid)
  local wrapped_expected_lines = wrap_lines(expected_lines, win_width)

  local actual_lines, actual_lines_correct
  vim.wait(500, function()
    actual_lines = get_win_lines(winid, #wrapped_expected_lines)
    actual_lines_correct = tables_equal(wrapped_expected_lines, actual_lines)
    return actual_lines_correct
  end)

  assert(
    actual_lines_correct,
    string.format(
      'incorrect lines in buffer, expected %s, got %s',
      vim.inspect(wrapped_expected_lines),
      vim.inspect(actual_lines)
    )
  )
end

---@param winid number
---@return string[]
local wait_for_win_lines = function(winid)
  local current_win_lines = get_win_lines(winid)
  local lines_changed = true

  -- Wait for at most timeout milliseconds after each change to the win lines for another one. Assuming that if no
  -- changes come within that time, then there won't be anymore.
  while lines_changed do
    vim.wait(500, function()
      local new_win_lines = get_win_lines(winid)
      lines_changed = not tables_equal(new_win_lines, current_win_lines)
      current_win_lines = new_win_lines
      return lines_changed
    end)
  end

  return current_win_lines
end

---@param start_winid number
---@return number
local wait_for_new_win = function(start_winid)
  local current_winid
  local new_win_opened
  vim.wait(500, function()
    current_winid = vim.api.nvim_get_current_win()
    new_win_opened = current_winid ~= start_winid
    return new_win_opened
  end)
  assert(new_win_opened, 'expected new window to be opened')
  return current_winid
end

---@param winid number
local wait_for_win = function(winid)
  local current_winid
  local current_win_correct
  vim.wait(500, function()
    current_winid = vim.api.nvim_get_current_win()
    current_win_correct = current_winid == winid
    return current_win_correct
  end)
  assert(current_win_correct, string.format('expected current window to be %d, was %d', winid, current_winid))
end

local close_all_windows_but_one = function()
  -- Close all floating windows first
  while true do
    -- List the windows everytime because closing one floating window might cause another to be closed as well
    local wins = vim.api.nvim_list_wins()
    local floating_win
    for _, win in ipairs(wins) do
      local config = vim.api.nvim_win_get_config(win)
      if config.relative ~= '' then
        floating_win = win
        break
      end
    end
    if floating_win then
      vim.api.nvim_win_close(floating_win, true)
    else
      break
    end
  end
  -- Close all but one of the remaining windows
  local remaining_wins = vim.api.nvim_list_wins()
  for i = 1, #remaining_wins - 1 do
    vim.api.nvim_win_close(remaining_wins[i], true)
  end
end

describe('run', function()
  after_each(close_all_windows_but_one)

  it('should output stdout from command in new window', function()
    local start_winid = vim.api.nvim_get_current_win()

    popup.run('bash', { '-c', 'for i in $(seq 1 5); do echo line $i; done' })

    local popup_winid = wait_for_new_win(start_winid)
    assert_win_lines({ 'line 1', 'line 2', 'line 3', 'line 4', 'line 5' }, popup_winid)
  end)

  it('should output stderr from command in new window', function()
    local start_winid = vim.api.nvim_get_current_win()

    popup.run('bash', { '-c', 'for i in $(seq 1 5); do echo line $i >&2; done' })

    local popup_winid = wait_for_new_win(start_winid)
    assert_win_lines({ 'line 1', 'line 2', 'line 3', 'line 4', 'line 5' }, popup_winid)
  end)

  it('outputs stdout and stderr together', function()
    local start_winid = vim.api.nvim_get_current_win()

    popup.run('bash', { '-c', 'echo stdout; echo stderr >&2' })

    local popup_winid = wait_for_new_win(start_winid)
    assert_win_lines({ 'stdout', 'stderr' }, popup_winid)
  end)

  it('should close when q is pressed', function()
    local start_winid = vim.api.nvim_get_current_win()
    popup.run('ls')
    local popup_winid = wait_for_new_win(start_winid)

    vim.api.nvim_feedkeys('q', 'x', false)

    wait_for_win(start_winid)
    assert.is_false(vim.api.nvim_win_is_valid(popup_winid), 'expected popup window to not be valid')
  end)

  it('should close when focus is lost', function()
    local start_winid = vim.api.nvim_get_current_win()
    popup.run('ls')
    local popup_winid = wait_for_new_win(start_winid)

    vim.api.nvim_set_current_win(start_winid)

    assert.is_false(vim.api.nvim_win_is_valid(popup_winid), 'expected popup window to not be valid')
  end)

  it('should kill the running command when q is pressed', function()
    local start_winid = vim.api.nvim_get_current_win()
    popup.run('bash', { '-c', 'for i in $(seq 1 1000); do echo line $i && sleep 0.1; done' })
    wait_for_new_win(start_winid)

    vim.api.nvim_feedkeys('q', 'x', false)

    wait_for_win(start_winid)
    -- If the command is still running, then it should keep outputting to the popup which now doesn't exist, resulting
    -- in errors. We do some waiting here to give it a chance to actually output some stuff before the test finishes.
    vim.wait(1000, function()
      return false
    end)
  end)

  it('should kill the running command when focus is lost', function()
    local start_winid = vim.api.nvim_get_current_win()
    popup.run('bash', { '-c', 'for i in $(seq 1 1000); do echo line $i && sleep 0.1; done' })
    local popup_winid = wait_for_new_win(start_winid)

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
  pending('i does not enter terminal mode', function()
    local start_winid = vim.api.nvim_get_current_win()
    popup.run('ls')
    wait_for_new_win(start_winid)

    vim.api.nvim_feedkeys('i', 'x', false)
    -- if the above i entered terminal mode, then the q below would not exit the pop
    vim.api.nvim_feedkeys('q', 'x', false)

    wait_for_win(start_winid)
  end)

  -- TODO: get this test working, vim.api.nvim_win_get_cursor(popup_winid)[1] is returning 1 everytime
  pending('should move cursor to last line of new window', function()
    local start_winid = vim.api.nvim_get_current_win()

    popup.run('bash', { '-c', 'for i in $(seq 1 5); do echo line $i; done' })

    local popup_winid = wait_for_new_win(start_winid)
    assert_win_lines({ 'line 1', 'line 2', 'line 3', 'line 4', 'line 5' }, popup_winid)
    local last_buf_line = vim.api.nvim_buf_line_count(vim.fn.winbufnr(popup_winid))
    local current_cursor_line = vim.api.nvim_win_get_cursor(popup_winid)[1]
    assert.are.equal(last_buf_line, current_cursor_line, 'incorrect cursor line')
  end)

  it('should output the command / args and quit / restore info after it exits', function()
    local start_winid = vim.api.nvim_get_current_win()

    popup.run('bash', { '-c', 'echo "hello"' })

    local popup_winid = wait_for_new_win(start_winid)
    assert_win_lines({
      'hello',
      '',
      'bash -c echo "hello"',
      '',
      'Press q to quit',
      [[Call Please restore_popup or require('please.runners.popup').restore() to restore]],
    }, popup_winid)
  end)

  it('should call on_success if command is successful', function()
    local on_success_called = false

    popup.run('bash', { '-c', 'echo "hello"' }, {
      on_success = function()
        on_success_called = true
      end,
    })

    vim.wait(500, function()
      return on_success_called
    end)
    assert.is_true(on_success_called, 'expected on_success to be called')
  end)

  it('should not call on_success if command fails', function()
    local start_winid = vim.api.nvim_get_current_win()
    local on_success_called = false

    popup.run('bash', { '-c', 'echo output && exit 1' }, {
      on_success = function()
        on_success_called = true
      end,
    })

    local popup_winid = wait_for_new_win(start_winid)
    assert_win_lines({ 'output' }, popup_winid)
    assert.is_false(on_success_called, 'expected on_success to not be called')
  end)

  it('should pass callback to on_success which closes popup', function()
    local start_winid = vim.api.nvim_get_current_win()
    local close_callback
    popup.run('bash', { '-c', 'sleep 0.1' }, {
      on_success = function(close)
        close_callback = close
      end,
    })
    wait_for_new_win(start_winid)
    vim.wait(200)

    close_callback()

    wait_for_win(start_winid)
  end)
end)

---@param cmd string
---@param args string[]?
---@return number
---@return string[]
local run_in_popup = function(cmd, args)
  local start_winid = vim.api.nvim_get_current_win()
  popup.run(cmd, args)
  local winid = wait_for_new_win(start_winid)
  local lines = wait_for_win_lines(winid)
  return winid, lines
end

---@param start_winid number
local quit_popup = function(start_winid)
  vim.api.nvim_set_current_win(start_winid)
  wait_for_win(start_winid)
end

---@param expected_cursor_pos please.cursor.Position
local wait_for_cursor = function(expected_cursor_pos)
  local actual_cursor_pos
  vim.wait(500, function()
    actual_cursor_pos = cursor.get()
    return actual_cursor_pos.row == expected_cursor_pos.row and actual_cursor_pos.col == expected_cursor_pos.col
  end)
  assert.are.same(expected_cursor_pos, actual_cursor_pos, 'incorrect cursor position')
end

describe('restore', function()
  after_each(close_all_windows_but_one)

  it('should show output from closed popup in new window', function()
    local start_winid = vim.api.nvim_get_current_win()
    local popup_winid, popup_lines = run_in_popup('bash', { '-c', 'echo "hello"' })
    quit_popup(start_winid)

    popup.restore()

    local restored_popup_winid = wait_for_new_win(start_winid)
    assert.are_not.equal(
      popup_winid,
      restored_popup_winid,
      'expected popup winid and restored popup winid to be different'
    )
    assert_win_lines(popup_lines, restored_popup_winid)
  end)

  it('should close restored popup when q is pressed', function()
    local start_winid = vim.api.nvim_get_current_win()
    run_in_popup('bash', { '-c', 'echo "hello"' })
    quit_popup(start_winid)

    popup.restore()
    local restored_popup_winid = wait_for_new_win(start_winid)

    vim.api.nvim_feedkeys('q', 'x', false)

    wait_for_win(start_winid)
    assert.is_false(vim.api.nvim_win_is_valid(restored_popup_winid), 'expected restored popup window to not be valid')
  end)

  it('should close restored popup when focus is lost', function()
    local start_winid = vim.api.nvim_get_current_win()
    run_in_popup('bash', { '-c', 'echo "hello"' })
    quit_popup(start_winid)

    popup.restore()
    local restored_popup_winid = wait_for_new_win(start_winid)

    vim.api.nvim_set_current_win(start_winid)

    assert.is_false(vim.api.nvim_win_is_valid(restored_popup_winid), 'expected restored popup window to not be valid')
  end)

  it('should not open popup when previous popup command was not completed', function()
    local start_winid = vim.api.nvim_get_current_win()
    popup.run('bash', { '-c', 'for i in $(seq 1 1000); do echo line $i && sleep 0.1; done' })
    wait_for_new_win(start_winid)
    quit_popup(start_winid)

    popup.restore()

    vim.wait(500)
    local current_winid = vim.api.nvim_get_current_win()
    assert.are.equal(start_winid, current_winid, 'expected current window to be the start window')
  end)

  it("should open restored popup again after it's been closed", function()
    local start_winid = vim.api.nvim_get_current_win()
    local _, popup_lines = run_in_popup('bash', { '-c', 'echo "hello"' })
    quit_popup(start_winid)

    popup.restore()
    wait_for_new_win(start_winid)
    quit_popup(start_winid)

    popup.restore()

    local second_restored_popup_winid = wait_for_new_win(start_winid)
    assert_win_lines(popup_lines, second_restored_popup_winid)
  end)

  it('should restore the cursor position from closed popup', function()
    local expected_cursor_pos = { row = 5, col = 3 }

    local start_winid = vim.api.nvim_get_current_win()
    run_in_popup('bash', { '-c', 'for i in $(seq 1 10); do echo line $i; done' })
    cursor.set(expected_cursor_pos)
    wait_for_cursor(expected_cursor_pos)
    quit_popup(start_winid)

    popup.restore()
    wait_for_new_win(start_winid)

    wait_for_cursor(expected_cursor_pos)
  end)

  it('should restore the cursor position from a previously closed restored popup', function()
    local first_cursor_pos = { row = 5, col = 3 }
    local second_cursor_pos = { row = 7, col = 2 }

    local start_winid = vim.api.nvim_get_current_win()
    run_in_popup('bash', { '-c', 'for i in $(seq 1 10); do echo line $i; done' })
    cursor.set(first_cursor_pos)
    wait_for_cursor(first_cursor_pos)
    quit_popup(start_winid)

    popup.restore()
    wait_for_new_win(start_winid)
    cursor.set(second_cursor_pos)
    quit_popup(start_winid)

    popup.restore()
    wait_for_new_win(start_winid)

    wait_for_cursor(second_cursor_pos)
  end)
end)
