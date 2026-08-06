local M = {}

local api = vim.api
local empty_fold_info = {
	start = 0,
	level = 0,
	llevel = 0,
	lines = 0,
	start_indent = 0,
}

---@class FoldLineProfile
---@field enabled boolean
---@field start_ns? integer
---@field foldinfo_calls integer
---@field extmark_calls integer
---@field ancestor_hops integer
---@field out_of_bounds_foldinfo_requests integer
---@field indent_clamp_count integer
---@field indent_bad_growth_count integer
---@field indent_sample_count integer

---@class FoldLineRenderer
---@field ns integer
---@field fold_signs table<string, string>
---@field priority integer
---@field border_shift integer
---@field sign_width integer
---@field extmark_config table<string, any>
---@field get_fold_info fun(wp:any, line:integer, indent_cache:table<integer, integer>):FoldInfo
---@field find_window_by_handle fun(winid:integer):any

---@class FoldLineFrame
---@field renderer FoldLineRenderer
---@field winid integer
---@field bufnr integer
---@field toprow integer
---@field botrow integer
---@field leftcol integer
---@field last_line integer
---@field current_fold_only boolean
---@field disable_cursor_highlight boolean
---@field max_level? integer
---@field use_level_spaced boolean
---@field foldinfos FoldInfo[]
---@field fold_end_infos table<integer, table<integer, integer>>
---@field flevel_indents table<integer, integer>
---@field profile FoldLineProfile

---@class FoldLineCursor
---@field level integer
---@field start integer
---@field closed boolean
---@field top? integer

local function resolve_strategy(strategy)
	if strategy ~= "indent" and strategy ~= "level" and strategy ~= "hybrid" then
		return "hybrid"
	end
	return strategy
end

local function should_render_window(winid, bufnr, toprow, botrow)
	return vim.wo[winid].foldenable
		and bufnr == api.nvim_win_get_buf(winid)
		and not vim.g.fold_line_disable
		and not vim.w[winid].fold_line_disable
		and not vim.b[bufnr].fold_line_disable
		and toprow - botrow ~= 0
end

local function new_fold_info_cache(get_fold_info, wp, last_line, profile)
	local indent_cache = {} ---@type table<integer, integer>
	local foldinfos = {} ---@type FoldInfo[]
	return setmetatable(foldinfos, {
		__index = function(infos, line)
			if line < 1 or line > last_line then
				profile.out_of_bounds_foldinfo_requests = profile.out_of_bounds_foldinfo_requests + 1
				return empty_fold_info
			end
			if profile.enabled then
				profile.foldinfo_calls = profile.foldinfo_calls + 1
			end
			local info = get_fold_info(wp, line, indent_cache)
			rawset(infos, line, info)
			return info
		end,
	})
end

local function new_frame(renderer, winid, bufnr, toprow, botrow)
	local strategy = resolve_strategy(vim.b[bufnr].fold_line_bar_pos_strategy
		or vim.w[winid].fold_line_bar_pos_strategy or vim.g.fold_line_bar_pos_strategy)
	local foldmethod = vim.wo[winid].foldmethod
	local max_level = tonumber(vim.g.fold_line_max_level)
	if max_level ~= nil and max_level < 1 then
		max_level = nil
	end
	local leftcol = vim.fn.winsaveview().leftcol
	local last_line = api.nvim_buf_line_count(bufnr)
	local wp = renderer.find_window_by_handle(winid)
	---@type FoldLineProfile
	local profile = {
		enabled = vim.g.fold_line_profile == true,
		foldinfo_calls = 0,
		extmark_calls = 0,
		ancestor_hops = 0,
		out_of_bounds_foldinfo_requests = 0,
		indent_clamp_count = 0,
		indent_bad_growth_count = 0,
		indent_sample_count = 0,
	}
	if profile.enabled then
		profile.start_ns = (vim.uv or vim.loop).hrtime()
	end
	---@type FoldLineFrame
	local frame = {
		renderer = renderer,
		winid = winid,
		bufnr = bufnr,
		toprow = toprow,
		botrow = botrow,
		leftcol = leftcol,
		last_line = last_line,
		current_fold_only = vim.g.fold_line_current_fold_only == true,
		disable_cursor_highlight = vim.g.fold_line_disable_cursor_highlight == true,
		max_level = max_level,
		profile = profile,
		flevel_indents = {},
		use_level_spaced = strategy == "level"
			or (strategy == "hybrid" and (foldmethod == "expr" or foldmethod == "syntax")),
		fold_end_infos = setmetatable({}, {
			__index = function(t, k)
				rawset(t, k, {})
				return t[k]
			end,
		}),
	}
	frame.foldinfos = new_fold_info_cache(renderer.get_fold_info, wp, last_line, profile)
	return frame
