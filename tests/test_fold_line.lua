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

return T
