let g:fold_line_bar_pos_strategy = 'indent'
let w:fold_line_bar_pos_strategy = 'indent'
let b:fold_line_bar_pos_strategy = 'hybrid'
setlocal fdm=expr
function! FoldLinePrecedenceExpr(lnum) abort
  if a:lnum == 1 | return 1 | endif
  if a:lnum == 2 | return 2 | endif
  if a:lnum <= 6 | return 3 | endif
  if a:lnum == 7 | return 2 | endif
  if a:lnum == 8 | return 1 | endif
  return 0
endfunction
setlocal foldexpr=FoldLinePrecedenceExpr(v:lnum)
setlocal fdl=99
setlocal fen
normal! zR
3
" vim: set ft=vim :
