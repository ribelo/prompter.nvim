local utils = require("prompter_nvim.utils")

local M = {}

M.add_tag = function()
  local range = utils.get_visual_range()
  local tag = vim.fn.input("Enter tag: ")

  if range then
    local selected_text = vim.api.nvim_buf_get_text(
      0,
      range.start_row,
      range.start_col,
      range.end_row,
      range.end_col,
      {}
    )
    local text = table.concat(selected_text, "\n")

    local wrapped_text = string.format("<%s>\n%s\n</%s>", tag, text, tag)
    vim.api.nvim_buf_set_text(
      0,
      range.start_row,
      range.start_col,
      range.end_row,
      range.end_col - 1,
      vim.split(wrapped_text, "\n")
    )

    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
      "n",
      false
    )
  else
    vim.api.nvim_put(
      { string.format("<%s>%s</%s>", tag, "true", tag) },
      "c",
      false,
      true
    )
  end
end

return M
