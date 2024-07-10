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

---@alias FoldInfo {start:number, level:number, llevel:number, lines:number, start_indent:number}
---@param win integer
---@param lnum integer
---@return FoldInfo|?
local get_fold_info = function(win, lnum)
	local wp = ffi.C.find_window_by_handle(win, ffi.new("Error"))
	local foldinfo = ffi.C.fold_info(wp, lnum)
	return {
		start = foldinfo.start,
		level = foldinfo.level,
		llevel = foldinfo.llevel,
		lines = foldinfo.lines,
		start_indent = vim.fn.indent(foldinfo.start), -- indent of start line
	} ---@type FoldInfo
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
	virt_text = { { "", "FoldLine" } },
}

---@param winid integer
---@param bufnr integer
---@param toprow integer
---@param botrow integer
local function on_win(_, winid, bufnr, toprow, botrow)
	if
		not vim.wo[winid].foldenable
		or bufnr ~= api.nvim_win_get_buf(winid)
		or vim.g.fold_line_disable
		or vim.w[winid].fold_line_disable
		or vim.b[bufnr].fold_line_disable
		or (toprow - botrow == 0)
	then
		return
	end

	api.nvim_win_set_hl_ns(winid, ns)

	local leftcol = vim.fn.winsaveview().leftcol
	local last_line = api.nvim_buf_line_count(bufnr)

	local level_indents = {} ---@type table<integer,integer>
	setmetatable(level_indents, {
		__index = function(indents, level)
			local indent = api.nvim_win_call(winid, function()
				for line = 1, last_line do
					if level == vim.fn.foldlevel(line) then
						return vim.fn.indent(line)
					end
				end
			end)
			if indent then
				rawset(indents, level, indent)
			end
			return indent
		end,
	})

	local foldinfos = {} ---@type FoldInfo[]
	setmetatable(foldinfos, {
		__index = function(infos, line)
			local foldinfo = get_fold_info(winid, line)
			rawset(infos, line, foldinfo)
			return foldinfo
		end,
	})

	--- get indent of a level with fallback
	---@param level integer
	---@param start_indent integer
	---@return integer
	local indent_fallback = function(level, start_indent)
		local indent = 0
		while true do
			indent = level_indents[level]
			if indent and (indent <= start_indent) then
				-- if the indent of this level less than or equl to the indent of start line, use it
				break
			else
				-- fallback to prev level
				level = level - 1
			end
			if level == 0 then
				indent = 0
				break
			end
		end
		return indent
	end

	--- check if in i_level is a close_sign
	---@param i_level integer
	---@param cur_line_finfo FoldInfo
	---@return string|nil
	local close_sign = function(i_level, cur_line_finfo)
		local cur_line_flevel = cur_line_finfo.level

		if (cur_line_flevel - 1) == i_level then
			return fold_signs.f_close
		end
		if cur_line_flevel == 1 then
			return fold_signs.f_top_close
		end
	end

	--- check if in i_level is a open_start_sign
	---@param i_level integer
	---@param cur_line integer
	---@param cur_line_finfo FoldInfo
	---@param prev_line_finfo FoldInfo
	---@return string|nil
	local open_start_sign = function(i_level, cur_line, cur_line_finfo, prev_line_finfo)
		-- if the 1st line in a fold, it's must the start of the folds
		if cur_line == 1 then
			return fold_signs.f_open
		end

		local cur_line_fstart = cur_line_finfo.start

		local sign
		if cur_line == cur_line_fstart then
			local cur_line_flevel = cur_line_finfo.level

			local prev_line_flevel = prev_line_finfo.level
			-- local prev_line_fstart = prev_line_finfo.start

			local is_closed = cur_line_finfo.lines > 0

			if i_level == cur_line_flevel then
				sign = fold_signs.f_open
			else
				if prev_line_flevel < i_level and i_level < cur_line_flevel then
					sign = fold_signs.f_open
				end

				-- if (prev_line_flevel == cur_line_flevel) and true then
				-- 	sign = fold_signs.f_open
				-- end

				-- if (prev_line_flevel > cur_line_flevel) and true then
				-- 	sign = fold_signs.f_open
				-- end
			end

			sign = (is_closed and sign) and "" or sign
		end
		return sign
	end

	--- check if in i_level is a open_end_sign
	---@param i_level integer
	---@param cur_line integer
	---@param cur_line_finfo FoldInfo
	---@param next_line_finfo FoldInfo
	---@return string|nil
	local open_end_sign = function(i_level, cur_line, cur_line_finfo, next_line_finfo)
		-- if the last line in a fold, it's must the end of the folds
		if cur_line == last_line then
			return fold_signs.f_end
		end

		local cur_line_fstart = cur_line_finfo.start
		local cur_line_flevel = cur_line_finfo.level

		local next_line_flevel = next_line_finfo.level
		local next_line_fstart = next_line_finfo.start

		local sign
		if i_level == cur_line_flevel then
			-- 1. same level but not same start line
			if cur_line_flevel == next_line_flevel and cur_line_fstart < next_line_fstart then
				sign = fold_signs.f_end
			end
			-- 2. not same level
			-- 2.1 the fold of after line include current fold of current line or no intersection
			-- 2.2 TODO the fold of current line and the fold of after line have no intersection
			-- if cur_line_flevel < next_line_flevel then
			-- end
			-- else
			-- 	if cur_line_flevel > next_line_flevel then
			-- 		-- if col > after_level then
			-- 		-- 	sign = fold_signs.f_end
			-- 		-- end
			-- 		if i_level == next_line_flevel and next_line_fstart == cur_line + 1 then
			-- 			sign = fold_signs.f_end
			-- 		end
			-- 	end
		end

		if next_line_flevel < cur_line_flevel then
			if next_line_flevel < i_level and i_level <= cur_line_flevel then
				sign = fold_signs.f_end
			end
			if (next_line_fstart == cur_line + 1) and (i_level == next_line_flevel) then
				sign = fold_signs.f_end
			end
		end
		return sign
	end

	local row = toprow
	while row <= botrow do
		local skip_rows
		local cur_line = row + 1
		local cur_line_finfo = foldinfos[cur_line]
		if cur_line_finfo then
			local cur_line_flevel = cur_line_finfo.level
			if cur_line_flevel > 0 then
				-- local cur_line_fstart = cur_line_finfo.start
				local cur_line_fstartindent = cur_line_finfo.start_indent

				local prev_line = (cur_line - 1) >= 1 and cur_line - 1 or 1
				local prev_line_finfo = foldinfos[prev_line]

				local next_line = (cur_line + 1) <= last_line and (cur_line + 1) or last_line
				local next_line_finfo = foldinfos[next_line]

				-- TODO: try from the deepest to the outermost level
				-- for i_level = cur_line_flevel, 1, -1 do

				local is_closed = cur_line_finfo.lines > 0

				for i_level = 1, cur_line_flevel do
					local indent = indent_fallback(i_level, cur_line_fstartindent) - leftcol
					if indent >= 0 then
						local sign = is_closed and close_sign(i_level, cur_line_finfo)
						if sign then
							skip_rows = cur_line_finfo.lines
						end
						sign = sign or open_start_sign(i_level, cur_line, cur_line_finfo, prev_line_finfo)
						sign = sign or open_end_sign(i_level, cur_line, cur_line_finfo, next_line_finfo)
						sign = sign or fold_signs.f_sep

						if sign ~= "" then
							config.virt_text[1][1] = sign
							config.virt_text_win_col = indent + border_shift
							api.nvim_buf_set_extmark(bufnr, ns, row, 0, config)
						end
					end
				end
			end
		end
		row = row + (skip_rows or 1)
	end
end

api.nvim_set_decoration_provider(ns, { on_win = on_win })
