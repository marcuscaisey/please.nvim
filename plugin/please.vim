if exists('g:loaded_please')
  finish
endif
let g:loaded_please = 1

command PleaseTest lua require('please').test()
