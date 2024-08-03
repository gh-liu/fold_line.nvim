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

local set_lines = function(lines)
	child.api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

local make_fold = function(start_line, end_line)
	child.cmd(tostring(start_line))
	child.cmd("normal " .. tostring(end_line - start_line + 1) .. "zFzo")
end

T["larger level on fold4.2 start line"] = function(buf_id, lines)
	set_lines({
		" fold1",
		"  fold2",
		"   fold3",
		"    fold4.1",
		"     fold5",
		"     fold5",
		"     fold5",
		"    fold4.2",
		"    fold4.2",
		"   fold3",
		"  fold2",
		" fold1",
	})
	make_fold(1, 12) -- level 1
	make_fold(2, 11) -- level 2
	make_fold(3, 10) -- level 3
	make_fold(4, 7) -- level4
	make_fold(5, 7) -- level5
	make_fold(8, 9) -- level4

	expect.reference_screenshot(child.get_screenshot())
end

T["larger level below fold4.1 end line"] = function(buf_id, lines)
	set_lines({
		" fold1",
		"  fold2",
		"   fold3",
		"    fold4.1",
		"    fold4.1",
		"     fold5",
		"     fold5",
		"     fold5",
		"    fold4.2",
		"    fold4.2",
		"   fold3",
		"  fold2",
		" fold1",
	})
	make_fold(1, 13) -- level 1
	make_fold(2, 12) -- level 2
	make_fold(3, 11) -- level 3
	make_fold(4, 5) -- level4
	make_fold(6, 10) -- level4
	make_fold(6, 8) -- level5

	expect.reference_screenshot(child.get_screenshot())
end

T["start line of a fold is a closed sub fold"] = function(buf_id, lines)
	set_lines({
		" fold1",
		"   fold1",
		"   fold1",
		"   fold1",
		"   fold1",
		"   fold1",
		"   fold1",
		"   fold1",
		"  fold1",
		" fold1",
	})
	make_fold(1, 10)
	make_fold(2, 9)
	make_fold(2, 8)

	child.cmd("2 | foldclose")

	expect.reference_screenshot(child.get_screenshot())
end

T["start line of a fold is a closed sub fold: 1"] = function(buf_id, lines)
	set_lines({
		"fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"        fold",
		"fold",
	})
	make_fold(1, 26)
	make_fold(2, 9)
	make_fold(10, 17)
	make_fold(10, 15)
	make_fold(18, 25)

	child.cmd("10 | foldclose")

	expect.reference_screenshot(child.get_screenshot())
end

T["end line of a fold is a closed sub fold"] = function(buf_id, lines)
	set_lines({
		" fold1",
		"  fold1",
		"   fold1",
		"   fold1",
		"   fold1",
		"   fold1",
		"   fold1",
		"   fold1",
		"   fold1",
		" fold1",
	})
	make_fold(1, 10)
	make_fold(2, 9)
	make_fold(3, 9)

	child.cmd("3 | foldclose")

	expect.reference_screenshot(child.get_screenshot())
end

T["end line of a fold is a closed sub fold: 1"] = function(buf_id, lines)
	set_lines(vim.split(
		[[
 fold
         fold
         fold
         fold
         fold
         fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
         fold
         fold
         fold
         fold
         fold
 fold]],
		"\n"
	))
	make_fold(1, 23)
	make_fold(2, 6)
	make_fold(7, 16)
	make_fold(7, 10)
	make_fold(11, 16)
	make_fold(18, 22)

	child.cmd("12 | foldclose")

	expect.reference_screenshot(child.get_screenshot())
end

T["end line of a fold is a closed sub fold: 2"] = function(buf_id, lines)
	set_lines(vim.split(
		[[
 fold
         fold
         fold
         fold
         fold
         fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
                 fold
         fold
         fold
         fold
         fold
         fold
 fold]],
		"\n"
	))
	make_fold(1, 22)
	make_fold(2, 6)
	make_fold(7, 16)
	make_fold(7, 10)
	make_fold(11, 16)
	make_fold(17, 21)

	child.cmd("12 | foldclose")

	expect.reference_screenshot(child.get_screenshot())
end

return T
