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
6,7fold
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
normal! zc
6
normal! zc
" vim: set ft=vim :
