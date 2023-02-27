local M = {}

---Get the buffer id from the options
---@param opts? {buffer?: number, win?: number}
---@return number
M.get_buffer_id = function(opts)
	if opts and opts.buffer then
		return opts.buffer
	end

	if opts and opts.win then
		return vim.api.nvim_win_get_buf(opts.win)
	end

	return vim.api.nvim_get_current_buf()
end

---Get the window id from the options
---@param opts? {win?: number}
---@return number
M.get_win_id = function(opts)
	local win_id = opts and opts.win or vim.api.nvim_get_current_win()
	return win_id
end

---Get the visual range of the current buffer.
---@param opts? {buffer?: number, win?: number}
---@return {start_row: number, start_col: number, end_row: number, end_col: number}
M.get_visual_range = function(opts)
	local buffer_id = M.get_buffer_id(opts)
	local start_pos = vim.api.nvim_buf_get_mark(buffer_id, "<")
	local start_row = start_pos[1] - 1
	local start_col = start_pos[2]
	local end_pos = vim.api.nvim_buf_get_mark(buffer_id, ">")
	local end_row = end_pos[1] - 1
	local last_line = vim.api.nvim_buf_get_lines(buffer_id, end_row, end_row + 1, true)[1]
	local end_col = #last_line
	return {
		start_row = start_row,
		start_col = start_col,
		end_row = end_row,
		end_col = end_col,
	}
end

---Get selected text
---@param opts? {buffer?: number, win?: number}
M.get_selected_text = function(opts)
	local range = M.get_visual_range(opts)
	local buffer_id = M.get_buffer_id(opts)

	return vim.api.nvim_buf_get_text(buffer_id, range.start_row, range.start_col, range.end_row, range.end_col, {})
end

---Get the range of the context befor the cursor
---@param opts {buffer?: number, win?: number, context_size: number}
---@return {start_row: number, start_col: number, end_row: number, end_col: number}
function M.get_context_range(opts)
	assert(opts.context_size, "context size is nil")

	local win_id = M.get_win_id(opts)
	local buffer_id = M.get_buffer_id(opts)

	local start_row, start_col, end_row, end_col
	local cursor_pos = vim.api.nvim_win_get_cursor(win_id)

	-- Calculate the start row by subtracting the context size from the current row
	start_row = math.max(0, cursor_pos[1] - 1 - opts.context_size)
	start_col = 0
	end_row = cursor_pos[1] - 1

	-- Get the last line of the buffer
	local last_line = vim.api.nvim_buf_get_lines(buffer_id, end_row, end_row + 1, true)[1]
	-- Calculate the end column by getting the length of the last line
	end_col = #last_line

	-- Return a table containing the start row, start column, end row, and end column
	return {
		start_row = start_row,
		start_col = start_col,
		end_row = end_row,
		end_col = end_col,
	}
end

---Get text range for smart selection
---@param opts {is_visual_mode?: boolean, context_size?: number, buffer?: number, win?: number}
M.smart_get_text_range = function(opts)
	assert(opts.is_visual_mode or opts.context_size, "is_visual_mode or context_size should be specified")
	if opts.is_visual_mode then
		return M.get_visual_range()
	elseif opts.context_size then
		---@diagnostic disable-next-line: param-type-mismatch
		return M.get_context_range(opts)
	end
end

---Get text from the current buffer.
---@param opts {is_visual_mode?: boolean, context_size?: number, buffer?: number, win?: number}
M.smart_get_text = function(opts)
	local range = M.smart_get_text_range(opts)
	local buffer_id = M.get_buffer_id(opts)
	return vim.api.nvim_buf_get_text(buffer_id, range.start_row, range.start_col, range.end_row, range.end_col, {})
end

---Join the given lines in a string.
---@param lines string[]
---@return string
M.join_lines = function(lines)
	local text = ""
	for i, line in ipairs(lines) do
		text = text .. line
		if i < #lines then
			text = text .. "\n"
		end
	end
	return text
end

---Ensure that the given text is a string
---@param text string|string[]
M.ensure_get_text = function(text)
	if type(text) == "string" then
		return text
	elseif type(text) == "table" then
		return M.join_lines(text)
	else
		error(string.format("invalid text type: %s", type(text)))
		---@diagnostic disable-next-line: missing-return
	end
end

---Split text into lines
---@param text string
---@return string[]
M.split_text = function(text)
	return vim.split(text, "\n", {})
end

---Ensures that the text is a table of lines
---@param text string|string[]
---@return string[]
M.ensure_get_lines = function(text)
	if type(text) == "string" then
		-- Split the text into lines
		return M.split_text(text)
	elseif type(text) == "table" then
		-- Return the lines as-is
		return text
	else
		-- Throw an error if the text is not a string or table
		assert(false, string.format("invalid text type: %s", type(text)))
		---@diagnostic disable-next-line: missing-return
	end
end

---Replace the content of the buffer with the given text.
---@param text string|string[]
---@param opts? {buffer?: number, win?: number}
M.buffer_replace_content = function(text, opts)
	local buffer_id = M.get_buffer_id(opts)
	local lines = M.ensure_get_lines(text)
	vim.api.nvim_buf_set_lines(buffer_id, 0, -1, true, lines)
end

---Replace a range of text in a buffer.
---@param text string|string[]
---@param opts {start_row: number, start_col: number, end_row: number, end_col: number, buffer?: number, win?: number}
M.buffer_replace_range = function(text, opts)
	local lines = M.ensure_get_lines(text)
	local buffer_id = M.get_buffer_id(opts)
	vim.api.nvim_buf_set_text(buffer_id, opts.start_row, opts.start_col, opts.end_row, opts.end_col, lines)
end

---Replaces the current selection with the given text.
---@param text string|string[] The text to be used to replace the current selection.
---@param opts {buffer?: number, win?: number} The options to be used when replacing the selection.
M.buffer_replace_selection = function(text, opts)
	---Retrieve the range of the visual selection.
	---@diagnostic disable-next-line: param-type-mismatch
	local range = M.get_visual_range(opts)

	---Replaces the range of the visual selection with the provided text.
	M.buffer_replace_range(text, {
		start_row = range.start_row,
		start_col = range.start_col,
		end_row = range.end_row,
		end_col = range.end_col,
		buffer = opts.buffer,
		win = opts.win,
	})
end

---Appends the given text to a given buffer at the provided position.
---@param text string|string[] The text to be appended to the buffer.
---@param opts {buffer?: number, win?: number, start_row: number} Options for the buffer append. 'start_row' is the row at which to insert the text; 'buffer' is the buffer to which the text should be added; 'win' is the window from which the buffer should be retrieved.
M.buffer_append_text = function(text, opts)
	local lines = M.ensure_get_lines(text)
	local buffer_id = M.get_buffer_id(opts)
	vim.api.nvim_buf_set_text(buffer_id, opts.start_row + 1, 0, opts.start_row + 1, 0, lines)
end

---@param  cmd_args table
---@return boolean
M.is_visual_mode = function(cmd_args)
	return cmd_args.range and cmd_args.range > 0
end

return M
