setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
2,3fold
1,4fold
6,7fold
5,8fold
10,10fold
9,11fold
let &fdl = &fdl
1
normal! zo
5
normal! zo
9
normal! zo
" vim: set ft=vim :
