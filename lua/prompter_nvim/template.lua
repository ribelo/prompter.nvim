---@diagnostic disable-next-line: no-unknown
local pf = require("plenary.filetype")
local config = require("prompter_nvim.config")
local utils = require("prompter_nvim.utils")

local M = {}

---Gets basic parameters to fill the template
---@param opts? { buffer?: number; win?: number }
local function get_basic_params(opts)
	local params = {}

	params.cwd = vim.fn.getcwd(utils.get_win_id(opts))
	params.filepath = vim.api.nvim_buf_get_name(utils.get_buffer_id(opts))
	params.filename = params.filepath:match(".+/([^/]+)$")
	---@type string
	params.filetype = pf.detect_from_extension(params.filepath)

	return params
end

---Fill template with appropriate data
---@param text string|string[]
---@param opts? table
---@returns string
M.fill_template = function(text, opts)
	local params = vim.tbl_extend("force", opts or {}, config.template_params or {}, get_basic_params(opts))
	---@param key string
	---@param value string
	for key, value in pairs(params) do
		text = text:gsub("{{" .. key .. "}}", value)
	end
	return text
end

return M
