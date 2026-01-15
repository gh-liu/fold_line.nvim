setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
7,11fold
5,11fold
2,11fold
1,12fold
let &fdl = &fdl
1
normal! zo
2
normal! zo
5
normal! zo
7
normal! zc
" vim: set ft=vim :
