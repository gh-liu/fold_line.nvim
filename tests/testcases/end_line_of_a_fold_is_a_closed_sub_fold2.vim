setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
2,6fold
7,10fold
11,16fold
7,16fold
17,21fold
1,22fold
let &fdl = &fdl
1
normal! zo
7
normal! zo
11
normal! zc

keepjumps 12
" vim: set ft=vim :
