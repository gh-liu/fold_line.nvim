local M = {}

local function normalize_sign_widths(signs)
	local max_width = 0
	for _, sign in pairs(signs) do
		if sign ~= "" then
			local width = vim.fn.strdisplaywidth(sign)
			if width > max_width then
				max_width = width
			end
		end
	end

	if max_width == 0 then
		return signs, 0
	end

	for key, sign in pairs(signs) do
		if sign ~= "" then
			local width = vim.fn.strdisplaywidth(sign)
			if width < max_width then
				signs[key] = sign .. string.rep(" ", max_width - width)
			end
		end
	end

	return signs, max_width
end

function M.build()
	local chars = vim.opt.fillchars:get()
	local signs = {
		f_top_close = vim.g.fold_line_char_top_close or chars.foldclose or "+",
		f_close = vim.g.fold_line_char_close or chars.vertright or "├",
		f_sep = vim.g.fold_line_char_open_sep or chars.foldsep or "│",
		f_open = vim.g.fold_line_char_open_start or "┌",
		f_end = vim.g.fold_line_char_open_end or "└",
		f_open_start_close = vim.g.fold_line_char_open_start_close or "╒",
		f_open_end_close = vim.g.fold_line_char_open_end_close or "╘",
	}

	local max_width
	signs, max_width = normalize_sign_widths(signs)

	local priority = vim.g.fold_line_char_priority or 100

	return {
		priority = priority,
		fold_signs = signs,
		sign_width = max_width,
		border_shift = 0 - max_width,
		extmark_config = {
			virt_text_pos = "overlay",
			hl_mode = "combine",
			ephemeral = true,
			virt_text = { { "", "" } },
		},
	}
end

return M
