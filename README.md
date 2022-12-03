# please.nvim
please.nvim is a plugin which allows you interact with your Please repository from the comfort of Neovim. The aim is to remove the need to switch from your editor to the shell when performing routine actions.

## Features
  * Build, run, test, and debug a target
  * Yank a target's label
  * Jump from a source file to its build target definition
  * Display history of previous actions and run any of them again
  * `please` configured as the `filetype` for the following files:
    * `BUILD`
    * `*.plz`
    * `*.build_def`
    * `*.build_defs`
    * `*.build`
    * `ini` configured as the `filetype` for `.plzconfig` files to enable better syntax highlighting
    * `nvim-treesitter` configured to use the Python parser for `please` files to enable better syntax highlighting and use of all treesitter features in build files

## Getting started
### Installation
> :information_source: Neovim >= 0.8 is required to use please.nvim

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use({
  'marcuscaisey/please.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'mfussenegger/nvim-dap',
  },
})
```

Using [vim-plug](https://github.com/junegunn/vim-plug)
```viml
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'nvim-lua/plenary.nvim'
Plug 'mfussenegger/nvim-dap'
Plug 'marcuscaisey/please.nvim'
```

Using [dein](https://github.com/Shougo/dein.vim)
```viml
call dein#add('nvim-treesitter/nvim-treesitter')
call dein#add('nvim-lua/plenary.nvim')
call dein#add('mfussenegger/nvim-dap')
call dein#add('marcuscaisey/please.nvim')
```

#### Recommended additional plugins
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - excellent fuzzy finder
- [dressing.nvim](https://github.com/stevearc/dressing.nvim) - pairs with telescope.nvim to
  provide a nice popup for inputs (`vim.ui.input`) and selections (`vim.ui.select`)
- [nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text) - embeds variable
  values as virtual text
- [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) - provides a UI for nvim-dap

### Documentation
Detailed documentation can be in [doc/please.txt](doc/please.txt) or by running `:help please.nvim`.

### `nvim-treesitter` configuration
`please.nvim` configures [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) so
that the Python parser is used for files with the `please` filetype. It doesn't, however, configure
anything else to do with [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter), so
it's recommended to at least enable syntax highlighting like so:
```lua
require('nvim-treesitter.configs').setup({
  highlight = {
    enable = true,
  },
})
```

For more information on configuring [`nvim-treesitter`](https://github.com/nvim-treesitter/nvim-treesitter),
[see here](https://github.com/nvim-treesitter/nvim-treesitter#available-modules).
