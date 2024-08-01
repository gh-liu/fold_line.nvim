local api = vim.api
local ns = api.nvim_create_namespace("FoldLine")

local priority = vim.g.fold_line_char_priority or 100

api.nvim_set_hl(0, "FoldLine", { default = true, link = "Folded" })
api.nvim_set_hl(0, "FoldLineCurrent", { default = true, link = "CursorLineFold" })

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
	f_open_start_close = vim.g.fold_line_char_open_start_close or "╒",
	f_open_end_close = vim.g.fold_line_char_open_end_close or "╘",
}

-- TODO: all fold signs must have same display width
local border_shift = 0 - vim.fn.strdisplaywidth(fold_signs.f_top_close)

local config = {
	virt_text_pos = "overlay",
	hl_mode = "combine",
	ephemeral = true,
	virt_text = { { "", "" } },
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

	api.nvim_win_call(winid, function()
		api.nvim_win_set_hl_ns(winid, ns)

		local leftcol = vim.fn.winsaveview().leftcol
		local last_line = api.nvim_buf_line_count(bufnr)

		local foldinfos = {} ---@type FoldInfo[]
		setmetatable(foldinfos, {
			__index = function(infos, line)
				local foldinfo = get_fold_info(winid, line)
				rawset(infos, line, foldinfo)
				return foldinfo
			end,
		})

		local flevel_indents = {} ---@type table<integer,integer>

		local function save_fold_indent(cur_line_finfo)
			local cur_line_flevel = cur_line_finfo.level
			local cur_line_fstartindent = cur_line_finfo.start_indent
			flevel_indents[cur_line_flevel] = cur_line_fstartindent

			local cur_line_fllevel = cur_line_finfo.llevel
			if cur_line_fllevel < cur_line_flevel then
				local unit = cur_line_fstartindent / (cur_line_flevel + 1)
				for i_level = cur_line_fllevel, cur_line_flevel - 1 do
					flevel_indents[i_level] = math.ceil(i_level * unit)
				end
			end
		end

		--- get indent of a level with fallback
		---@param level integer
		---@param cur_line_finfo FoldInfo
		---@param cur_line integer
		---@return integer
		local flevel_indent = function(level, cur_line_finfo, cur_line)
			if cur_line == cur_line_finfo.start then
				save_fold_indent(cur_line_finfo)
			end
			return flevel_indents[level] or 0
		end

		-- local cur_line = toprow + 1
		local foldinfo = foldinfos[toprow + 1]
		while foldinfo.level > 0 do
			save_fold_indent(foldinfo)
			foldinfo = foldinfos[foldinfo.start - 1]
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
				local cur_line_fllevel = cur_line_finfo.llevel

				local is_closed = cur_line_finfo.lines > 0

				if cur_line_fllevel <= i_level and i_level <= cur_line_flevel then
					sign = fold_signs.f_open
				end

				sign = (is_closed and sign) and "" or sign
			end
			return sign
		end

		local fold_end_infos = {}
		setmetatable(fold_end_infos, {
			__index = function(t, k)
				rawset(t, k, {})
				return t[k]
			end,
		})

		local save_fold_end_line = function(cur_line, i_level, fold_info)
			while i_level < fold_info.level do
				fold_info = foldinfos[fold_info.start - 1]
			end
			-- if end line already exist, just return
			if fold_end_infos[fold_info.start][i_level] then
				return
			end
			if i_level == fold_info.level then
				fold_end_infos[fold_info.start][i_level] = cur_line
			end
		end

		--- check if in i_level is a open_end_sign
		---@param i_level integer
		---@param cur_line integer
		---@param cur_line_finfo FoldInfo
		---@param next_line_finfo FoldInfo
		---@return string|nil
		local open_end_sign = function(i_level, cur_line, cur_line_finfo, next_line_finfo)
			local cur_line_fstart = cur_line_finfo.start
			-- if the last line in a fold, it's must the end of the folds
			if cur_line == last_line then
				save_fold_end_line(cur_line, i_level, cur_line_finfo)
				return fold_signs.f_end
			end

			local cur_line_flevel = cur_line_finfo.level
			-- local cur_line_fllevel = cur_line_finfo.llevel

			local next_line_flevel = next_line_finfo.level
			local next_line_fllevel = next_line_finfo.llevel
			local next_line_fstart = next_line_finfo.start

			local sign

			if next_line_flevel < cur_line_flevel then
				local start = next_line_flevel + 1
				if next_line_fstart == cur_line + 1 then -- next line is start line of a fold
					start = next_line_fllevel
				end
				if start <= i_level and i_level <= cur_line_flevel then
					sign = fold_signs.f_end
				end
			end

			-- same level but not same fold
			if next_line_flevel == cur_line_flevel and (cur_line_fstart < next_line_fstart) then
				if next_line_fllevel <= i_level and i_level <= next_line_flevel then
					sign = fold_signs.f_end
				end
			end

			if next_line_flevel > cur_line_flevel then
				if next_line_fllevel <= i_level and i_level <= cur_line_flevel then
					sign = fold_signs.f_end
				end
			end
			if sign then
				save_fold_end_line(cur_line, i_level, cur_line_finfo)
			end

			return sign
		end

		local cursor_line = vim.fn.line(".")
		local cursor_line_finfo = foldinfos[cursor_line]
		local cursor_line_flevel = cursor_line_finfo.level
		local cursor_line_fstart = cursor_line_finfo.start
		local is_cursor_fold_closed = cursor_line_finfo.lines > 0

		local cursor_fold_top
		if is_cursor_fold_closed then
			local fold_info = cursor_line_finfo
			while fold_info.level >= cursor_line_flevel do
				fold_info = foldinfos[fold_info.start - 1]
			end
			cursor_fold_top = fold_info.start
		end

		---@param i_level integer
		---@param cur_line_finfo FoldInfo
		---@param cur_line integer
		local cursor_fold_closed = function(i_level, cur_line_finfo, cur_line)
			if i_level == cursor_line_flevel - 1 then
				local cur_line_fstart = cur_line_finfo.start
				local cur_line_flevel = cur_line_finfo.level

				if cursor_fold_top <= cur_line_fstart then
					local fold_end_line = fold_end_infos[cursor_fold_top][i_level]
					if not fold_end_line then
						if (cur_line_fstart <= cursor_line_fstart) or (cur_line_flevel >= cursor_line_flevel) then
							return true
						end
					else
						if fold_end_line == cur_line then
							return true
						end
					end
				end
			end
		end

		---@param i_level integer
		---@param cur_line_finfo FoldInfo
		---@param cur_line integer
		---@return boolean
		local cursor_fold = function(i_level, cur_line_finfo, cur_line)
			local cur_line_flevel = cur_line_finfo.level
			local cur_line_fstart = cur_line_finfo.start

			if
				i_level == cur_line_flevel
				and cur_line_flevel == cursor_line_flevel
				and cur_line_fstart == cursor_line_fstart
			then
				return true
			end

			if i_level == cursor_line_flevel then
				local fold_end_line = fold_end_infos[cursor_line_fstart][i_level]
				if not fold_end_line then
					if cursor_line_flevel < cur_line_flevel and cursor_line_fstart <= cur_line_fstart then
						return true
					end
				else
					if fold_end_line == cur_line then
						return true
					end
				end
			end

			return false
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
					-- local cur_line_fstartindent = cur_line_finfo.start_indent

					local prev_line = (cur_line - 1) >= 1 and cur_line - 1 or 1
					local prev_line_finfo = foldinfos[prev_line]

					local next_line = (cur_line + 1) <= last_line and (cur_line + 1) or last_line
					local next_line_finfo = foldinfos[next_line]

					-- TODO: try from the deepest to the outermost level
					-- for i_level = cur_line_flevel, 1, -1 do

					local is_closed = cur_line_finfo.lines > 0

					for i_level = 1, cur_line_flevel do
						local indent = flevel_indent(i_level, cur_line_finfo, cur_line)
						indent = indent - leftcol

						if indent >= 0 then
							local sign = is_closed and close_sign(i_level, cur_line_finfo)
							if sign then
								fold_end_infos[cur_line_finfo.start][i_level] = cur_line + cur_line_finfo.lines
								skip_rows = cur_line_finfo.lines

								if sign == fold_signs.f_close then
									local above_line_finfo = foldinfos[cur_line_finfo.start - 1]
									if above_line_finfo.level < cur_line_finfo.level - 1 then
										sign = fold_signs.f_open_start_close
									end

									local below_line = cur_line_finfo.start + cur_line_finfo.lines
									local below_line_finfo = foldinfos[below_line]
									if below_line_finfo.level < cur_line_finfo.level - 1 then
										sign = fold_signs.f_open_end_close
									end
								end
							end
							sign = sign or open_start_sign(i_level, cur_line, cur_line_finfo, prev_line_finfo)
							sign = sign or open_end_sign(i_level, cur_line, cur_line_finfo, next_line_finfo)
							sign = sign or fold_signs.f_sep

							if sign ~= "" then
								local is_cursor_fold = false
								if

									(not is_cursor_fold_closed and cursor_fold(i_level, cur_line_finfo, cur_line))
									or (is_cursor_fold_closed and cursor_fold_closed(i_level, cur_line_finfo, cur_line))
								then
									config.virt_text[1][2] = "FoldLineCurrent"
									config.priority = priority + 1
									is_cursor_fold = true
								else
									config.virt_text[1][2] = "FoldLine"
									config.priority = priority
								end

								if
									not vim.g.fold_line_current_fold_only
									or (vim.g.fold_line_current_fold_only and is_cursor_fold)
								then
									config.virt_text[1][1] = sign
									config.virt_text_win_col = indent + border_shift
									api.nvim_buf_set_extmark(bufnr, ns, row, 0, config)
								end
							end
						end
					end
				end
			end
			row = row + (skip_rows or 1)
		end
	end)
end

api.nvim_set_decoration_provider(ns, { on_win = on_win })
