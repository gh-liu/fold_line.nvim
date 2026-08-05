let g:fold_line_bar_pos_strategy = 'indent'
setlocal fdm=manual
setlocal fdl=99
setlocal fen
setlocal nowrap
silent! normal! zE
2,6fold
1,7fold
normal! zR
3
normal! 5zl
" vim: set ft=vim :
