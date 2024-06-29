local api = vim.api
local ns = api.nvim_create_namespace("FoldLine")

api.nvim_set_hl(0, "FoldLine", { default = true, link = "Folded" })

local ffi = require("ffi")
ffi.cdef([[
	typedef struct {} Error;
	typedef struct {} win_T;
	typedef struct {
		int start;  // line number where deepest fold starts
		int level;  // fold level, when zero other fields are invalid
		int llevel; // lowest level that starts in v:lnum
		int lines;  // number of lines from v:lnum to end of closed fold
	} foldinfo_T;
	foldinfo_T fold_info(win_T* wp, int lnum);
	win_T *find_window_by_handle(int Window, Error *err);
]])

---@alias FoldInfo {start:number, level:number, llevel:number, lines:number}
---@param win integer
---@param lnum integer
---@return FoldInfo|?
local get_fold_info = function(win, lnum)
	local wp = ffi.C.find_window_by_handle(win, ffi.new("Error"))
	local foldinfo = ffi.C.fold_info(wp, lnum)
	return { start = foldinfo.start, level = foldinfo.level, llevel = foldinfo.llevel, lines = foldinfo.lines } ---@type FoldInfo
end

local config = {
	virt_text_pos = "overlay",
	hl_mode = "combine",
	ephemeral = true,
}

local chars = vim.opt.fillchars:get()
local fold_signs = {
	f_top_close = vim.g.fold_line_char_top_close or chars.foldclose or "+",
	f_close = vim.g.fold_line_char_close or chars.vertright or "├",
	f_sep = vim.g.fold_line_char_open_sep or chars.foldsep or "│",
	f_open = vim.g.fold_line_char_open_start or "┌",
	f_end = vim.g.fold_line_char_open_end or "└",
}

-- TODO: all fold signs must have same display winth
local border_shift = 0 - vim.fn.strdisplaywidth(fold_signs.f_top_close)

---@param winid integer
---@param bufnr integer
---@param toprow integer
---@param botrow integer
local function on_win(_, winid, bufnr, toprow, botrow)
	if not vim.wo[winid].foldenable then
		return
	end
	if bufnr ~= api.nvim_win_get_buf(winid) then
		return
	end
	if vim.g.fold_line_disable or vim.w[winid].fold_line_disable or vim.b[bufnr].fold_line_disable then
		return
	end
	if toprow == 0 and botrow == 0 then
		return
	end

	api.nvim_win_set_hl_ns(winid, ns)

	config.virt_text = { { "", "FoldLine" } }

	local get_indent
	get_indent = (function()
		local indent_cache = {}
		return function(win, buf, l)
			if not indent_cache[l] then
				api.nvim_win_call(win, function()
					local last_line = api.nvim_buf_line_count(buf)
					for line = 1, last_line do
						if l == vim.fn.foldlevel(line) then
							indent_cache[l] = vim.fn.indent(line)
						end
					end
				end)
			end
			return indent_cache[l] or (l - 1 > 0 and get_indent(win, buf, l - 1)) or 0
		end
	end)()

	local last_line = api.nvim_buf_line_count(bufnr)
	local row = toprow
	while row <= botrow do
		local skip_rows
		local line = row + 1
		local foldinfo = get_fold_info(winid, line)
		if foldinfo then
			local cur_level = foldinfo.level
			if cur_level > 0 then
				-- local line_before = (line - 1) >= 1 and line - 1 or 1
				-- local foldinfo_before = get_fold_info(winid, line_before)
				local line_after = (line + 1) <= last_line and (line + 1) or last_line
				local foldinfo_after = get_fold_info(winid, line_after)
				local after_level = foldinfo_after.level
				local after_start = foldinfo_after.start

				local closed = foldinfo.lines > 0
				local first_level = 1
				local closedcol = cur_level
				local range = cur_level
				for col = 1, range do
					local sign
					if closedcol == 1 and closed then
						sign = fold_signs.f_top_close
						skip_rows = foldinfo.lines
					end
					if col == closedcol - 1 and closed then
						sign = fold_signs.f_close
						skip_rows = foldinfo.lines
					end
					if line == 1 then
						sign = fold_signs.f_open
					end
					if line == last_line then
						sign = fold_signs.f_end
					end
					if col == closedcol and (foldinfo.start == line and first_level + col >= foldinfo.llevel) then
						sign = fold_signs.f_open
						if closed then
							sign = ""
						end
					end
					if col == closedcol then
						-- 1. same level but not same start line
						if cur_level == after_level and foldinfo.start < after_start then
							sign = fold_signs.f_end
						end
						-- 2. not same level
						-- 2.1 the fold of after line include current fold of current line or no intersection
						if cur_level > after_level then
							sign = fold_signs.f_end
						end
						-- 2.2 TODO the fold of current line and the fold of after line have no intersection
						-- if cur_level < foldinfo_after.level then
						-- end
					else
						if cur_level > after_level then
							-- if col > after_level then
							-- 	sign = fold_signs.f_end
							-- end
							if col == after_level and after_start == line_after then
								sign = fold_signs.f_end
							end
						end
					end

					if not sign then
						sign = fold_signs.f_sep
					end

					local indent
					local indent_start = vim.fn.indent(foldinfo.start)
					local col2 = col
					while true do
						indent = get_indent(winid, bufnr, col2)
						if indent <= indent_start then
							break
						end
						col2 = col2 - 1
						if col2 == 0 then
							indent = 0
							break
						end
					end

					local leftcol = vim.fn.winsaveview().leftcol
					indent = indent - leftcol

					if indent >= 0 then
						config.virt_text[1][1] = sign
						config.virt_text_win_col = indent + border_shift
						api.nvim_buf_set_extmark(bufnr, ns, row, 0, config)
					end
				end
			end
		end
		row = row + (skip_rows or 1)
	end
end

api.nvim_set_decoration_provider(ns, { on_win = on_win })