end

local function save_fold_indent(frame, info)
	local level = info.level
	local llevel = info.llevel
	local indent = info.start_indent
	frame.flevel_indents[level] = indent
	if llevel < level then
		local parent_level = llevel - 1
		local parent_indent = frame.flevel_indents[parent_level]
		if parent_indent == nil and info.start > 1 then
			local parent = frame.foldinfos[info.start - 1]
			if parent and parent.level > 0 then
				parent_indent = parent.start_indent
			end
		end
		parent_indent = parent_indent or 0
		local delta = indent - parent_indent
		local denom = level - parent_level
		local unit = delta / denom
		frame.profile.indent_sample_count = frame.profile.indent_sample_count + 1
		if delta < denom then
			frame.profile.indent_bad_growth_count = frame.profile.indent_bad_growth_count + 1
		end
		-- Share available columns when indentation cannot fit every level instead
		-- of pushing additional fold signs into source text.
		for i = llevel, level - 1 do
			frame.flevel_indents[i] = parent_indent + math.ceil((i - parent_level) * unit)
		end
	end
end

local function warm_fold_indents(frame)
	local info = frame.foldinfos[frame.toprow + 1]
	local ancestry = {}
	local seen = {}
	while info.level > 0 and not seen[info.start] do
		ancestry[#ancestry + 1] = info
		seen[info.start] = true
		if info.start <= 1 then
			break
		end
		frame.profile.ancestor_hops = frame.profile.ancestor_hops + 1
		info = frame.foldinfos[info.start - 1]
	end
	for i = #ancestry, 1, -1 do
		save_fold_indent(frame, ancestry[i])
	end
end

local function close_sign(signs, i_level, info)
	if info.level - 1 == i_level then
		return signs.f_close
	end
	if info.level == 1 then
		return signs.f_top_close
	end
end

local function open_start_sign(signs, i_level, line, info)
	if line == 1 then
		return signs.f_open
	end
	local sign
	if line == info.start then
		if info.llevel <= i_level and i_level <= info.level then
			sign = signs.f_open
		end
		sign = (info.lines > 0 and sign) and "" or sign
	end
	return sign
end

local function save_fold_end_line(frame, line, i_level, info)
	info = frame.foldinfos[info.start]
	while i_level < info.llevel and info.start > 1 do
		local previous = frame.foldinfos[info.start - 1]
		if previous.level <= 0 then
			break
		end
		info = frame.foldinfos[previous.start]
	end
	if frame.fold_end_infos[info.start][i_level] then
		return
	end
	if info.llevel <= i_level and i_level <= info.level then
		frame.fold_end_infos[info.start][i_level] = line
	end
end

local function open_end_sign(frame, i_level, line, info, next_info)
	local signs = frame.renderer.fold_signs
	if info.lines > 0 and i_level < info.level - 1 then
		line = info.start + info.lines - 1
		info = frame.foldinfos[line]
		next_info = line < frame.last_line and frame.foldinfos[line + 1] or empty_fold_info
	end
	if line == frame.last_line then
		save_fold_end_line(frame, line, i_level, info)
		return signs.f_end
	end
	local sign
	if next_info.level < info.level then
		local start = next_info.level + 1
		if next_info.start == line + 1 then
			start = next_info.llevel
		end
		if start <= i_level and i_level <= info.level then
			sign = signs.f_end
		end
	end
	if next_info.level == info.level and info.start < next_info.start then
		if next_info.llevel <= i_level and i_level <= next_info.level then
			sign = signs.f_end
		end
	end
	if next_info.level > info.level then
		if next_info.llevel <= i_level and i_level <= info.level then
			sign = signs.f_end
		end
	end
	if sign then
		save_fold_end_line(frame, line, i_level, info)
	end
	return sign
end

local function fold_sign(frame, i_level, line, info, next_info)
	local start_sign = open_start_sign(frame.renderer.fold_signs, i_level, line, info)
	local end_sign = open_end_sign(frame, i_level, line, info, next_info)
	if start_sign and end_sign then
		save_fold_end_line(frame, line, i_level, info)
		return ""
	end
	return start_sign or end_sign
end

local function capture_cursor_fold(frame)
	if frame.disable_cursor_highlight then
		return nil
	end
	local line = vim.fn.line(".")
	local info = frame.foldinfos[line]
	---@type FoldLineCursor
	local cursor = {
		level = info.level,
		start = info.start,
		closed = info.lines > 0,
	}
	if cursor.closed then
		local fold_info = frame.foldinfos[cursor.start]
		if cursor.level > 1 and not (fold_info.llevel <= cursor.level - 1) then
			local previous = frame.foldinfos[fold_info.start - 1]
			if previous.level > 0 then
				fold_info = frame.foldinfos[previous.start]
			end
			while fold_info.llevel >= cursor.level and fold_info.start > 1 do
				previous = frame.foldinfos[fold_info.start - 1]
				if previous.level <= 0 then
					break
				end
				fold_info = frame.foldinfos[previous.start]
			end
		end
		cursor.top = fold_info.start
	end
	return cursor
end

local function is_cursor_fold(frame, cursor, i_level, info, line)
	if cursor.closed then
		if i_level == cursor.level - 1 and cursor.top <= info.start then
			local finish = frame.fold_end_infos[cursor.top][i_level]
			if not finish then
				return info.start <= cursor.start or info.level >= cursor.level
			end
			return finish >= line
		end
		return nil
	end
	if i_level == info.level and info.level == cursor.level and info.start == cursor.start then
		return true
	end
	if i_level == cursor.level then
		local finish = frame.fold_end_infos[cursor.start][i_level]
		if not finish then
			return cursor.level < info.level and cursor.start <= info.start
		end
		if finish == line then
			return true
		end
		if info.lines > 0 and finish == info.lines + info.start - 1 then
			return true
		end
	end
	return false
end

local function render_rows(frame, cursor)
	local renderer = frame.renderer
	local signs = renderer.fold_signs
	local extmark_config = renderer.extmark_config
	local virt_text = extmark_config.virt_text[1]
	local row = frame.toprow
	while row <= frame.botrow do
		local skip_rows
		local line = row + 1
		if line > frame.last_line then
			break
		end
		local info = frame.foldinfos[line]
		if info and info.level > 0 then
			local next_line = line + 1 <= frame.last_line and line + 1 or frame.last_line
			local next_info = frame.foldinfos[next_line]
			local is_closed = info.lines > 0
			local to_level = info.level
			if frame.max_level ~= nil and frame.max_level < to_level then
				to_level = frame.max_level
			end
			if line == info.start then
				save_fold_indent(frame, info)
			end
			local base_indent = frame.flevel_indents[1] or 0
			for i_level = 1, to_level do
				local raw_col
				if frame.use_level_spaced then
					raw_col = base_indent + (i_level - 1) * renderer.sign_width
				else
					raw_col = frame.flevel_indents[i_level] or 0
				end
				raw_col = raw_col - frame.leftcol
				local col = raw_col + renderer.border_shift
				if raw_col >= 0 then
					local sign = is_closed and close_sign(signs, i_level, info)
					if sign then
						local end_line = line + info.lines - 1
						frame.fold_end_infos[info.start][i_level + 1] = end_line
						skip_rows = info.lines
						if sign == signs.f_close then
							if open_start_sign(signs, i_level, line, info) then
								sign = signs.f_open_start_close
							else
								local after = end_line + 1
								local after_info = after <= frame.last_line and frame.foldinfos[after] or empty_fold_info
								if open_end_sign(frame, i_level, end_line, frame.foldinfos[end_line], after_info) then
									sign = signs.f_open_end_close
								end
							end
						end
					end
					sign = sign or fold_sign(frame, i_level, line, info, next_info) or signs.f_sep
					if sign ~= "" then
						local current = false
						if frame.disable_cursor_highlight then
							virt_text[2] = "FoldLine"
							extmark_config.priority = renderer.priority
						elseif is_cursor_fold(frame, cursor, i_level, info, line) then
							virt_text[2] = "FoldLineCurrent"
							extmark_config.priority = renderer.priority + 1
							current = true
						else
							virt_text[2] = "FoldLine"
							extmark_config.priority = renderer.priority
						end
						if not frame.current_fold_only or current then
							virt_text[1] = sign
							extmark_config.virt_text_win_col = col
							api.nvim_buf_set_extmark(frame.bufnr, renderer.ns, row, 0, extmark_config)
							if frame.profile.enabled then
								frame.profile.extmark_calls = frame.profile.extmark_calls + 1
							end
						end
					end
				end
			end
		end
		row = row + (skip_rows or 1)
	end
end

local function publish_profile(frame)
	if not frame.profile.enabled then
		return
	end
	local p = frame.profile
	vim.g.fold_line_profile_last = {
		winid = frame.winid,
		bufnr = frame.bufnr,
		toprow = frame.toprow,
		botrow = frame.botrow,
		elapsed_ns = (vim.uv or vim.loop).hrtime() - p.start_ns,
		foldinfo_calls = p.foldinfo_calls,
		extmark_calls = p.extmark_calls,
		leftcol = frame.leftcol,
		last_line = frame.last_line,
		max_level = frame.max_level,
		disable_cursor_highlight = frame.disable_cursor_highlight,
		current_fold_only = frame.current_fold_only,
		indent_sample_count = p.indent_sample_count,
		indent_bad_growth_count = p.indent_bad_growth_count,
		indent_clamp_count = p.indent_clamp_count,
		use_level_spaced = frame.use_level_spaced,
		ancestor_hops = p.ancestor_hops,
		out_of_bounds_foldinfo_requests = p.out_of_bounds_foldinfo_requests,
	}
end

---@param opts table
---@return fun(_, winid:integer, bufnr:integer, toprow:integer, botrow:integer)
function M.create_on_win(opts)
	local config = opts.config
	---@type FoldLineRenderer
	local renderer = {
		ns = opts.ns,
		fold_signs = config.fold_signs,
		priority = config.priority,
		border_shift = config.border_shift,
		sign_width = config.sign_width or 1,
		extmark_config = config.extmark_config,
		get_fold_info = opts.get_fold_info,
		find_window_by_handle = opts.find_window_by_handle,
	}
	return function(_, winid, bufnr, toprow, botrow)
		if not should_render_window(winid, bufnr, toprow, botrow) then
			return
		end
		api.nvim_win_call(winid, function()
			api.nvim_win_set_hl_ns(winid, renderer.ns)
			local frame = new_frame(renderer, winid, bufnr, toprow, botrow)
			warm_fold_indents(frame)
			local cursor = capture_cursor_fold(frame)
			render_rows(frame, cursor)
			publish_profile(frame)
		end)
	end
end

return M
