local api = vim.api
local ns = api.nvim_create_namespace("FoldLine")

api.nvim_set_hl(0, "FoldLine", { default = true, link = "Folded" })
api.nvim_set_hl(0, "FoldLineCurrent", { default = true, link = "CursorLineFold" })

local config = require("fold_line.config").build()
local ffi = require("fold_line.ffi")
local render = require("fold_line.render")

local on_win = render.create_on_win({
	ns = ns,
	config = config,
	get_fold_info = ffi.get_fold_info,
	find_window_by_handle = ffi.find_window_by_handle,
})

api.nvim_set_decoration_provider(ns, { on_win = on_win })
