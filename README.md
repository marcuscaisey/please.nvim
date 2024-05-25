# please.nvim [![CI](https://github.com/marcuscaisey/please.nvim/actions/workflows/ci.yaml/badge.svg)](https://github.com/marcuscaisey/please.nvim/actions/workflows/ci.yaml)
please.nvim is a plugin which allows you interact with your Please repository from the comfort of Neovim. The aim is to remove the need to switch from your editor to the shell when performing routine actions.

## Features
  * Build, run, test, and debug a target
  * Yank a target's label
  * Jump from a source file to its build target definition
  * Display history of previous commands and run any of them again
  * `please` configured as the `filetype` for `BUILD`, `BUILD.plz`, and `*.build_defs` files
  * `ini` configured as the `filetype` for `.plzconfig` files to enable better syntax highlighting
  * Python tree-sitter parser configured to be used for please files to enable better syntax
    highlighting and use of all treesitter features in build files

## Demo
https://user-images.githubusercontent.com/34950778/205456279-665ddfe8-de77-4f36-a337-85768bb06a37.mov

Shown above:
1. Testing the target `//gopkg:test` from `gopkg/gopkg_test.go` with `<space>pt` (`require('please').test()`)
2. Jumping to the defintion of the target `//gopkg:test` from `gopkg/gopkg_test.go` with `<space>pj` (`require('please').jump_to_target()`)
3. Testing the target `//gopkg:test` again, this time from the `BUILD` file (`require('please').test()` again)

## Documentation
Detailed documentation can be in [doc/please.txt](doc/please.txt) or by running `:help please.nvim`.

## Getting started
### Installation
> :information_source: Neovim >= 0.10 is required to use please.nvim

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use({
  'marcuscaisey/please.nvim',
  requires = {
    'mfussenegger/nvim-dap',
  },
})
```

Using [vim-plug](https://github.com/junegunn/vim-plug)
```viml
Plug 'mfussenegger/nvim-dap'
Plug 'marcuscaisey/please.nvim'
```

Using [dein](https://github.com/Shougo/dein.vim)
```viml
call dein#add('mfussenegger/nvim-dap')
call dein#add('marcuscaisey/please.nvim')
```

#### Recommended additional plugins
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - excellent fuzzy finder
- [dressing.nvim](https://github.com/stevearc/dressing.nvim) - pairs with telescope.nvim to
  provide a nice popup for inputs (`vim.ui.input`) and selections (`vim.ui.select`)
- [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) - provides a UI for nvim-dap

### `nvim-treesitter` configuration
`please.nvim` configures the Python tree-sitter parser to be used for please files. It doesn't,
however, configure anything else to do with
[`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter), so it's recommended to at
least enable syntax highlighting like so:
```lua
require('nvim-treesitter.configs').setup({
  highlight = {
    enable = true,
  },
})
```

For more information on configuring [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter),
[see here](https://github.com/nvim-treesitter/nvim-treesitter#available-modules).
