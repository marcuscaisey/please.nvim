---@tag please.nvim

---@brief [[
--- please.nvim is a plugin which allows you interact with your Please repository from the comfort of NeoVim.
---
--- <pre>
--- COMMANDS                                               *please-commands-intro*
--- </pre>
---
--- Commands can be called either through the Lua or the VimL API.
---
--- Lua API~<br>
--- Commands are exported by the `please` module, which can then be called like
--- `require("please").$command_name()`
---
--- For example, jump_to_target can be executed with
--- <code>
---   require("please").jump_to_target()
--- </code>
---
--- VimL API~<br>
--- Commands are called like `:Please $command_name`
---
--- For example, jump_to_target can be executed with
--- <code>
---   :Please jump_to_target
--- </code>
---
--- Available Commands~<br>
--- jump_to_target : jump to the build target of the current file<br>
--- build : build the target of the current file<br>
--- test : test the current file<br>
--- test_under_cursor : run the test under the cursor
---
--- See |please-commands| for more detailed descriptions of each command.
---
--- <pre>
--- MAPPINGS                                                     *please-mappings*
--- </pre>
---
--- please.nvim doesn't come with any mappings defined out of the box so that you can customise how you use it. Below
--- are some examples for each command to get you started.
---
--- Example Mappings~<br>
--- Lua:
--- <code>
---   vim.keymap.set('n', '<leader>pj', require("please").jump_to_target, { silent = true })
---   vim.keymap.set('n', '<leader>pb', require("please").build, { silent = true })
---   vim.keymap.set('n', '<leader>pt', require("please").test, { silent = true })
--- </code>
---
--- VimL:
--- <code>
---   nnoremap <leader>pj silent <cmd>Please jump_to_target<cr>
---   nnoremap <leader>pb silent <cmd>Please build<cr>
---   nnoremap <leader>pt silent <cmd>Please test<cr>
--- </code>
---@brief ]]

local please = require 'please.please'

return {
  jump_to_target = please.jump_to_target,
  build = please.build,
  test = please.test,
  run = please.run,
  test_under_cursor = please.test_under_cursor,
}
