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

---@param args table
---@param cb function
M.completion_prompt = function(args, cb)
	--Define necessary variables
	local prompt = args.args or nil
	local is_visual_mode = args.range > 0
	local range = utils.smart_get_text_range({ is_visual_mode = is_visual_mode, context_size = config.context_size })
	local text = vim.api.nvim_buf_get_text(0, range.start_row, range.start_col, range.end_row, range.end_col, {})
	local mark_id

	-- Create the prompt depending on prompt being nil or not
	if prompt then
		prompt = prompt .. "\n" .. table.concat(text, "\n")
	else
		prompt = table.concat(text)
	end

	-- Setextmark for sign
	local extmark_opts = {
		sign_text = config.sign_text,
		sign_hl_group = config.sign_hl,
	}
	mark_id = vim.api.nvim_buf_set_extmark(0, ns_id, range.start_row, range.start_col, extmark_opts)

	-- Get result of openai call and delete mark if applicable
	local on_result = function(err, output)
		vim.api.nvim_buf_del_extmark(0, ns_id, mark_id)
		if err then
			vim.notify(err, vim.log.levels.ERROR, {})
		else
			cb(output, range)
		end
	end

	-- Parameters for openai call
	local body = {
		prompt = prompt,
		temperature = config.temperature or 1.0,
		model = config.completion_model or "text-davinci-003",
		max_tokens = config.max_tokens or 256,
	}
	-- Make the openai call
	openai.call("completions", body, on_result)
end

M.prompter_continue = function(args)
	M.completion_prompt(args, function(output, range)
		---@type string|string[]
		local text = output.choices[1].text
		local start_row = range.end_row + 1

		-- Ensure text is an array of strings and append to buffer
		utils.buffer_append_text(utils.ensure_get_lines(text), { start_row = start_row })
	end)
end

M.prompter_replace = function(args)
	M.completion_prompt(args, function(output, range)
		---@type string|string[]
		local text = vim.trim(output.choices[1].text)
		text = utils.ensure_get_lines(text)
		utils.buffer_replace_range(text, range)
	end)
end

M.prompter_edit = function(args)
	---@type string?
	local prompt = args.args

	if not prompt or prompt == "" then
		vim.notify("Edit only available with instruction prompt", vim.log.levels.ERROR, {})
		return
	end

	local is_visual_mode = args.range > 0

	if not is_visual_mode then
		vim.notify("Edit only available in visual mode", vim.log.levels.ERROR, {})
		return
	end

	-- Get the text range of the selection
	local range = utils.smart_get_text_range({ is_visual_mode = is_visual_mode, context_size = config.context_size })

	-- Get text from the range
	local text = vim.api.nvim_buf_get_text(0, range.start_row, range.start_col, range.end_row, range.end_col, {})

	-- Set ext mark with given sign text & highlight group
	local extmark_opts = {
		sign_text = config.sign_text,
		sign_hl_group = config.sign_hl,
	}
	local mark_id = vim.api.nvim_buf_set_extmark(0, ns_id, range.start_row, range.start_col, extmark_opts)

	-- Callbacks when we get result of edit
	local on_result = function(err, output)
		vim.api.nvim_buf_del_extmark(0, ns_id, mark_id) -- delete the ext mark

		-- Notify error if fail
		if err then
			vim.notify(err, vim.log.levels.ERROR, {})
		-- Replace selection with response text
		else
			utils.buffer_replace_selection(vim.trim(output.choices[1].text), {})
		end
	end

	-- Construct body for api call
	local body = {
		input = utils.ensure_get_text(text),
		instruction = prompt,
		temperature = config.temperature or 1.0,
		model = config.edit_model or "text-davinci-edit-001",
	}

	--Api call
	openai.call("edits", body, on_result)
end

return M
