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
return T