let g:fold_line_bar_pos_strategy = 'indent'
setlocal fdm=expr
function! FoldExpr(lnum) abort
  if a:lnum == 1 | return 1 | endif
  if a:lnum == 2 | return 2 | endif
  if a:lnum == 3 | return 3 | endif
  if a:lnum <= 6 | return 3 | endif
  if a:lnum == 7 | return 2 | endif
  if a:lnum == 8 | return 1 | endif
  return 0
endfunction
setlocal foldexpr=FoldExpr(v:lnum)
setlocal fdl=99
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
let &fdl = &fdl
normal! zM
" 展开到 3 层
1
normal! zo
2
normal! zo
3
normal! zo
" vim: set ft=vim :
