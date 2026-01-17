let g:fold_line_max_level = 0
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
5,6fold
4,7fold
3,8fold
2,9fold
1,10fold
let &fdl = &fdl
1
normal! zo
2
normal! zo
3
normal! zo
4
normal! zo
" vim: set ft=vim :
