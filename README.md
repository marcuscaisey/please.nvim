# please.nvim
please.nvim is a plugin which allows you interact with your Please repository from the comfort of
NeoVim. The aim is to achieve feature parity (and beyond) with [please-vscode](https://github.com/thought-machine/please-vscode)

## Features
Currently implemented features of please.nvim are:
- jump to the build target which uses the current file (`:Please jump_to_target`)

## Getting started
### Installation

Using [vim-plug](https://github.com/junegunn/vim-plug)
```viml
Plug 'nvim-lua/plenary.nvim'
Plug 'marcuscaisey/please.nvim'
```

Using [dein](https://github.com/Shougo/dein.vim)
```viml
call dein#add('nvim-lua/plenary.nvim')
call dein#add('marcuscaisey/please.nvim')
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
  'marcuscaisey/please.nvim',
  requires = 'nvim-lua/plenary.nvim',
}
```

### Mappings
please.nvim doesn't come with any mappings defined out of the box so that you
can customise how you use it. Below are some examples for each command to get
you started.

Lua:
```lua
vim.keymap.set('n', '<leader>pj', require("please").jump_to_target, { silent = true })
```

VimL:
```viml
nnoremap <leader>pj silent <cmd>Please jump_to_target<cr>
```

### Documentation
Detailed documentation can be found in the help file by running `:help please.nvim`.
