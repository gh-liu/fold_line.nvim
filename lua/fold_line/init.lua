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

local chars = vim.opt.fillchars:get()
local fold_signs = {
	f_top_close = vim.g.fold_line_char_top_close or chars.foldclose or "+",
	f_close = vim.g.fold_line_char_close or chars.vertright or "├",
	f_sep = vim.g.fold_line_char_open_sep or chars.foldsep or "│",
	f_open = vim.g.fold_line_char_open_start or "┌",
	f_end = vim.g.fold_line_char_open_end or "└",
}

-- TODO: all fold signs must have same display width
local border_shift = 0 - vim.fn.strdisplaywidth(fold_signs.f_top_close)

local config = {
	virt_text_pos = "overlay",
	hl_mode = "combine",
	ephemeral = true,
}

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

	local foldinfos = {}
	setmetatable(foldinfos, {
		__index = function(infos, line)
			local foldinfo = get_fold_info(winid, line)
			rawset(infos, line, foldinfo)
			return foldinfo
		end,
	})

	local get_indent_by_level
	get_indent_by_level = (function()
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
			return indent_cache[l] or (l - 1 > 0 and get_indent_by_level(win, buf, l - 1)) or 0
		end
	end)()

	local leftcol = vim.fn.winsaveview().leftcol

	local last_line = api.nvim_buf_line_count(bufnr)
	for row = toprow, botrow do
		local cur_line = row + 1
		local foldinfo = foldinfos[cur_line]
		if foldinfo then
			local cur_line_level = foldinfo.level
			if cur_line_level > 0 then
				local line_before = (cur_line - 1) >= 1 and cur_line - 1 or 1
				local foldinfo_prev = foldinfos[line_before]
				local prev_level = foldinfo_prev.level
				local prev_start = foldinfo_prev.start

				local line_next = (cur_line + 1) <= last_line and (cur_line + 1) or last_line
				local foldinfo_next = foldinfos[line_next]
				local next_level = foldinfo_next.level
				local next_start = foldinfo_next.start

				local closed = foldinfo.lines > 0
				local first_level = 1
				for level = 1, cur_line_level do
					-- current: ## |  # | # | #  | ##
					-- next:    #  | #  | # |  # |  #

					local sign
					-- close sign
					if (cur_line_level - 1) == level and closed then
						sign = fold_signs.f_close
					end
					if cur_line_level == 1 and closed then
						sign = fold_signs.f_top_close
					end

					-- open sign
					if not sign then
						if cur_line == 1 then
							sign = fold_signs.f_open
						end
						if foldinfo.start == cur_line then
							if level == cur_line_level then
								sign = fold_signs.f_open
							end

							if (prev_level < cur_line_level) and (prev_level < level and level <= cur_line_level) then
								sign = fold_signs.f_open
							end

							-- if (before_level == cur_line_level) and true then
							-- 	sign = fold_signs.f_open
							-- end
						end
						if closed then
							sign = ""
						end
					end

					-- end sign
					if not sign then
						if cur_line == last_line then
							sign = fold_signs.f_end
						end
						if level == cur_line_level then
							-- 1. same level but not same start line
							if cur_line_level == next_level and foldinfo.start < next_start then
								sign = fold_signs.f_end
							end
							-- 2. not same level
							-- 2.1 the fold of after line include current fold of current line or no intersection
							-- 2.2 TODO the fold of current line and the fold of after line have no intersection
							-- if cur_level < foldinfo_after.level then
							-- end
							-- else
							-- 	if cur_line_level > after_level then
							-- 		-- if col > after_level then
							-- 		-- 	sign = fold_signs.f_end
							-- 		-- end
							-- 		if level == after_level and after_start == line_after then
							-- 			sign = fold_signs.f_end
							-- 		end
							-- 	end
						end

						if cur_line_level > next_level then
							if next_level < level and level <= cur_line_level then
								sign = fold_signs.f_end
							end
						end
					end

					if not sign then
						sign = fold_signs.f_sep
					end

					local indent
					-- indent of start line
					local indent_start = vim.fn.indent(foldinfo.start)
					local level_copy = level
					while true do
						-- indent of a level
						indent = get_indent_by_level(winid, bufnr, level_copy)
						-- if the indent of this level less than or equl to the indent or start line, use this indent
						if indent <= indent_start then
							break
						else
							-- fallback to prev level
							level_copy = level_copy - 1
						end
						-- can not find a indent, so use 0 indent
						if level_copy == 0 then
							indent = 0
							break
						end
					end
					indent = indent - leftcol

					if indent >= 0 then
						config.virt_text[1][1] = sign
						config.virt_text_win_col = indent + border_shift
						api.nvim_buf_set_extmark(bufnr, ns, row, 0, config)
					end
				end
			end
		end
	end
end

api.nvim_set_decoration_provider(ns, { on_win = on_win })
