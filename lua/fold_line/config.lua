local M = {}

local function valid_sign(value, fallback)
	if type(value) ~= "string" or vim.fn.strdisplaywidth(value) < 1 then
		return fallback
	end
	return value
end

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
		f_top_close = valid_sign(vim.g.fold_line_char_top_close, chars.foldclose or "+"),
		f_close = valid_sign(vim.g.fold_line_char_close, chars.vertright or "├"),
		f_sep = valid_sign(vim.g.fold_line_char_open_sep, chars.foldsep or "│"),
		f_open = valid_sign(vim.g.fold_line_char_open_start, "┌"),
		f_end = valid_sign(vim.g.fold_line_char_open_end, "└"),
		f_open_start_close = valid_sign(vim.g.fold_line_char_open_start_close, "╒"),
		f_open_end_close = valid_sign(vim.g.fold_line_char_open_end_close, "╘"),
	}

	local max_width
	signs, max_width = normalize_sign_widths(signs)

	local priority = tonumber(vim.g.fold_line_char_priority) or 100
	if priority < 0 or priority == math.huge or priority == -math.huge or priority ~= priority then
		priority = 100
	else
		priority = math.floor(priority)
	end

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
