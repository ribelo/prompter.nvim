---@diagnostic disable-next-line: no-unknown
local pf = require("plenary.filetype")
local config = require("prompter_nvim.config")
local utils = require("prompter_nvim.utils")

local M = {}

---Gets basic parameters to fill the template
---@param opts? { buffer?: number; win?: number }
local function get_basic_params(opts)
  local params = {}
  local buffnr = vim.api.nvim_get_current_buf()
  local winnr = vim.api.nvim_get_current_win()

  params.cwd = vim.fn.getcwd(winnr)
  params.filepath = vim.api.nvim_buf_get_name(buffnr)
  params.filename = params.filepath:match(".+/([^/]+)$")
  ---@type string
  params.filetype = pf.detect_from_extension(params.filepath)
  ---@type string
  params.commentstring =
    -- vim.api.nvim_get_option_value("commentstring", {}):gsub("%%s", "")
    vim.api.nvim_buf_get_option(buffnr, "commentstring"):gsub("%%s", "")

  return params
end

---Fill template with appropriate data
---@param text string|string[]
---@param opts? table
---@returns string
M.fill_template = function(text, opts)
  local params = vim.tbl_extend(
    "force",
    opts or {},
    config.template_params or {},
    get_basic_params(opts)
  )
  ---@param k string
  ---@param v string
  for k, v in pairs(params) do
    ---@type any
    local value
    if type(v) == "function" then
      ---@diagnostic disable-next-line: no-unknown
      value = v(text, opts)
    else
      value = v
    end
    ---@diagnostic disable-next-line: no-unknown
    text = text:gsub("{{" .. k .. "}}", value)
  end
  return text
end

return M
