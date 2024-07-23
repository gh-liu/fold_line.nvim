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

local set_lines = function(lines)
	child.api.nvim_buf_set_lines(0, 0, -1, true, lines)
end

local make_fold = function(start_line, end_line)
	child.cmd(tostring(start_line))
	child.cmd("normal " .. tostring(end_line - start_line + 1) .. "zFzo")
end

T["basic"] = function(buf_id, lines)
	set_lines({
		" fold1",
		"  fold2",
		"   fold3",
		"    fold4.1",
		"    fold4.1",
		"    fold4.2",
		"    fold4.2",
		"   fold3",
		"  fold2",
		" fold1",
	})
	make_fold(1, 10)
	make_fold(2, 9)
	make_fold(3, 8)
	make_fold(4, 5)
	make_fold(6, 7)

	expect.reference_screenshot(child.get_screenshot())
end

T["same fold start line"] = function(buf_id, lines)
	set_lines({
		"     fold5",
		"     fold5",
		"     fold5",
		"     fold5",
		"     fold5",
		"     fold5",
		"    fold4",
		"   fold2",
		"  fold2",
		" fold1",
	})
	make_fold(1, 10)
	make_fold(1, 9)
	make_fold(1, 8)
	make_fold(1, 7)
	make_fold(1, 6)

	expect.reference_screenshot(child.get_screenshot())
end

T["same fold end line"] = function(buf_id, lines)
	set_lines({
		" fold1",
		"  fold2",
		"   fold2",
		"    fold2",
		"     fold5",
		"     fold5",
		"     fold5",
		"     fold5",
		"     fold5",
		"     fold5",
	})
	make_fold(1, 10)
	make_fold(2, 10)
	make_fold(3, 10)
	make_fold(4, 10)
	make_fold(5, 10)

	expect.reference_screenshot(child.get_screenshot())
end

T["current fold only"] = function(buf_id, lines)
	child.lua("vim.g.fold_line_current_fold_only = true")

	set_lines({
		" fold1",
		"  fold2",
		"   fold2",
		"    fold2",
		"     fold5",
		"     fold5",
		"     fold5",
		"     fold5",
		"     fold5",
		"     fold5",
	})
	make_fold(1, 10)
	make_fold(2, 10)
	make_fold(3, 10)
	make_fold(4, 10)
	make_fold(5, 10)

	child.cmd("5")

	expect.reference_screenshot(child.get_screenshot())
end

T["fallback current closed fold"] = function(buf_id, lines)
	child.lua("vim.g.fold_line_current_fold_only = true")

	set_lines({
		" fold1",
		"  fold2",
		"   fold3",
		"    fold4.1",
		"    fold4.1",
		"    fold4.2",
		"    fold4.2",
		"   fold3",
		"  fold2",
		" fold1",
	})
	make_fold(1, 10)
	make_fold(2, 9)
	make_fold(3, 8)
	make_fold(4, 5)
	make_fold(6, 7)

	child.cmd("4 | foldclose")

	expect.reference_screenshot(child.get_screenshot())
end

T["closed fold"] = function(buf_id, lines)
	set_lines({
		" fold1",
		"  fold2",
		"   fold3",
		"    fold4.1",
		"    fold4.1",
		"    fold4.2",
		"    fold4.2",
		"   fold3",
		"  fold2",
		" fold1",
	})
	make_fold(1, 10)
	make_fold(2, 9)
	make_fold(3, 8)
	make_fold(4, 5)
	make_fold(6, 7)

	child.cmd("4 | foldclose")
	child.cmd("6 | foldclose")

	expect.reference_screenshot(child.get_screenshot())
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

return T
