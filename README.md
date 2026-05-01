# please.nvim [![CI](https://github.com/marcuscaisey/please.nvim/actions/workflows/ci.yaml/badge.svg)](https://github.com/marcuscaisey/please.nvim/actions/workflows/ci.yaml)

please.nvim is a plugin which enables you to interact with Please repositories from the comfort of
Neovim.

Bug reports and feature requests are welcome. Please open an issue if you find something that does
not work as expected, or if there is a feature you would like to see added.

## Features

<details>
    <summary>Build a target with <code>:Please build</code></summary>
    <p><strong>In Source File</strong></p>
    <img src="https://github.com/user-attachments/assets/6135bd18-23ad-4942-a5ad-556d5e725cd5" />
    <p><strong>In BUILD File</strong></p>
    <img src="https://github.com/user-attachments/assets/fb3fe515-3f69-42ef-8306-1606f9055a22" />
</details>
<details>
    <summary>Run a target with <code>:Please run</code></summary>
    <p><strong>In Source File</strong></p>
    <img src="https://github.com/user-attachments/assets/7b938ad3-a062-4fcb-89e7-97c83fd8518b" />
    <p><strong>In BUILD File</strong></p>
    <img src="https://github.com/user-attachments/assets/33db6101-d42a-4c20-a5d2-806ddf372a14" />
</details>
<details>
    <summary>Test a target with <code>:Please test</code></summary>
    <p><strong>In Source File</strong></p>
    <img src="https://github.com/user-attachments/assets/6e1e26b4-bb89-4a21-90be-c1a1eccc3974" />
    <p><strong>Run Test Under Cursor</strong></p>
    <img src="https://github.com/user-attachments/assets/b9d62253-3d2a-4919-b6ea-323b2235cd6c" />
    <p><strong>In BUILD File</strong></p>
    <img src="https://github.com/user-attachments/assets/49e3f704-50ab-4150-b00b-baab3a364f17" />
</details>
<details>
    <summary>Display test coverage for a target with <code>:Please cover</code></summary>
    <p><strong>In Source File</strong></p>
    <img src="https://github.com/user-attachments/assets/ff9ad8f9-aa2b-40c6-b78c-d8115776415f" />
    <p><strong>Run Test Under Cursor</strong></p>
    <img src="https://github.com/user-attachments/assets/e5370a39-d1ff-4bc5-a6bd-b3f6ea16d489" />
    <p><strong>In BUILD File</strong></p>
    <img src="https://github.com/user-attachments/assets/a6166252-e2a3-4197-be1e-ad84905ec73d" />
</details>
<details>
    <summary>Debug a target with <code>:Please debug</code></summary>
    <p><strong>In Source File</strong></p>
    <img src="https://github.com/user-attachments/assets/208aad09-6390-494d-9596-78981fd33f18" />
    <p><strong>Run Test Under Cursor</strong></p>
    <img src="https://github.com/user-attachments/assets/793c345d-95d4-4b09-bba8-4816bf329a52" />
    <p><strong>In BUILD File</strong></p>
    <img src="https://github.com/user-attachments/assets/2badc06d-a79b-4187-914e-7bfe49e7331e" />
</details>
<details>
    <summary>Run an arbitrary plz command in a popup with <code>:Please command</code>.</summary>
    <img src="https://github.com/user-attachments/assets/449daf89-4a53-475b-b627-b5bc2e19b716" />
</details>
<details>
    <summary>Display history of previous commands and run any of them again with <code>:Please history</code>.</summary>
    <img src="https://github.com/user-attachments/assets/c9d52f74-55f1-41c6-9613-60ff65119b64" />
</details>
<details>
    <summary>Set the profile to use with <code>:Please set_profile</code>.</summary>
    <img src="https://github.com/user-attachments/assets/48e4ec30-c728-42d2-8679-e73651f88371" />
</details>
<details>
    <summary>Jump from a source file to its target's definition with <code>:Please jump_to_target</code>.</summary>
    <img src="https://github.com/user-attachments/assets/2be470e8-e99f-44cd-9767-fcbeac165031" />
