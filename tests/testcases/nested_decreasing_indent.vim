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
let &fdl = &fdl
1
normal! zo
2
normal! zc
" vim: set ft=vim :
