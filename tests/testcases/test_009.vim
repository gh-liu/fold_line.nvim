setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
2,4fold
5,8fold
2,8fold
13,14fold
16,17fold
12,19fold
1,20fold
let &fdl = &fdl
1
normal! zo
2
normal! zo
2
normal! zc
5
normal! zc
12

keepjumps 2
" vim: set ft=vim :
