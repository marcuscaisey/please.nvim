# please.nvim
`please.nvim` is a plugin which allows you interact with your Please repository from the comfort of
NeoVim. The aim is to achieve feature parity (and beyond) with [please-vscode](https://github.com/thought-machine/please-vscode)

## Features
Currently implemented features of `please.nvim` are:
- jumping to the build target of the current file (`Please jump_to_target`)
- building (`Please build`)
- testing (`Please test`)
- running specific tests (`Please test under_cursor`)
- running (`Please run`)
- yanking build labels (`Please yank`)
- `please` filetype configured for the following files:
    - `BUILD`
    - `*.plz`
    - `*.build_def`
    - `*.build_defs`
    - `*.build`
- `ini` filetype configured for `.plzconfig` files
- [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) configured to use the
  Python parser so that you get the benefits of treesitter in `please` files (see
  [`nvim-treesitter` configuration](#nvim-treesitter-configuration) for more info)

## Demo
Shown below:
1. Testing the target `:run_test` from `run_test.go` with `<space>pt` (`Please test`)
2. Jumping to the defintion of the target `:run_test` from `run_test.go` with `<space>pj` (`Please jump_to_target`)
3. Testing the target `:run_test` again, this time from the `BUILD` file (`Please test` again)

![please.nvim demo](https://user-images.githubusercontent.com/34950778/169720695-fe5b80d1-7c53-4b3d-ad56-b23c80e48bde.gif)

## Documentation
Detailed documentation can be found in the help file by running `:help please.nvim`.

## Getting started
### Installation
> :information_source: Neovim >= 0.7 is required to use `please.nvim`

Using [vim-plug](https://github.com/junegunn/vim-plug)
```viml
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'nvim-lua/plenary.nvim'
Plug 'marcuscaisey/please.nvim'
```

Using [dein](https://github.com/Shougo/dein.vim)
```viml
call dein#add('nvim-treesitter/nvim-treesitter')
call dein#add('nvim-lua/plenary.nvim')
call dein#add('marcuscaisey/please.nvim')
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
  'marcuscaisey/please.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
}
```

### `nvim-treesitter` configuration
`please.nvim` configures [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) so
that the Python parser is used for files with the `please` filetype. It doesn't, however, configure
anything else to do with [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter), so
it's recommended to at least enable syntax highlighting like so:
```lua
require('nvim-treesitter.configs').setup {
  highlight = {
    enable = true,
  },
}
```

For more information on configuring [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter),
[see here](https://github.com/nvim-treesitter/nvim-treesitter#available-modules).

### Mappings
`please.nvim` doesn't come with any mappings defined out of the box so that you
can customise how you use it. Below are some examples for each command to get
you started.

Lua:
```lua
vim.keymap.set('n', '<leader>pj', require("please").jump_to_target, { silent = true })
vim.keymap.set('n', '<leader>pb', require("please").build, { silent = true })
vim.keymap.set('n', '<leader>pt', require("please").test, { silent = true })
vim.keymap.set('n', '<leader>pct', function()
  require('please').test { under_cursor = true}
end, { silent = true })
vim.keymap.set('n', '<leader>pr', require("please").run, { silent = true })
vim.keymap.set('n', '<leader>py', require("please").yank, { silent = true })
```

VimL:
```vim
nnoremap <leader>pj silent <cmd>Please jump_to_target<cr>
nnoremap <leader>pb silent <cmd>Please build<cr>
nnoremap <leader>pt silent <cmd>Please test<cr>
nnoremap <leader>pct silent <cmd>Please test under_cursor<cr>
nnoremap <leader>pr silent <cmd>Please run<cr>
nnoremap <leader>py silent <cmd>Please yank<cr>
```
