setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
5,10fold
4,10fold
3,10fold
2,10fold
1,10fold
let &fdl = &fdl
1
normal! zo
2
normal! zo
3
normal! zo
4
normal! zo
let s:l = 5 - ((4 * winheight(0) + 23) / 47)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 5
normal! 0
" vim: set ft=vim :
