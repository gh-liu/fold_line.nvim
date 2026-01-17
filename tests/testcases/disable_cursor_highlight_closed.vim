let g:fold_line_disable_cursor_highlight = v:true
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
4,5fold
3,6fold
2,7fold
1,8fold
let &fdl = &fdl
" 关闭最内层 fold
3
normal! zc
" 光标在 closed fold 上
3
" vim: set ft=vim :
