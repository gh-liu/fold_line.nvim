setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
1,1fold
4,10fold
3,10fold
let &fdl = &fdl
1
normal! zc
3
normal! zo

keepjumps 1
" vim: set ft=vim :
