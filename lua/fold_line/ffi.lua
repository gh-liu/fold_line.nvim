local M = {}

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

local indent = vim.fn.indent

---@alias FoldInfo {start:number, level:number, llevel:number, lines:number, start_indent:number}

---@param wp userdata
---@param lnum integer
---@param indent_cache table<integer, integer>
---@return FoldInfo|?
function M.get_fold_info(wp, lnum, indent_cache)
	local foldinfo = ffi.C.fold_info(wp, lnum)
	local start_indent
	if foldinfo.level > 0 and foldinfo.start > 0 then
		start_indent = indent_cache[foldinfo.start] or indent(foldinfo.start)
		indent_cache[foldinfo.start] = start_indent
	else
		start_indent = indent(foldinfo.start)
	end
	return {
		start = foldinfo.start,
		level = foldinfo.level,
		llevel = foldinfo.llevel,
		lines = foldinfo.lines,
		start_indent = start_indent, -- indent of start line
	} ---@type FoldInfo
end

---@param winid integer
---@return userdata
function M.find_window_by_handle(winid)
	return ffi.C.find_window_by_handle(winid, ffi.new("Error"))
end

return M
