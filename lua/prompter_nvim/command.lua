local openai = require("prompter_nvim.openai")
local config = require("prompter_nvim.config")
local utils = require("prompter_nvim.utils")
local browser = require("prompter_nvim.browser")

local M = {}
local ns_id = vim.api.nvim_create_namespace("")

local function get_prompt_from_args(args)
	local prompt = ""

	-- Iterate over the arguments
	---@param arg string
	for _, arg in ipairs(args.fargs) do
		-- Append the argument to the prompt
		prompt = prompt .. arg .. " "
	end

	-- Trim any trailing whitespace
	return vim.trim(prompt)
end

M.completion_prompt = function(args, cb)
	---@type string?
	local prompt = args.args
	local is_visual_mode = args.range > 0
	local range = utils.smart_get_text_range({ is_visual_mode = is_visual_mode, context_size = config.context_size })
	local text = vim.api.nvim_buf_get_text(0, range.start_row, range.start_col, range.end_row, range.end_col, {})

	if prompt and prompt:len() > 0 then
		prompt = prompt .. "\n"
		for _, x in ipairs(text) do
			prompt = prompt .. x .. "\n"
		end
	else
		for _, x in ipairs(text) do
			prompt = prompt .. x
		end
	end

	local extmark_opts = {
		sign_text = config.sign_text,
		sign_hl_group = config.sign_hl,
	}

	local mark_id = vim.api.nvim_buf_set_extmark(0, ns_id, range.start_row, range.start_col, extmark_opts)

	local on_result = function(err, output)
		vim.api.nvim_buf_del_extmark(0, ns_id, mark_id)
		if err then
			vim.notify(err, vim.log.levels.ERROR, {})
		else
			cb(output, range)
		end
	end
	local body = {
		prompt = prompt,
		temperature = config.temperature or 1.0,
		model = config.completion_model or "text-davinci-003",
		max_tokens = config.max_tokens or 256,
	}
	openai.call("completions", body, on_result)
end

M.prompter_continue = function(args)
	M.completion_prompt(args, function(output, range)
		---@type string|string[]
		local text = output.choices[1].text
		text = utils.ensure_get_lines(text)
		utils.buffer_append_text(text, { start_row = range.end_row - 1 })
	end)
end

M.prompter_replace = function(args)
	M.completion_prompt(args, function(output, range)
		---@type string|string[]
		local text = vim.trim(output.choices[1].text)
		text = (utils.ensure_get_lines(text))
		utils.buffer_replace_range(text, range)
	end)
end

M.prompter_edit = function(args)
	---@type string?
	local prompt = args.args

	if not prompt or prompt == "" then
		vim.notify("edit only available with instruction prompt", vim.log.levels.ERROR, {})
		return
	end

	local is_visual_mode = args.range > 0

	if not is_visual_mode then
		vim.notify("edit only available in visual mode", vim.log.levels.ERROR, {})
		return
	end

	local range = utils.smart_get_text_range({ is_visual_mode = is_visual_mode, context_size = config.context_size })
	local text = vim.api.nvim_buf_get_text(0, range.start_row, range.start_col, range.end_row, range.end_col, {})

	local extmark_opts = {
		sign_text = config.sign_text,
		sign_hl_group = config.sign_hl,
	}

	local mark_id = vim.api.nvim_buf_set_extmark(0, ns_id, range.start_row, range.start_col, extmark_opts)

	local on_result = function(err, output)
		vim.api.nvim_buf_del_extmark(0, ns_id, mark_id)
		if err then
			vim.notify(err, vim.log.levels.ERROR, {})
		else
			utils.buffer_replace_selection(vim.trim(output.choices[1].text), {})
		end
	end
	local body = {
		input = utils.ensure_get_text(text),
		instruction = prompt,
		temperature = config.temperature or 1.0,
		model = config.edit_model or "text-davinci-edit-001",
	}
	openai.call("edits", body, on_result)
end

return M
