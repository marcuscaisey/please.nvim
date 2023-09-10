local strings = require('plenary.strings')
local Path = require('plenary.path')

local M = {}

local function create_file_tree(root, tree, contents)
  if type(tree) == 'string' then
    local path_tail = tree
    if path_tail:match('/$') then
      local dir_path = Path:new(root, path_tail)
      dir_path:mkdir()
      if contents then
        create_file_tree(dir_path, contents)
      end
    else
      local file_path = Path:new(root, path_tail)
      file_path:touch()
      if contents then
        -- remove trailing empty lines
        -- this needs to be done before dedenting otherwise the blank line will count as leading whitespace
        contents = contents:match('^(.+\n?)%s*$')
        -- remove common leading whitespace
        contents = strings.dedent(contents)
        file_path:write(strings.dedent(contents), 'w')
      end
    end
    return
  end

  for k, v in pairs(tree) do
    -- k is a number if the element of the table was just a string i.e. { 'a', 'b', 'c' } and is a string (the key) if
    -- it's part of a key value pair like { a = 1, b = 2 }
    if type(k) == 'number' then
      local path_tail = v
      create_file_tree(root, path_tail)
    else
      local path_tail = k
      local tree_file_contents = v
      create_file_tree(root, path_tail, tree_file_contents)
    end
  end
end

local function get_temp_dir()
  -- tmpname gives us an OS agnostic way of getting a unique file in the temporary directory. We want a temporary
  -- directory though, so we'll delete the temporary file and create a temporary directory with the same name.
  local temp_dir = Path:new(os.tmpname())
  temp_dir:rm()
  temp_dir:mkdir()
  return temp_dir
end

---Creates a file tree in a temporary directory. The tree should be provided as a table in the following format:
---@param tree table: the file tree to create provided in the following format:
---{
---  'empty_file',
---  ['file'] = 'contents',
---  'empty_dir/',
---  ['dir/'] = {
---    'another_empty_file',
---    ['another_file'] = 'more contents',
---  },
---}
---elements of the tree are either:
---- string values representing an empty file or directory to be created, depending on whether the string ends in / or
---not
---- key value pairs where again the key is a string representing a file or directory to be created and the value is
---either the contents to write to the file or the file tree to create in the directory
---File contents are written with common leading whitespace and blank final lines removed.
---@return string: the root of the temporary file tree
---@return function: a function which tears down the file tree when called
function M.create(tree)
  local temp_dir = get_temp_dir()
  create_file_tree(temp_dir, tree)
  local function teardown_func()
    temp_dir:rm({ recursive = true })
  end
  -- resolve to remove any symlinks (on macOS /tmp is linked to /private/tmp)
  return vim.fn.resolve(temp_dir.filename), teardown_func
end

return M
