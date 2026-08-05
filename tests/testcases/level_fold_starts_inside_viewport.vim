let g:fold_line_bar_pos_strategy = 'level'
setlocal fdm=manual
setlocal fdl=99
setlocal fen
silent! normal! zE
5,11fold
4,12fold
4
normal! zo
5
normal! zo
6
" vim: set ft=vim :
