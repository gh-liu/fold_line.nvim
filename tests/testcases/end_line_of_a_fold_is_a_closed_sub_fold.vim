setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
3,9fold
2,9fold
1,10fold
let &fdl = &fdl
1
normal! zo
2
normal! zo
3
normal! zc
keepjumps 3
" vim: set ft=vim :
