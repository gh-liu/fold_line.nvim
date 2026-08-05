set laststatus=0 noruler noshowcmd
setlocal fdm=manual
setlocal fdl=99
setlocal fen
silent! normal! zE
3,6fold
1,8fold
normal! zR
vsplit
3
normal! zc
wincmd w
normal! zR
4
" vim: set ft=vim :
