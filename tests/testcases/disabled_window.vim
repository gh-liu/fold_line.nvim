let w:fold_line_disable = v:true

setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
1,4fold
let &fdl = &fdl
1
normal! zo
" vim: set ft=vim :
