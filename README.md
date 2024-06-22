# fold_line.nvim

Lines, not for indentation, but for folding.

## install

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
