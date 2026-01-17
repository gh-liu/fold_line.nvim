setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
setlocal nowrap
silent! normal! zE
4,5fold
3,6fold
2,7fold
1,8fold
let &fdl = &fdl
1
normal! zo
2
normal! zo
3
normal! zo
normal! 10zl
" vim: set ft=vim :
