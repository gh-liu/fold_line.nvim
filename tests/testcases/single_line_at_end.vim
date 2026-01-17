setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
3,3fold
2,4fold
1,5fold
6,6fold
let &fdl = &fdl
1
normal! zo
2
normal! zo
" vim: set ft=vim :
