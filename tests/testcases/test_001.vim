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
let s:l = 8 - ((7 * winheight(0) + 23) / 47)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 8
normal! 0
" vim: set ft=vim :
