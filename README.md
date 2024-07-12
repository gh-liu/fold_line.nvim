# fold_line.nvim

Lines, not for indentation, but for folding.

## Screenshots

<img width="960" alt="fold_line" src="https://github.com/user-attachments/assets/88ab809b-0de2-43df-b23a-e9dee7c0d30e">

The line of the current fold is yellow. You can change the color by setting the `FoldLineCurrent` highlight group.
<img width="960" alt="hi_current" src="https://github.com/user-attachments/assets/0fd67967-5dac-439d-9230-cc6538064e9e">


## Install

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- init.lua:
{
    "gh-liu/fold_line.nvim",
    event = "VeryLazy",
    init = function()
        -- change the char of the line, see the `Appearance` section
        vim.g.fold_line_char_open_start = "╭"
        vim.g.fold_line_char_open_end = "╰"
    end,
}
```

## Appearance

Use the highlight group `FoldLine` to change the color of the line. Per default it links to `Folded`.
And use the highlight group `FoldLineCurrent` to change the color of the line of current fold. Per default it links to `CursorLineFold`.

change the char of the line:
```lua
vim.g.fold_line_char_top_close = "+"  -- default: fillchars.foldclose or "+"
vim.g.fold_line_char_close = "├"      -- default: fillchars.vertright or "├"
vim.g.fold_line_char_open_sep = "│"   -- default: fillchars.foldsep or "│"
vim.g.fold_line_char_open_start = "╭" -- default: "┌"
vim.g.fold_line_char_open_end = "╰"   -- default: "└"
```

## Disabling

Set `vim.g.fold_line_disable` (globally) or `vim.w.fold_line_disable` (for a window) or `vim.b.fold_line_disable` (for a buffer) to `true`.
