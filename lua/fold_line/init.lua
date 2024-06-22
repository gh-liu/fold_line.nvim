local api = vim.api
local ns = api.nvim_create_namespace("FoldLine")

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
	f_top_close = chars.foldclose or "+",
	f_close = chars.vertright or "├",
	f_sep = chars.foldsep or "│",
	f_open = "┌",
	f_end = "└",
}

-- TODO: all fold signs must have same display winth
local border_shift = 0 - vim.fn.strdisplaywidth(fold_signs.f_top_close)

---@param bufnr integer
---@param line integer
---@return integer
local function get_indent_of_line(bufnr, line)
	local folded_lines = api.nvim_buf_get_lines(0, line - 1, line, false)
	if #folded_lines == 0 then
		return 0
	end
	local blank_chars = folded_lines[1]:match("^%s+") or ""
	return #(blank_chars:gsub("\t", string.rep(" ", vim.bo[bufnr].tabstop)))
end

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
	if toprow == 0 and botrow == 0 then
		return
	end

	api.nvim_win_set_hl_ns(winid, ns)

	config.virt_text = { { "", "Folded" } }

	local indent_cache = {}
	local last_line = api.nvim_buf_line_count(bufnr)
	for row = toprow, botrow do
		local line = row + 1
		local sign = fold_signs.f_sep
		local foldinfo = get_fold_info(winid, line)
		if foldinfo then
			local level = foldinfo.level
			if level > 0 then
				local line_before = (line - 1) >= 1 and line - 1 or 1
				local line_after = (line + 1) <= last_line and (line + 1) or last_line
				local foldinfo_before = get_fold_info(winid, line_before)
				local foldinfo_after = get_fold_info(winid, line_after)

				if not indent_cache[foldinfo.start] then
					indent_cache[level] = get_indent_of_line(bufnr, foldinfo.start)
				end

				for l = 1, level, 1 do
					local indent = indent_cache[l] or 0
					config.virt_text_win_col = indent + border_shift
					if l == level then
						if foldinfo_before and foldinfo.start > foldinfo_before.start or line == 1 then
							sign = fold_signs.f_open
						end
						if foldinfo_after then
							if foldinfo.start > foldinfo_after.start or line == last_line then
								sign = fold_signs.f_end
							end

							if foldinfo.level == foldinfo_after.level and foldinfo.start < foldinfo_after.start then
								sign = fold_signs.f_end
							end
						end
						if foldinfo_before and foldinfo_after then
							-- ignore the fold of a single line
							if
								foldinfo_before.level == foldinfo_after.level
								and foldinfo_after.level < foldinfo.level
							then
								sign = ""
							end
						end
					end

					local closed = foldinfo.lines > 0
					if closed then
						if l == level - 1 then
							sign = fold_signs.f_close
						end
						if l == level then
							sign = ""
							if l == 1 then
								sign = fold_signs.f_top_close
							end
						end
					end

					config.virt_text[1][1] = sign
					api.nvim_buf_set_extmark(bufnr, ns, row, 0, config)
				end
			end
		end
	end
end

api.nvim_set_decoration_provider(ns, { on_win = on_win })
