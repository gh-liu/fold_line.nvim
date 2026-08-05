local MiniTest = require("mini.test")

-- Define helper aliases
local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

-- Create (but not start) child Neovim object
local child = MiniTest.new_child_neovim()

-- Define main test set of this file
local T = new_set({
	-- Register hooks
	hooks = {
		-- This will be executed before every (even nested) case
		pre_case = function()
			-- Restart child process with custom 'init.lua' script
			child.restart({ "-u", "scripts/minimal_init.lua" })
			-- Load tested plugin
			child.lua([[M = require('fold_line')]])
		end,
		-- This will be executed one after all tests from this set are finished
		post_once = child.stop,
	},
})

---@type string[]
local testfiles = vim.fs.find(function(name, _)
	return name:match(".*txt$")
end, {
	path = "tests/testcases",
	limit = math.huge,
	type = "file",
})

for _, testfile in ipairs(testfiles) do
	local name = vim.fn.fnamemodify(testfile, ":t:r")
	local fold_cmd_file = testfile:match("(.*).txt") .. ".vim"

	T["__" .. name] = function(buf_id, lines)
		child.cmd("e " .. testfile)
		child.cmd("source " .. fold_cmd_file)
		expect.reference_screenshot(child.get_screenshot())
	end
end

T["__profile_visible_fold_sampling"] = function()
	child.cmd("let g:fold_line_profile=v:true")
	child.cmd("e tests/testcases/split_nested_groups.txt")
	child.cmd("source tests/testcases/split_nested_groups.vim")
	child.cmd("redraw!")

	local profile = child.lua_get("vim.g.fold_line_profile_last")

	eq(profile.indent_bad_growth_count, 0)
	eq(profile.use_level_spaced, false)
	eq(profile.out_of_bounds_foldinfo_requests, 0)
end

T["__profile_eof_folds_stay_in_bounds"] = function()
	child.cmd("e tests/testcases/profile_enabled.txt")
	child.cmd("source tests/testcases/profile_enabled.vim")
	child.cmd("redraw!")

	local profile = child.lua_get("vim.g.fold_line_profile_last")
	eq(profile.out_of_bounds_foldinfo_requests, 0)
end

T["__config_rejects_invalid_values"] = function()
	child.lua([[
		vim.g.fold_line_char_priority = "invalid"
		vim.g.fold_line_char_open_start = { "not", "a", "string" }
	]])

	local built = child.lua_get([[require("fold_line.config").build()]])
	eq(built.priority, 100)
	eq(built.fold_signs.f_open, "┌")
	eq(built.sign_width >= 1, true)
end

T["__ffi_normalizes_lines_outside_folds"] = function()
	local foldinfo = child.lua_get([[(function()
		local ffi = require("fold_line.ffi")
		local wp = ffi.find_window_by_handle(vim.api.nvim_get_current_win())
		return ffi.get_fold_info(wp, 1, {})
	end)()]])

	eq(foldinfo, {
		start = 0,
		level = 0,
		llevel = 0,
		lines = 0,
		start_indent = 0,
	})
end

T["__profile_skips_large_closed_fold"] = function()
	child.lua([[
		vim.g.fold_line_profile = true
		vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.map(vim.fn.range(1, 2000), '"line " .. v:val'))
	]])
	child.cmd("setlocal foldmethod=manual")
	child.cmd("1,2000fold")
	child.cmd("normal! zM")
	child.cmd("redraw!")

	local profile = child.lua_get("vim.g.fold_line_profile_last")
	eq(profile.foldinfo_calls < 50, true)
	eq(profile.out_of_bounds_foldinfo_requests, 0)
end

return T
