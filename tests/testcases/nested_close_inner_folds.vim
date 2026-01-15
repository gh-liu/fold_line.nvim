setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
8,9fold
11,13fold
6,13fold
1,13fold
let &fdl = &fdl
1
normal! zo
6
normal! zo
8
normal! zc
11
normal! zc
" vim: set ft=vim :
