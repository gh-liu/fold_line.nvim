setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
6,7fold
5,8fold
4,9fold
3,10fold
2,11fold
1,12fold
let &fdl = &fdl
1
normal! zM
" vim: set ft=vim :
