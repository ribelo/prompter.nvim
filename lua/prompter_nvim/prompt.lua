---@diagnostic disable-next-line: no-unknown
local pf = require("plenary.filetype")
local openai = require("prompter_nvim.openai")
local config = require("prompter_nvim.config")
local utils = require("prompter_nvim.utils")

---@enum endpoints
local ENDPOINTS = {
	"completions",
	"edits",
	"chat/completions",
}

---@enum roles
local ROLES = {
	"system",
	"user",
	"assistent",
}

---Gets basic parameters to fill the template
---@param opts? { buffer?: number; win?: number }
local function get_basic_params(opts)
	local params = {}
	local buffnr = utils.get_buffer_id(opts)

	params.cwd = vim.fn.getcwd(utils.get_win_id(opts))
	params.filepath = vim.api.nvim_buf_get_name(buffnr)
	params.filename = params.filepath:match(".+/([^/]+)$")
	---@type string
	params.filetype = pf.detect_from_extension(params.filepath)
	---@type string
	params.commentstring = vim.api.nvim_buf_get_option(buffnr, "commentstring"):gsub("%%s", "")

	return params
end

---Fill template with appropriate data
---@param text string|string[]
---@param params? table
---@returns string
local function fill_template(text, params)
	vim.pretty_print("template", params)
	params = vim.tbl_extend("force", params or {}, config.template_params or {}, get_basic_params(params))
	---@param k string
	---@param v string
	for k, v in pairs(params) do
		---@type any
		local value
		if type(v) == "function" then
			---@diagnostic disable-next-line: no-unknown
			value = v(text, params)
		else
			value = v
		end
		---@diagnostic disable-next-line: no-unknown
		text = text:gsub("{{" .. k .. "}}", value)
	end
	return text
end

---@alias message {role: roles, content: string}
---@alias on_result fun(err: string, output: string)

---@class Prompt
---@field endpoint endpoints
---@field model string|string[]
---@field messages message[]
---@field name string
---@field temperature? number
---@field top_p? number
---@field n? number
---@field stop? string|string[]
---@field max_tokens? number
---@field presence_penalty? number
---@field frequency_penalty? number
---@field logit_bias? table
---@field user? string
---@field trim_result? boolean
local Prompt = {}
Prompt.__index = Prompt

function Prompt:new(o)
	return setmetatable(o, self)
end

---@param on_result fun(err: string, response: CompletionsResponse|EditsResponse|ChatResponse)
function Prompt:send(on_result)
	local body = {
		model = self.model,
		messages = self.messages,
	}
	if self.temperature then
		body.temperature = self.temperature
	end
	if self.top_p then
		body.top_p = self.top_p
	end
	if self.n then
		body.n = self.n
	end
	if self.stop then
		body.stop = self.stop
	end
	if self.max_tokens then
		body.max_tokens = self.max_tokens
	end
	if self.presence_penalty then
		body.presence_penalty = self.presence_penalty
	end
	if self.frequency_penalty then
		body.frequency_penalty = self.frequency_penalty
	end
	if self.logit_bias then
		body.logit_bias = self.logit_bias
	end
	if self.user then
		body.user = self.user
	end
	openai.call(self.endpoint, body, on_result)
end

---@param params table?
function Prompt:fill(params)
	if self.endpoint == "chat/completions" then
		for _, message in ipairs(self.messages) do
			message.content = fill_template(message.content, params)
		end
	else
		assert(false, "not implemented: " .. self.endpoint)
	end
end

return Prompt
