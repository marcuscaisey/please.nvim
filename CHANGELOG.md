# Changelog

## [1.1.1](https://github.com/marcuscaisey/please.nvim/compare/v1.1.0...v1.1.1) (2026-05-01)


### Bug Fixes

* error if :Please cover or :Please test run with a non-test target ([eeb38d4](https://github.com/marcuscaisey/please.nvim/commit/eeb38d4428d9b1fc24a6dc2307e68e9e78d713b0)), closes [#139](https://github.com/marcuscaisey/please.nvim/issues/139)

## [1.1.0](https://github.com/marcuscaisey/please.nvim/compare/v1.0.0...v1.1.0) (2026-05-01)


### Features

* add :Please cover ([7f1cf56](https://github.com/marcuscaisey/please.nvim/commit/7f1cf56e1152c7a5d11fa6ca8e9b93b7741620da)), closes [#66](https://github.com/marcuscaisey/please.nvim/issues/66)
* add healthcheck ([9050363](https://github.com/marcuscaisey/please.nvim/commit/905036375e7191a32b328bfbcf2edb1db8942c35)), closes [#10](https://github.com/marcuscaisey/please.nvim/issues/10)
* **go:** run puku fmt on saved file if puku_command configured ([022e0c0](https://github.com/marcuscaisey/please.nvim/commit/022e0c00b94f428627cc17ab553aa4a59e85e65b)), closes [#82](https://github.com/marcuscaisey/please.nvim/issues/82)
* **history:** log when history successfully cleared ([ba0d8fb](https://github.com/marcuscaisey/please.nvim/commit/ba0d8fb12548b0192c3e603afd63bfe9ad2b39ca))
* **lsp:** enable opt out of auto config with please.setup ([c375ae0](https://github.com/marcuscaisey/please.nvim/commit/c375ae00bad350c6b801a294f89e09570031e8ac)), closes [#106](https://github.com/marcuscaisey/please.nvim/issues/106)
* respect parse.buildfilename .plzconfig setting ([19c68ae](https://github.com/marcuscaisey/please.nvim/commit/19c68aed032f0497d25283a11433a1e574411203)), closes [#135](https://github.com/marcuscaisey/please.nvim/issues/135)
* **setup:** move flat options into nested objects ([8c3142f](https://github.com/marcuscaisey/please.nvim/commit/8c3142ffc724a12df39a327fd29b9b364a14c161))


### Bug Fixes

* ensure that created autocmds fail gracefully ([6787051](https://github.com/marcuscaisey/please.nvim/commit/6787051d289ebcde17d62fc37c25b73095d399e4))
* **logging:** don't include lazily required modules in debug output ([2f2c529](https://github.com/marcuscaisey/please.nvim/commit/2f2c5295949bcce540153a1e093cb5168109967c))
* **maximise_popup:** no-op if popup is already maximised ([84aaa9a](https://github.com/marcuscaisey/please.nvim/commit/84aaa9a0f5f6c186bb2dfaebaf1a95de5307a043))
* only set filetype for *.build and *.build_defs files in a plz repo ([46aedee](https://github.com/marcuscaisey/please.nvim/commit/46aedee2092535d4aa207deb05d141fb63131dcd))
* **popup:** ensure cursor position is saved before closing popup ([f9d1197](https://github.com/marcuscaisey/please.nvim/commit/f9d1197b256fbfd69bcd453c8794708710a6d36b))
* **popup:** only save previous cursor position when popup is closed ([11980a7](https://github.com/marcuscaisey/please.nvim/commit/11980a7e1d932102afacbb6aca5219cc810ecf22))
* set filetype for *.build and *.build_defs files in please cache ([4db904b](https://github.com/marcuscaisey/please.nvim/commit/4db904bdb8bb20448f8e3e304b0f37cc7934168b))
* **setup:** override existing config instead of updating it ([9fcbd86](https://github.com/marcuscaisey/please.nvim/commit/9fcbd86b49eb951cd31d840d50644d7a36c673a9))

## [1.0.0](https://github.com/marcuscaisey/please.nvim/compare/v1.0.0...v1.0.0) (2026-04-20)


### Miscellaneous Chores

* release 1.0.0 ([8e03c29](https://github.com/marcuscaisey/please.nvim/commit/8e03c29a661f06bd9edfb317b8690b14fb1ab329))
