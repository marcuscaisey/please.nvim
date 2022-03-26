if exists('g:loaded_please')
  finish
endif
let g:loaded_please = 1

command -nargs=1 Please lua require('please.command').run_command(<f-args>)