</details>
<details>
    <summary>Look up a target by its build label with <code>:Please look_up_target</code>.</summary>
    <p><strong>Provide Label</strong></p>
    <img src="https://github.com/user-attachments/assets/38ab9f84-be3c-439d-9c6d-28c3a5d53ed9" />
    <p><strong>Use Label Under Cursor</strong></p>
    <img src="https://github.com/user-attachments/assets/f019e10c-4cf6-4ad6-8801-c1b36910d584" />
</details>
<details>
    <summary>Yank a target's build label with <code>:Please yank</code>.</summary>
    <p><strong>In Source File</strong></p>
    <img src="https://github.com/user-attachments/assets/b75e9e77-e263-45a2-8909-9c8b8f5b6a2e" />
    <p><strong>In BUILD File</strong></p>
    <img src="https://github.com/user-attachments/assets/62601a8c-c28c-488e-b729-807ebb0fc0e6" />
</details>

- `please` configured as the `'filetype'` for build files: `*.build`, `*.build_defs`, and the build
  file names set as `parse.buildfilename` in `.plzconfig` (defaults to `BUILD` and `BUILD.plz`).
  is configured as `parse.buildfilename` (defaults to `BUILD` and `BUILD.plz`).
- `ini` configured as the `'filetype'` for `.plzconfig` files to enable better syntax highlighting.
- Python tree-sitter parser configured to be used for please files to enable better syntax
  highlighting and use of all tree-sitter features in BUILD files.
- `please` LSP client configured to use `plz tool lps` for `please` files.
- Language servers [gopls](https://go.dev/gopls),
  [golangci-lint-langserver](https://github.com/nametake/golangci-lint-langserver),
  [basedpyright](https://github.com/detachhead/basedpyright), and
  [pyright](https://github.com/microsoft/pyright) configured for use in a Please repository.
- Runs `puku fmt` when a Go file is saved.

## Requirements

please.nvim requires:

- Neovim >= 0.11.0
- [Please](https://please.build)

please.nvim supports the latest two Neovim minor versions. CI tests against the minimum supported
version and the latest patch of each supported minor.

Additional dependencies are required for some features:

- [tree-sitter-go](https://github.com/tree-sitter/tree-sitter-go) enables
  `:Please test under_cursor`, `:Please cover under_cursor`, and `:Please debug under_cursor` in Go
  files.
- [tree-sitter-python](https://github.com/tree-sitter/tree-sitter-python) enables:
  - `:Please test under_cursor`, `:Please cover under_cursor`, and `:Please debug under_cursor` in
    Python files.
  - `:Please jump_to_target` and `:Please look_up_target`.
  - `:Please build`, `:Please run`, `:Please test`, `:Please debug`, and `:Please yank` in BUILD
    files.
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) enables `:Please debug`.

Execute `:checkhealth please` to verify that the required dependencies are available and to see
whether any feature-specific dependencies are missing.

## Getting started

### Quickstart

> [!NOTE]
> These steps require Neovim >= 0.12 to use `vim.pack`.

1. Open a test file in a Please repository.
2. Execute
   `:lua vim.pack.add({ 'https://github.com/marcuscaisey/please.nvim' }, { confirm = false })` to
   install `please.nvim`.
3. Execute `:Please test` to test the target corresponding to the test file in a popup.
4. Execute `:lua vim.pack.del({ 'please.nvim' }, { force = true })` to uninstall `please.nvim`.

### Installation

Install using your favourite plugin manager. See below for snippets for some popular ones.

#### Snippets

##### [vim.pack](https://neovim.io/doc/user/pack/#_plugin-manager)

> [!NOTE]
> Requires Neovim >= 0.12.

```lua
vim.pack.add({
    {
        src = 'https://github.com/marcuscaisey/please.nvim',
        version = vim.version.range('1.*'), -- Use for stability; omit to use master branch for the latest features
    },
})
```

##### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    'marcuscaisey/please.nvim',
    version = '1.*', -- Use for stability; omit to use master branch for the latest features
}
```

#### Recommended additional plugins

- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) - Tree-sitter configurations
  and abstraction layer for Neovim. This enables you to install tree-sitter parsers.
- [fzf-lua](https://github.com/ibhagwan/fzf-lua) - Highly extendable fuzzy finder. This provides a
  good `vim.ui.select` implementation.
- [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) - UI for nvim-dap.

## Documentation

See [doc/please.txt](doc/please.txt) or execute `:help please.nvim`.
