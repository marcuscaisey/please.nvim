# please.nvim [![CI](https://github.com/marcuscaisey/please.nvim/actions/workflows/ci.yaml/badge.svg)](https://github.com/marcuscaisey/please.nvim/actions/workflows/ci.yaml)

please.nvim is a plugin which enables you to interact with your Please repository from the comfort
of Neovim.

## Features

- Build, run, test, and debug a target with `:Please build`, `:Please run`, `:Please test`, and
  `:Please debug`.
- Run an arbitrary plz command in a popup with `:Please command`.
- Display history of previous commands and run any of them again with `:Please history`.
- Set the profile to use with `:Please set_profile`.
- Jump from a source file to its target's definition with `:Please jump_to_target`.
- Look up a target by its build label with `:Please look_up_target`.
- Yank a target's build label with `:Please yank`.
- `please` configured as the `'filetype'` for `BUILD`, `BUILD.plz`, `*.build`, and `*.build_defs`
  files.
- `ini` configured as the `'filetype'` for `.plzconfig` files to enable better syntax highlighting.
- Python tree-sitter parser configured to be used for please files to enable better syntax
  highlighting and use of all tree-sitter features in build files.
- `please` LSP client configured to use `plz tool lps` for `please` files.
- Language servers [gopls](https://go.dev/gopls),
  [golangci-lint-langserver](https://github.com/nametake/golangci-lint-langserver),
  [basedpyright](https://github.com/detachhead/basedpyright), and
  [pyright](https://github.com/microsoft/pyright) automatically configured for use in a Please
  repository.

## Demo

https://user-images.githubusercontent.com/34950778/205456279-665ddfe8-de77-4f36-a337-85768bb06a37.mov

Shown above:

1. Testing the target `//gopkg:test` from `gopkg/gopkg_test.go` with `<space>pt` (`:Please test`)
2. Jumping to the defintion of the target `//gopkg:test` from `gopkg/gopkg_test.go` with `<space>pj`
   (`:Please jump_to_target`)
3. Testing the target `//gopkg:test` again, this time from the `BUILD` file (`:Please test` again)

## Getting started

### Quickstart

> [!NOTE]
> These steps require Neovim >= 0.12.

1. Open a test file in a Please repository.
2. Execute
   `:lua vim.pack.add({ 'https://github.com/marcuscaisey/please.nvim' }, { confirm = false })` to
   install `please.nvim`.
3. Execute `:Please test` to test the target corresponding to the test file in a popup.
4. Execute `:lua vim.pack.del({ 'please.nvim' }, { force = true })` to uninstall `please.nvim`.

### Installation

> [!NOTE]
> please.nvim supports the latest two Neovim minor versions.
> CI tests against the minimum supported version and the latest patch of each supported minor.
> The current minimum supported version is 0.11.0.

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
  and abstraction layer for Neovim. This enables you to install tree-sitter parsers.
- [fzf-lua](https://github.com/ibhagwan/fzf-lua) - Highly extendable fuzzy finder. This provides a
  good `vim.ui.select` implementation.
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) - Debug Adapter Protocol client
  implementation for Neovim. **This is required to use `:Please debug`.**
- [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) - UI for nvim-dap.

## Documentation

Detailed documentation can found be in [doc/please.txt](doc/please.txt) or by executing
`:help please.nvim`.
