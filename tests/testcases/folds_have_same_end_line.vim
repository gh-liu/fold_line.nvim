setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
1,6fold
1,7fold
1,8fold
1,9fold
1,10fold
let &fdl = &fdl
1
normal! zo
1
normal! zo
1
normal! zo
1
normal! zo
" vim: set ft=vim :
