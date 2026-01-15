setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
2,9fold
10,15fold
10,17fold
18,25fold
1,26fold
let &fdl = &fdl
1
normal! zo
10
normal! zo
10
normal! zc
" vim: set ft=vim :
