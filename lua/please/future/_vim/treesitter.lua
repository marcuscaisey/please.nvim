local api = vim.api

local M = {}

--- Returns the smallest named node at the given position
---
--- NOTE: Calling this on an unparsed tree can yield an invalid node.
--- If the tree is not known to be parsed by, e.g., an active highlighter,
--- parse the tree first via
---
--- ```lua
--- vim.treesitter.get_parser(bufnr):parse(range)
--- ```
---
---@param opts vim.treesitter.get_node.Opts?
---
---@return TSNode | nil Node at the given position
function M.get_node(opts)
  opts = opts or {}

  local bufnr = opts.bufnr

  if not bufnr or bufnr == 0 then
    bufnr = api.nvim_get_current_buf()
  end

  local row, col --- @type integer, integer
  if opts.pos then
    assert(#opts.pos == 2, 'Position must be a (row, col) tuple')
    row, col = opts.pos[1], opts.pos[2]
  else
    assert(
      bufnr == api.nvim_get_current_buf(),
      'Position must be explicitly provided when not using the current buffer'
    )
    local pos = api.nvim_win_get_cursor(0)
    -- Subtract one to account for 1-based row indexing in nvim_win_get_cursor
    row, col = pos[1] - 1, pos[2]
  end

  assert(row >= 0 and col >= 0, 'Invalid position: row and col must be non-negative')

  local ts_range = { row, col, row, col }

  local root_lang_tree = vim.treesitter.get_parser(bufnr, opts.lang)
  if not root_lang_tree then
    return
  end

  return root_lang_tree:named_node_for_range(ts_range, opts)
end

return M
