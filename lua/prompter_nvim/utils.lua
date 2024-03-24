local M = {}

---Get the visual range of the current buffer.
---@return {start_row: number, start_col: number, end_row: number, end_col: number}|nil
function M.get_visual_range()
  ---@type number, number, number
  local _, srow, scol = unpack(vim.fn.getpos("v"))
  ---@type number, number, number
  local _, erow, ecol = unpack(vim.fn.getpos("."))

  if vim.fn.mode() == "V" then
    if srow > erow then
      srow, erow = erow, srow
    end
    scol, ecol = 1, vim.fn.col({ erow, "$" })
  elseif vim.fn.mode() == "v" then
    if srow > erow or (srow == erow and scol > ecol) then
      srow, erow, scol, ecol = erow, srow, ecol, scol
    end
  elseif vim.fn.mode() == "\22" then
    if srow > erow then
      srow, erow = erow, srow
    end
    if scol > ecol then
      scol, ecol = ecol, scol
    end
  else
    return
  end

  return {
    start_row = srow - 1,
    start_col = scol - 1,
    end_row = erow - 1,
    end_col = ecol,
  }
end

--- Return the visually selected text as an array with an entry for each line
---
--- @return string[]|nil lines The selected text as an array of lines.
function M.get_selected_text()
  ---@type number, number, number
  local _, srow, scol = unpack(vim.fn.getpos("v"))
  ---@type number, number, number
  local _, erow, ecol = unpack(vim.fn.getpos("."))

  -- visual line mode
  if vim.fn.mode() == "V" then
    if srow > erow then
      return vim.api.nvim_buf_get_lines(0, erow - 1, srow, true)
    else
      return vim.api.nvim_buf_get_lines(0, srow - 1, erow, true)
    end
  end

  -- regular visual mode
  if vim.fn.mode() == "v" then
    if srow < erow or (srow == erow and scol <= ecol) then
      return vim.api.nvim_buf_get_text(
        0,
        srow - 1,
        scol - 1,
        erow - 1,
        ecol,
        {}
      )
    else
      return vim.api.nvim_buf_get_text(
        0,
        erow - 1,
        ecol - 1,
        srow - 1,
        scol,
        {}
      )
    end
  end

  -- visual block mode
  if vim.fn.mode() == "\22" then
    local lines = {}
    if srow > erow then
      srow, erow = erow, srow
    end
    if scol > ecol then
      scol, ecol = ecol, scol
    end
    for i = srow, erow do
      table.insert(
        lines,
        vim.api.nvim_buf_get_text(
          0,
          i - 1,
          math.min(scol - 1, ecol),
          i - 1,
          math.max(scol - 1, ecol),
          {}
        )[1]
      )
    end
    return lines
  end
end

---Join the given lines in a string.
---@param lines string[]|nil
---@return string
M.join_lines = function(lines)
  local text = ""
  if lines == nil then
    return text
  end
  ---@cast lines string[]
  for i, line in ipairs(lines) do
    text = text .. line
    if i < #lines then
      ---@type string
      text = text .. "\n"
    end
  end
  return text
end

---Ensure that the given text is a string
---@param text string|string[]
---@return string|nil
M.ensure_get_text = function(text)
  if type(text) == "string" then
    return text
  elseif type(text) == "table" then
    return M.join_lines(text)
  else
    error(string.format("invalid text type: %s", type(text)))
    return
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
    return vim.split(text, "\n", {})
  elseif type(text) == "table" then
    -- Return the lines as-is
    return text
  else
    error(string.format("Invalid text type: %s", type(text)))
  end
end

---Replace the content of the buffer with the given text.
---@param text string|string[]
---@param opts? {buffer?: number}
M.buffer_replace_content = function(text, opts)
  ---@type number
  local buffer_id
  if opts and opts.buffer then
    buffer_id = opts.buffer
  else
    buffer_id = vim.api.nvim_get_current_buf()
  end
  local lines = M.ensure_get_lines(text)
  ---@cast buffer_id number
  vim.api.nvim_buf_set_lines(buffer_id, 0, -1, false, lines)
end

---Replace a range of text in a buffer.
---@param text string|string[]
---@param opts {start_row: number, start_col: number, end_row: number, end_col: number, buffer: number}
M.buffer_replace_range = function(text, opts)
  local lines = M.ensure_get_lines(text)
  ---@type number
  local buffer_id
  if opts and opts.buffer then
    buffer_id = opts.buffer
  else
    buffer_id = vim.api.nvim_get_current_buf()
  end
  ---@cast buffer_id number
  vim.api.nvim_buf_set_text(
    buffer_id,
    opts.start_row,
    opts.start_col,
    opts.end_row,
    opts.end_col,
    lines
  )
end

---Replaces the current selection with the given text.
---@param text string|string[] The text to be used to replace the current selection.
M.buffer_replace_selection = function(text)
  ---Retrieve the range of the visual selection.
  ---@diagnostic disable-next-line: param-type-mismatch
  local range = M.get_visual_range()

  if range == nil then
    return
  end

  ---Replaces the range of the visual selection with the provided text.
  M.buffer_replace_range(text, {
    start_row = range.start_row,
    start_col = range.start_col,
    end_row = range.end_row,
    end_col = range.end_col,
  })
end

---Appends the given text to a given buffer at the provided position.
---@param text string|string[] The text to be appended to the buffer.
---@param opts {start_row: number} Options for the buffer append. 'start_row' is the row at which to insert the text; 'buffer' is the buffer to which the text should be added; 'win' is the window from which the buffer should be retrieved.
M.buffer_append_text = function(text, opts)
  local lines = M.ensure_get_lines(text)
  local buffer_id = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_text(
    buffer_id,
    opts.start_row + 1,
    0,
    opts.start_row + 1,
    0,
    lines
  )
end

---@param cmd_args table
---@return boolean
M.is_visual_mode = function(cmd_args)
  return cmd_args.range and cmd_args.range > 0
end

return M
