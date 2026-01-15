setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
3,4fold
2,7fold
8,11fold
2,11fold
15,17fold
14,20fold
1,21fold
let &fdl = &fdl
1
normal! zo
2
normal! zo
2
normal! zo
2
normal! zc
14
normal! zo

keepjumps 2
" vim: set ft=vim :
