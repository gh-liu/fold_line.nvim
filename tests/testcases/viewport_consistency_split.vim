set laststatus=0 noruler noshowcmd
let g:fold_line_bar_pos_strategy = 'indent'
setlocal fdm=manual
setlocal fdl=99
setlocal fen
silent! normal! zE
2,10fold
11,29fold
1,30fold
normal! zR
vsplit
15
normal! zt
wincmd w
1
normal! zt
" vim: set ft=vim :
