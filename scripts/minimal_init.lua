-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

-- Normalize message area highlight for deterministic screenshots
vim.api.nvim_set_hl(0, "MsgArea", { link = "Normal" })
vim.api.nvim_set_hl(0, "MsgSeparator", { link = "Normal" })

-- Set up 'mini.test' only when calling headless Neovim (like with `make test`)
if #vim.api.nvim_list_uis() == 0 then
	-- Add 'mini.nvim' to 'runtimepath' to be able to use 'mini.test'
	-- Assumed that 'mini.nvim' is stored in 'deps/mini.nvim'
	vim.cmd("set rtp+=deps/mini.test")

	-- Set up 'mini.test'
	local Test = require("mini.test")
	Test.setup({
		execute = {
			reporter = Test.gen_reporter.stdout({
				group_depth = 99,
				quit_on_finish = true,
			}),
			stop_on_error = true,
		},
	})
end
