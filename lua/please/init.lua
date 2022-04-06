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
--- `require("please").$command_name(<args>)`
---
--- For example, jump_to_target can be executed with
--- <code>
---   require("please").jump_to_target()
--- </code>
---
--- VimL API~<br>
--- Commands are called like `:Please $command_name <args>`
---
--- For example, jump_to_target can be executed with
--- <code>
---   :Please jump_to_target
--- </code>
---
--- Available Commands~<br>
--- jump_to_target : jump to the build target which uses the current file<br>
--- build_target : build the target which uses the current file<br>
--- test_target : test the target which uses the current file
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
---   vim.keymap.set('n', '<leader>pb', require("please").build_target, { silent = true })
---   vim.keymap.set('n', '<leader>pt', require("please").test_target, { silent = true })
--- </code>
---
--- VimL:
--- <code>
---   nnoremap <leader>pj silent <cmd>Please jump_to_target<cr>
---   nnoremap <leader>pb silent <cmd>Please build_target<cr>
---   nnoremap <leader>pt silent <cmd>Please test_target<cr>
--- </code>
---@brief ]]

local please = require 'please.please'

return {
  jump_to_target = please.jump_to_target,
  build_target = please.build_target,
  test_target = please.test_target,
}
