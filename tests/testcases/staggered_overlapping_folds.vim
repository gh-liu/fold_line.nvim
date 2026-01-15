setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
5,7fold
4,7fold
8,9fold
3,10fold
2,11fold
1,12fold
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
