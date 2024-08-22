setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
5,9fold
4,9fold
11,15fold
10,17fold
4,17fold
3,18fold
1,19fold
let &fdl = &fdl
1
normal! zo
3
normal! zo
4
normal! zo
4
normal! zo
10
normal! zo

keepjumps 4
" vim: set ft=vim :
