let b:fold_line_bar_pos_strategy = 'level'
let g:fold_line_bar_pos_strategy = 'indent'
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
1
normal! zo
2
normal! zo
3
normal! zo
" vim: set ft=vim :
