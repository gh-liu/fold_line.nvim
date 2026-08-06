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

T["__profile_closed_child_at_eof_stays_in_bounds"] = function()
	child.cmd("e tests/testcases/closed_child_at_eof.txt")
	child.cmd("source tests/testcases/closed_child_at_eof.vim")
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

T["__config_normalizes_mixed_sign_widths"] = function()
	child.lua([[
		vim.g.fold_line_char_open_start = "=="
		vim.g.fold_line_char_open_end = "|"
	]])

	local built = child.lua_get([[require("fold_line.config").build()]])
	eq(built.sign_width, 2)
	eq(built.border_shift, -2)
	eq(child.lua_get([[vim.fn.strdisplaywidth(require("fold_line.config").build().fold_signs.f_end)]]), 2)
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

T["__generated_fold_forests_preserve_render_invariants"] = function()
	local failures = child.lua_get([[(function()
		local api = vim.api
		local original_set_extmark = api.nvim_buf_set_extmark
		local fold_ns = api.nvim_get_namespaces().FoldLine
		local failures = {}
		local marks = {}

		api.nvim_buf_set_extmark = function(bufnr, ns, row, col, opts)
			if ns == fold_ns then
				marks[#marks + 1] = {
					row = row,
					col = col,
					win_col = opts.virt_text_win_col,
					text = opts.virt_text[1][1],
					hl = opts.virt_text[1][2],
					priority = opts.priority,
					ephemeral = opts.ephemeral,
				}
			end
			return original_set_extmark(bufnr, ns, row, col, opts)
		end

		local function check(ok, seed, message)
			if not ok then
				failures[#failures + 1] = ("seed %d: %s"):format(seed, message)
			end
		end

		local function new_random(seed)
			local state = seed
			return function(limit)
				state = (state * 48271) % 2147483647
				return state % limit
			end
		end

		local function generate_case(seed, line_count)
			local random = new_random(seed)
			local nodes = {}
			local max_depth = 0

			local function add_nodes(first, last, depth)
				local line = first
				while line < last do
					if random(4) ~= 0 then
						local max_length = math.min(14, last - line + 1)
						local finish = line + 1 + random(max_length - 1)
						nodes[#nodes + 1] = { first = line, last = finish, depth = depth }
						max_depth = math.max(max_depth, depth)
						if depth < 8 and finish - line >= 3 and random(3) ~= 0 then
							add_nodes(line + 1, finish, depth + 1)
						end
						line = finish + 1
					else
						line = line + 1
					end
				end
			end

			add_nodes(1, line_count, 1)
			if #nodes == 0 then
				nodes[1] = { first = 1, last = line_count, depth = 1 }
				max_depth = 1
			end
			return random, nodes, max_depth
		end

		local function mark_signature()
			local unique = {}
			for _, mark in ipairs(marks) do
				local part = table.concat({
					mark.row,
					mark.col,
					mark.win_col,
					mark.text,
					mark.hl,
					mark.priority,
				}, ":")
				unique[part] = true
			end
			local parts = {}
			for part in pairs(unique) do
				parts[#parts + 1] = part
			end
			table.sort(parts)
			return table.concat(parts, "|")
		end

		local ok, err = xpcall(function()
			vim.g.fold_line_profile = true
			vim.wo.foldmethod = "manual"
			vim.wo.wrap = false

			for seed = 1, 40 do
				local line_count = 40 + seed
				local random, nodes, max_depth = generate_case(seed, line_count)
				local lines = {}
				for line = 1, line_count do
					local indent = random(13)
					lines[line] = string.rep(" ", indent) .. "line " .. line
				end

				vim.cmd("normal! zE")
				api.nvim_buf_set_lines(0, 0, -1, false, lines)
				-- Manual folds close when created, so install descendants before their
				-- parents to keep every generated range addressable.
				for i = #nodes, 1, -1 do
					local node = nodes[i]
					vim.cmd(("%d,%dfold"):format(node.first, node.last))
				end
				local expected_levels = {}
				for line = 1, line_count do
					expected_levels[line] = 0
				end
				for _, node in ipairs(nodes) do
					for line = node.first, node.last do
						expected_levels[line] = expected_levels[line] + 1
					end
				end
				for line = 1, line_count do
					check(vim.fn.foldlevel(line) == expected_levels[line], seed,
						("unexpected fold level at line %d"):format(line))
				end

				vim.cmd("normal! zR")
				local anchor = nodes[1 + random(#nodes)]
				for _, node in ipairs(nodes) do
					node.closed = random(5) == 0
				end
				for i = #nodes, 1, -1 do
					local node = nodes[i]
					local contains_anchor = node.first <= anchor.first and anchor.first <= node.last
					if node.closed and not contains_anchor then
						api.nvim_win_set_cursor(0, { node.first, 0 })
						vim.cmd("normal! zc")
						check(vim.fn.foldclosed(node.first) == node.first, seed,
							("failed to close fold %d:%d"):format(node.first, node.last))
					end
				end

				api.nvim_win_set_cursor(0, { anchor.first, 0 })
				vim.cmd("normal! zt")

				marks = {}
				vim.cmd("redraw!")
				local first_signature = mark_signature()
				local profile = vim.deepcopy(vim.g.fold_line_profile_last)

				check(profile.out_of_bounds_foldinfo_requests == 0, seed, "out-of-bounds fold query")
				check(profile.foldinfo_calls <= line_count, seed, "fold query count exceeds line count")
				check(profile.ancestor_hops <= line_count, seed, "ancestry walk is not bounded")
				check(profile.extmark_calls > 0, seed, "visible fold produced no extmarks")
				check(profile.extmark_calls <= line_count * max_depth, seed, "extmark count exceeds topology bound")
				check(#marks > 0, seed, "FoldLine namespace produced no extmarks")

				for _, mark in ipairs(marks) do
					check(mark.row >= 0 and mark.row < line_count, seed, "extmark row is outside the buffer")
					check(mark.col == 0, seed, "extmark anchor column changed")
					check(type(mark.win_col) == "number" and mark.win_col == math.floor(mark.win_col), seed,
						"virtual column is not an integer")
					check(mark.text ~= "", seed, "empty fold sign was rendered")
					check(mark.hl == "FoldLine" or mark.hl == "FoldLineCurrent", seed, "unexpected highlight")
					check(type(mark.priority) == "number" and mark.priority >= 0, seed, "invalid priority")
					check(mark.ephemeral == true, seed, "fold sign is not ephemeral")
				end

				marks = {}
				vim.cmd("redraw!")
				check(mark_signature() == first_signature, seed, "identical redraws produced different extmarks")
			end
		end, debug.traceback)

		api.nvim_buf_set_extmark = original_set_extmark
		if not ok then
			failures[#failures + 1] = err
		end
		return failures
	end)()]])

	eq(failures, {})
end

return T
