let g:fold_line_bar_pos_strategy = 'indent'
setlocal fdm=manual
setlocal fdl=99
setlocal fen
silent! normal! zE
4,6fold
3,7fold
2,8fold
1,8fold
1
normal! zo
2
normal! zo
3
normal! zo
4
normal! zo
" vim: set ft=vim :
