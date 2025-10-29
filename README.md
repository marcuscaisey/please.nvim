# please.nvim [![CI](https://github.com/marcuscaisey/please.nvim/actions/workflows/ci.yaml/badge.svg)](https://github.com/marcuscaisey/please.nvim/actions/workflows/ci.yaml)
please.nvim is a plugin which allows you interact with your Please repository from the comfort of Neovim. The aim is to remove the need to switch from your editor to the shell when performing routine actions.

## Features
  * Build, run, test, and debug a target with `please.build()`, `please.run()`, `please.test()`, and
    `please.debug()`.
  * Display history of previous commands and run any of them again with `please.history()`.
  * Set the profile to use with `please.set_profile()`.
  * Jump from a source file to its build target definition with `please.jump_to_target()`.
  * Look up a build target by its label with `please.look_up_target()`.
  * Yank a target's label with `please.yank()`.
  * `please` configured as the `filetype` for `BUILD`, `BUILD.plz`, `*.build`, and `*.build_defs`
    files.
  * `ini` configured as the `filetype` for `.plzconfig` files to enable better syntax highlighting.
  * `please` LSP client configured to use `plz tool lps` for `please` files.
  * [gopls](https://go.dev/gopls) language server configured to use appropriate `GOROOT` when
    started in a Please respository.
  * Python tree-sitter parser configured to be used for please files to enable better syntax
    highlighting and use of all tree-sitter features in build files.

## Demo
https://user-images.githubusercontent.com/34950778/205456279-665ddfe8-de77-4f36-a337-85768bb06a37.mov

Shown above:
1. Testing the target `//gopkg:test` from `gopkg/gopkg_test.go` with `<space>pt` (`please.test()`)
2. Jumping to the defintion of the target `//gopkg:test` from `gopkg/gopkg_test.go` with `<space>pj` (`please.jump_to_target()`)
3. Testing the target `//gopkg:test` again, this time from the `BUILD` file (`please.test()` again)

## Documentation
Detailed documentation can be in [doc/please.txt](doc/please.txt) or by running `:help please.nvim`.

## Getting started
### Installation
> :information_source: Neovim >= 0.11.1 is required to use please.nvim

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use({ 'marcuscaisey/please.nvim' })
```

Using [vim-plug](https://github.com/junegunn/vim-plug)
```viml
Plug 'marcuscaisey/please.nvim'
```

Using [dein](https://github.com/Shougo/dein.vim)
```viml
call dein#add('marcuscaisey/please.nvim')
```

#### Recommended additional plugins
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) - Tree-sitter configurations
  and abstraction layer for Neovim.
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - Highly extendable fuzzy
  finder.
- [dressing.nvim](https://github.com/stevearc/dressing.nvim) - Pairs with telescope.nvim to
  provide a nice popup for inputs (`vim.ui.input`) and selections (`vim.ui.select`).
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) - Debug Adapter Protocol client
  implementation for Neovim. **This is required to use `please.debug()`.**
- [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) - UI for nvim-dap.

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
