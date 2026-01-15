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
6,8fold
6,10fold
3,11fold
2,12fold
1,13fold
let &fdl = &fdl
1
normal! zo
2
normal! zo
3
normal! zo
6
normal! zo
6
normal! zc
" vim: set ft=vim :
