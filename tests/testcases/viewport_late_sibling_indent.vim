let g:fold_line_profile = v:true
let g:fold_line_bar_pos_strategy = 'indent'
setlocal fdm=manual
setlocal fdl=99
setlocal fen
silent! normal! zE
2,10fold
11,29fold
1,30fold
1
normal! zo
11
normal! zo
15
normal! zt
" vim: set ft=vim :
