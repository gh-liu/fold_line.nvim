let g:fold_line_bar_pos_strategy = 'indent'
let w:fold_line_bar_pos_strategy = 'level'
setlocal fdm=manual
setlocal fdl=99
setlocal fen
silent! normal! zE
4,5fold
3,6fold
2,7fold
1,8fold
1
normal! zo
2
normal! zo
3
normal! zo
" vim: set ft=vim :
