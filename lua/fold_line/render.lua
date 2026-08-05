local M = {}

local api = vim.api
local empty_fold_info = {
	start = 0,
	level = 0,
	llevel = 0,
	lines = 0,
	start_indent = 0,
}

---@param opts table
---@return fun(_, winid:integer, bufnr:integer, toprow:integer, botrow:integer)
function M.create_on_win(opts)
	local ns = opts.ns
	local config = opts.config
	local fold_signs = config.fold_signs
	local priority = config.priority
	local border_shift = config.border_shift
	local sign_width = config.sign_width or 1
	local extmark_config = config.extmark_config

	local get_fold_info = opts.get_fold_info
	local find_window_by_handle = opts.find_window_by_handle

	return function(_, winid, bufnr, toprow, botrow)
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
			local set_hl_ns = api.nvim_win_set_hl_ns
			local set_extmark = api.nvim_buf_set_extmark
			local virt_text = extmark_config.virt_text[1]
			set_hl_ns(winid, ns)

			local fn = vim.fn
			local leftcol = fn.winsaveview().leftcol
			local last_line = api.nvim_buf_line_count(bufnr)
			local current_fold_only = vim.g.fold_line_current_fold_only == true
			local bar_pos_strategy = vim.b[bufnr].fold_line_bar_pos_strategy
				or vim.w[winid].fold_line_bar_pos_strategy
				or vim.g.fold_line_bar_pos_strategy
			if bar_pos_strategy == nil then
				bar_pos_strategy = "hybrid"
			end
			if bar_pos_strategy ~= "indent" and bar_pos_strategy ~= "level" and bar_pos_strategy ~= "hybrid" then
				bar_pos_strategy = "hybrid"
			end

			-- Keep the strategy stable across redraws: hybrid only uses level spacing
			-- for fold methods whose levels are not derived from indentation.
			local foldmethod = vim.wo[winid].foldmethod
			local force_level_spaced = (bar_pos_strategy == "level")
				or (bar_pos_strategy == "hybrid" and (foldmethod == "expr" or foldmethod == "syntax"))

			local max_level = tonumber(vim.g.fold_line_max_level)
			if max_level ~= nil and max_level < 1 then
				max_level = nil
			end
			local disable_cursor_highlight = vim.g.fold_line_disable_cursor_highlight == true
			local f_top_close = fold_signs.f_top_close
			local f_close = fold_signs.f_close
			local f_sep = fold_signs.f_sep
			local f_open = fold_signs.f_open
			local f_end = fold_signs.f_end
			local f_open_start_close = fold_signs.f_open_start_close
			local f_open_end_close = fold_signs.f_open_end_close

			local wp = find_window_by_handle(winid)
			local indent_cache = {} ---@type table<integer, integer>
			local foldinfos = {} ---@type FoldInfo[]
			local profile_enabled = vim.g.fold_line_profile == true
			local profile_start_ns
			local foldinfo_calls = 0
			local extmark_calls = 0
			local ancestor_hops = 0
			local out_of_bounds_foldinfo_requests = 0
			if profile_enabled then
				local uv = vim.uv or vim.loop
				profile_start_ns = uv.hrtime()
			end
			setmetatable(foldinfos, {
				__index = function(infos, line)
					if line < 1 or line > last_line then
						out_of_bounds_foldinfo_requests = out_of_bounds_foldinfo_requests + 1
						return empty_fold_info
					end
					if profile_enabled then
						foldinfo_calls = foldinfo_calls + 1
					end
					local foldinfo = get_fold_info(wp, line, indent_cache)
					rawset(infos, line, foldinfo)
					return foldinfo
				end,
			})

			local flevel_indents = {} ---@type table<integer,integer>
			local indent_clamp_count = 0
			local indent_bad_growth_count = 0
			local indent_sample_count = 0
			local use_level_spaced = force_level_spaced

			local function save_fold_indent(cur_line_finfo)
				local cur_line_flevel = cur_line_finfo.level
				local cur_line_fllevel = cur_line_finfo.llevel
				local cur_line_fstartindent = cur_line_finfo.start_indent
				flevel_indents[cur_line_flevel] = cur_line_fstartindent

				if cur_line_fllevel < cur_line_flevel then
					local parent_level = cur_line_fllevel - 1
					local parent_indent = flevel_indents[parent_level]
					if parent_indent == nil and cur_line_finfo.start > 1 then
						local parent = foldinfos[cur_line_finfo.start - 1]
						if parent and parent.level > 0 then
							parent_indent = parent.start_indent
						end
					end

					parent_indent = parent_indent or 0
					local delta = (cur_line_fstartindent - parent_indent)
					local denom = (cur_line_flevel - parent_level)
					local unit = delta / denom
					indent_sample_count = indent_sample_count + 1
					if delta < denom then
						indent_bad_growth_count = indent_bad_growth_count + 1
					end
					if unit < 1 then
						unit = 1
						indent_clamp_count = indent_clamp_count + 1
					end
					for i_level = cur_line_fllevel, cur_line_flevel - 1 do
						flevel_indents[i_level] = parent_indent + math.ceil((i_level - parent_level) * unit)
					end
				end
			end

			--- get indent of a level with fallback
			---@param level integer
			---@return integer
			local flevel_indent = function(level)
				return flevel_indents[level] or 0
			end

			local function warmup_fold_indents()
				local foldinfo = foldinfos[toprow + 1]
				local ancestry = {}
				local seen_starts = {}
				while foldinfo.level > 0 and not seen_starts[foldinfo.start] do
					ancestry[#ancestry + 1] = foldinfo
					seen_starts[foldinfo.start] = true
					if foldinfo.start <= 1 then
						break
					end
					ancestor_hops = ancestor_hops + 1
					foldinfo = foldinfos[foldinfo.start - 1]
				end

				-- Replay from the outermost fold towards the fold at the top of the
				-- viewport. A preceding sibling can then never overwrite the active one.
				for i = #ancestry, 1, -1 do
					save_fold_indent(ancestry[i])
				end
			end

			warmup_fold_indents()

			--- check if in i_level is a close_sign
			---@param i_level integer
			---@param cur_line_finfo FoldInfo
			---@return string|nil
			local close_sign = function(i_level, cur_line_finfo)
				local cur_line_flevel = cur_line_finfo.level

				if (cur_line_flevel - 1) == i_level then
					return f_close
				end
				if cur_line_flevel == 1 then
					return f_top_close
				end
			end

			--- check if in i_level is a open_start_sign
			---@param i_level integer
			---@param cur_line integer
			---@param cur_line_finfo FoldInfo
			---@param prev_line_finfo FoldInfo
			---@return string|nil
			local open_start_sign = function(i_level, cur_line, cur_line_finfo)
				-- if the 1st line in a fold, it's must the start of the folds
				if cur_line == 1 then
					return f_open
				end

				local cur_line_fstart = cur_line_finfo.start

				local sign
				if cur_line == cur_line_fstart then
					local cur_line_flevel = cur_line_finfo.level
					local cur_line_fllevel = cur_line_finfo.llevel

					local is_closed = cur_line_finfo.lines > 0

					if cur_line_fllevel <= i_level and i_level <= cur_line_flevel then
						sign = f_open
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
				fold_info = foldinfos[fold_info.start]
				while i_level < fold_info.llevel do
					fold_info = foldinfos[foldinfos[fold_info.start - 1].start]
				end
				-- if end line already exist, just return
				if fold_end_infos[fold_info.start][i_level] then
					return
				end
				if fold_info.llevel <= i_level and i_level <= fold_info.level then
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
				if cur_line_finfo.lines > 0 and i_level < cur_line_finfo.level - 1 then
					local next_line = cur_line_finfo.start + cur_line_finfo.lines
					cur_line = next_line - 1
					cur_line_finfo = foldinfos[cur_line]
					next_line_finfo = foldinfos[cur_line + 1]
				end

				local cur_line_fstart = cur_line_finfo.start
				-- if the last line in a fold, it's must the end of the folds
				if cur_line == last_line then
					save_fold_end_line(cur_line, i_level, cur_line_finfo)
					return f_end
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
						sign = f_end
					end
				end

				-- same level but not same fold
				if next_line_flevel == cur_line_flevel and (cur_line_fstart < next_line_fstart) then
					if next_line_fllevel <= i_level and i_level <= next_line_flevel then
						sign = f_end
					end
				end

				if next_line_flevel > cur_line_flevel then
					if next_line_fllevel <= i_level and i_level <= cur_line_flevel then
						sign = f_end
					end
				end

				if sign then
					save_fold_end_line(cur_line, i_level, cur_line_finfo)
				end

				return sign
			end

			local cursor_line
			local cursor_line_finfo
			local cursor_line_flevel
			local cursor_line_fstart
			local is_cursor_fold_closed
			local cursor_fold_top

			---@param i_level integer
			---@param cur_line_finfo FoldInfo
			---@param cur_line integer
			---@return boolean|nil
			local cursor_fold_closed

			---@param i_level integer
			---@param cur_line_finfo FoldInfo
			---@param cur_line integer
			---@return boolean
			local cursor_fold

			if not disable_cursor_highlight then
				cursor_line = fn.line(".")
				cursor_line_finfo = foldinfos[cursor_line]
				cursor_line_flevel = cursor_line_finfo.level
				cursor_line_fstart = cursor_line_finfo.start
				is_cursor_fold_closed = cursor_line_finfo.lines > 0

				if is_cursor_fold_closed then
					local fold_info = foldinfos[cursor_line_fstart]
					if cursor_line_flevel > 1 and not (fold_info.llevel <= cursor_line_flevel - 1) then
						local previous = foldinfos[fold_info.start - 1]
						if previous.level > 0 then
							fold_info = foldinfos[previous.start]
						end
						while fold_info.llevel >= cursor_line_flevel and fold_info.start > 1 do
							previous = foldinfos[fold_info.start - 1]
							if previous.level <= 0 then
								break
							end
							fold_info = foldinfos[previous.start]
						end
					end
					cursor_fold_top = fold_info.start
				end

				cursor_fold_closed = function(i_level, cur_line_finfo, cur_line)
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
								if fold_end_line >= cur_line then
									return true
								end
							end
						end
					end
				end

				cursor_fold = function(i_level, cur_line_finfo, cur_line)
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

							local cur_line_flines = cur_line_finfo.lines
							if cur_line_flines > 0 and fold_end_line == cur_line_flines + cur_line_fstart - 1 then
								return true
							end
						end
					end

					return false
				end
			end

			local fold_sign = function(i_level, cur_line, cur_line_finfo, next_line_finfo)
				local start_sign = open_start_sign(i_level, cur_line, cur_line_finfo)
				local end_sign = open_end_sign(i_level, cur_line, cur_line_finfo, next_line_finfo)
				if start_sign and end_sign then
					save_fold_end_line(cur_line, i_level, cur_line_finfo)
					return ""
				end
				if start_sign then
					return start_sign
				end
				if end_sign then
					return end_sign
				end
			end

			local row = toprow
			while row <= botrow do
				local skip_rows
				local cur_line = row + 1
				if cur_line > last_line then
					break
				end
				local cur_line_finfo = foldinfos[cur_line]
				if cur_line_finfo then
					local cur_line_flevel = cur_line_finfo.level
					if cur_line_flevel > 0 then
						-- local cur_line_fstart = cur_line_finfo.start
						-- local cur_line_fstartindent = cur_line_finfo.start_indent

						local next_line = (cur_line + 1) <= last_line and (cur_line + 1) or last_line
						local next_line_finfo = foldinfos[next_line]

						-- TODO: try from the deepest to the outermost level
						-- for i_level = cur_line_flevel, 1, -1 do

						local is_closed = cur_line_finfo.lines > 0

						local to_level = cur_line_flevel
						if max_level ~= nil and max_level < to_level then
							to_level = max_level
						end

						if cur_line == cur_line_finfo.start then
							save_fold_indent(cur_line_finfo)
						end
						local base_indent = flevel_indents[1] or 0

						for i_level = 1, to_level do
							local raw_col
							local col
							if use_level_spaced then
								raw_col = (base_indent + (i_level - 1) * sign_width) - leftcol
								col = raw_col + border_shift
							else
								local indent = flevel_indent(i_level)
								raw_col = indent - leftcol
								col = raw_col + border_shift
							end

							-- Keep legacy behavior: allow negative `virt_text_win_col` (gets clamped by Neovim),
							-- but skip drawing when the raw column is fully scrolled out to the left.
							if raw_col >= 0 then
								local sign = is_closed and close_sign(i_level, cur_line_finfo)
								if sign then
									local end_line = cur_line + cur_line_finfo.lines - 1
									fold_end_infos[cur_line_finfo.start][i_level + 1] = end_line
									skip_rows = cur_line_finfo.lines

									if sign == f_close then
										if open_start_sign(i_level, cur_line, cur_line_finfo) then
											sign = f_open_start_close
										else
											local next_line = end_line + 1
											local next_line_finfo = foldinfos[next_line]
											local cur_line = end_line
											local cur_line_finfo = foldinfos[cur_line]
											if open_end_sign(i_level, cur_line, cur_line_finfo, next_line_finfo) then
												sign = f_open_end_close
											end
										end
									end
								end
								sign = sign
									or fold_sign(i_level, cur_line, cur_line_finfo, next_line_finfo)
								sign = sign or f_sep

								if sign ~= "" then
									local is_cursor_fold = false
									if disable_cursor_highlight then
										virt_text[2] = "FoldLine"
										extmark_config.priority = priority
									else
										if
											(not is_cursor_fold_closed and cursor_fold(i_level, cur_line_finfo, cur_line))
											or (is_cursor_fold_closed and cursor_fold_closed(i_level, cur_line_finfo, cur_line))
										then
											virt_text[2] = "FoldLineCurrent"
											extmark_config.priority = priority + 1
											is_cursor_fold = true
										else
											virt_text[2] = "FoldLine"
											extmark_config.priority = priority
										end
									end

									if (not current_fold_only) or is_cursor_fold then
										virt_text[1] = sign
										extmark_config.virt_text_win_col = col
										set_extmark(bufnr, ns, row, 0, extmark_config)
										if profile_enabled then
											extmark_calls = extmark_calls + 1
										end
									end
								end
							end
						end
					end
				end
				row = row + (skip_rows or 1)
			end

			if profile_enabled then
				local uv = vim.uv or vim.loop
				local elapsed_ns = uv.hrtime() - profile_start_ns
				vim.g.fold_line_profile_last = {
					winid = winid,
					bufnr = bufnr,
					toprow = toprow,
					botrow = botrow,
					elapsed_ns = elapsed_ns,
					foldinfo_calls = foldinfo_calls,
					extmark_calls = extmark_calls,
					-- helpful context:
					leftcol = leftcol,
					last_line = last_line,
					max_level = max_level,
					disable_cursor_highlight = disable_cursor_highlight,
					current_fold_only = current_fold_only,
					indent_sample_count = indent_sample_count,
					indent_bad_growth_count = indent_bad_growth_count,
					indent_clamp_count = indent_clamp_count,
					use_level_spaced = use_level_spaced,
					ancestor_hops = ancestor_hops,
					out_of_bounds_foldinfo_requests = out_of_bounds_foldinfo_requests,
				}
			end
		end)
	end
end

return M
