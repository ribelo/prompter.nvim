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

---Replace the content of the buffer with the given text.
---@param text string | string[]
---@param opts? {buffer?: number}
M.buffer_replace_content = function(text, opts)
  local buffer_id = opts and opts.buffer or vim.api.nvim_get_current_buf()
  local lines = type(text) == "string" and vim.split(text, "\n") or text
  --- @cast lines string[]

  local ok, err =
    pcall(vim.api.nvim_buf_set_lines, buffer_id, 0, -1, false, lines)
  if not ok then
    vim.notify(
      "Failed to replace buffer content: " .. err,
      vim.log.levels.ERROR
    )
    return
  end
end

--- Add content at the end of the buffer.
---@param text string|string[]
---@param opts? {buffer?: number}
M.buffer_add_content = function(text, opts)
  local buffer_id = opts and opts.buffer or vim.api.nvim_get_current_buf()
  local lines = type(text) == "string" and vim.split(text, "\n") or text
  --- @cast lines string[]

  -- Get the number of lines in the current buffer
  local num_lines = vim.api.nvim_buf_line_count(buffer_id)

  -- Append lines to the end of the buffer
  vim.api.nvim_buf_set_lines(buffer_id, num_lines, num_lines, false, lines)
end

---Replace a range of text in a buffer.
---@param text string|string[]
---@param opts {start_row: number, start_col: number, end_row: number, end_col: number, buffer?: number}
M.buffer_replace_range = function(text, opts)
  local lines = type(text) == "string" and vim.split(text, "\n") or text
  --- @cast lines string[]
  local buffer_id = opts.buffer or vim.api.nvim_get_current_buf()

  local ok, err = pcall(
    vim.api.nvim_buf_set_text,
    buffer_id,
    opts.start_row,
    opts.start_col,
    opts.end_row,
    opts.end_col,
    lines
  )

  if not ok then
    vim.notify("Failed to replace buffer range: " .. err, vim.log.levels.ERROR)
  end
end

---Replaces the current selection with the given text.
---@param text string|string[] The text to be used to replace the current selection.
M.buffer_replace_selection = function(text)
  local range = M.get_visual_range()
  if not range then
    return
  end

  M.buffer_replace_range(text, {
    start_row = range.start_row,
    start_col = range.start_col,
    end_row = range.end_row,
    end_col = range.end_col,
  })
end

---Appends the given text to a given buffer at the provided position.
---@param text string|string[] The text to be appended to the buffer.
---@param opts {start_row: number, buffer?: number, win?: number} Options for the buffer append.
M.buffer_append_text = function(text, opts)
  local lines =
    ---@diagnostic disable-next-line: param-type-mismatch
    vim.split(type(text) == "string" and text or table.concat(text, "\n"), "\n")
  local buffer = opts.buffer
    or (opts.win and vim.api.nvim_win_get_buf(opts.win))
    or vim.api.nvim_get_current_buf()
  local start_row = opts.start_row or 0

  pcall(function()
    vim.api.nvim_buf_set_lines(buffer, start_row, start_row, false, lines)
  end)
end

---@param cmd_args table
---@return boolean
M.is_visual_mode = function(cmd_args)
  return cmd_args.range and cmd_args.range > 0
end

---@param xml_string string
---@param tag_list string[]
---@return string
M.extract_text_between_tags = function(xml_string, tag_list)
  local result = {}

  for _, tag in ipairs(tag_list) do
    local start_tag = "<" .. tag .. ">"
    local end_tag = "</" .. tag .. ">"

    local start_pos = xml_string:find(start_tag)
    while start_pos do
      local end_pos = xml_string:find(end_tag, start_pos + 1)
      if end_pos then
        local text = xml_string:sub(start_pos + #start_tag, end_pos - 1)
        table.insert(result, text)
        start_pos = xml_string:find(start_tag, end_pos + 1)
      else
        start_pos = nil
      end
    end
  end

  return M.join_lines(result)
end

---@param xml_string string
---@param tag_list string[]
---@return string
M.remove_tags = function(xml_string, tag_list)
  for _, tag in ipairs(tag_list) do
    local start_tag = "<" .. tag .. ">"
    local end_tag = "</" .. tag .. ">"
    xml_string = xml_string:gsub(start_tag, "")
    xml_string = xml_string:gsub(end_tag, "")
  end
  return xml_string
end

---Escapes special characters in a string for use in XML.
---@param str string The string to escape.
---@return string The escaped string.
M.escape_xml = function(str)
  local escaped = str:gsub("[<>&'\"]]", {
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ["&"] = "&amp;",
    ["'"] = "&apos;",
    ['"'] = "&quot;",
  })
  return escaped
end

--- Generates a random string to be used as an ID.
---
--- @return string A random string.
M.generate_random_id = function()
  return tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))
end

return M
