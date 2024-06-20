local M = {}

---@class tests.temptree.Tree
---@field [number] string
---@field [string] string | tests.temptree.Tree

---@param path string
local function mkdir(path)
  local current_path = path:match('^/') and '/' or ''
  for component in path:gmatch('[^/]+') do
    if current_path == '' then
      current_path = component
    else
      current_path = vim.fs.joinpath(current_path, component)
    end
    local success, err, err_name = vim.uv.fs_mkdir(current_path, 448) -- 448 = 0o700
    assert(success or err_name == 'EEXIST', err)
  end
end

---@param s string
---@return string
local function dedent(s)
  local lines = vim.split(s, '\n')
  local min_indent = math.huge
  for _, line in ipairs(lines) do
    local indent = line:match('^%s*')
    if indent ~= line then
      min_indent = math.min(min_indent, #indent)
    end
  end
  local dedented_lines = {}
  for _, line in ipairs(lines) do
    table.insert(dedented_lines, line:sub(min_indent + 1))
  end
  return table.concat(dedented_lines, '\n')
end

---@param root string
---@param tree tests.temptree.Tree | string
---@param contents string | nil
local function create_file_tree(root, tree, contents)
  if type(tree) == 'string' then
    local path_tail = tree
    if path_tail:match('/$') then
      local dir_path = vim.fs.joinpath(root, path_tail)
      mkdir(dir_path)
      if contents then
        create_file_tree(dir_path, contents)
      end
    else
      local file_path = vim.fs.joinpath(root, path_tail)
      local f = assert(io.open(file_path, 'w'))
      contents = dedent(contents or '')
      assert(f:write(contents))
      assert(f:close())
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

---@return string
local function make_temp_dir()
  local tempname = vim.fn.tempname()
  assert(vim.uv.fs_mkdir(tempname, 448)) -- 448 = 0o700
  return tempname
end

---Creates a file tree in a directory in the Neovim [tempdir]. When Neovim exits, the [tempdir] and all its contents
---will be deleted so you don't have to worry about cleaning up any directories or files created by this function.
---The tree should be provided as a table in the following format:
---```lua
---{
---  'empty_file',
---  ['file'] = 'contents',
---  'empty_dir/',
---  ['dir/'] = {
---    'another_empty_file',
---    ['another_file'] = 'more contents',
---  },
---}
---```
---Elements of the tree are either:
---  - string values representing an empty file or directory to be created, depending on whether the string ends in / or
---    not
---  - key value pairs where again the key is a string representing a file or directory to be created and the value is
---    either the contents to write to the file or the file tree to create in the directory
---File contents are written with common leading whitespace removed.
---@param tree tests.temptree.Tree
---@return string root: root of the created file tree
function M.create(tree)
  local temp_dir = make_temp_dir()
  create_file_tree(temp_dir, tree)
  -- resolve to remove any symlinks (on macOS /tmp is linked to /private/tmp)
  return vim.fn.resolve(temp_dir)
end

return M
