let g:fold_line_profile = v:true
setlocal fdm=manual
setlocal fdl=99
setlocal fen
silent! normal! zE
2,6fold
1,6fold
normal! zM
1
normal! zo
" vim: set ft=vim :
