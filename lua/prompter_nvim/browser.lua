local M = {}

local openai = require("prompter_nvim.openai")
local config = require("prompter_nvim.config")
local utils = require("prompter_nvim.utils")
local template = require("prompter_nvim.template")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")

local global_prompt_path = vim.fn.stdpath("data") .. "/prompts"

-- Get saved prompts from both local and global prompt paths
local function get_saved_prompts()
	local prompts = {}
	local cwd = vim.loop.cwd()
	local local_prompt_path = cwd .. "/.prompts"

	local local_prompt_files = vim.fn.glob(local_prompt_path .. "/*.json", false, true)
	local global_prompt_files = vim.fn.glob(global_prompt_path .. "/*.json", false, true)

	local all_prompt_files = vim.tbl_flatten({ local_prompt_files, global_prompt_files })
	---@param file_path string
	for _, file_path in ipairs(all_prompt_files) do
		local file = io.open(file_path, "r")
		if file then
			local content = file:read("*all")
			file:close()

			local prompt = vim.fn.json_decode(content)
			if prompt then
				table.insert(prompts, prompt)
			end
		end
	end

	return prompts
end

M.show_browser = function(args)
	local win_id = utils.get_win_id()
	local buffer_id = utils.get_buffer_id()
	local prompts = get_saved_prompts()
	---@type string[]?
	local selected_text
	if utils.is_visual_mode(args) then
		selected_text = utils.get_selected_text()
	end

	local entry_maker = function(entry)
		return {
			value = entry,
			---@type string
			display = entry.name,
			---@type string
			ordinal = entry.name,
		}
	end

	---@diagnostic disable-next-line: no-unknown
	local finder = finders.new_table({
		results = prompts,
		entry_maker = entry_maker,
	})

	---@diagnostic disable-next-line: no-unknown
	local previewer = previewers.new({
		preview_fn = function(_, entry, status)
			local previewer_buffer = vim.api.nvim_win_get_buf(status.preview_win)
			---@type string
			local text = entry.value.prompt or entry.value.instruction
			if selected_text and #selected_text > 0 then
				---@type string
				text = template.fill_template(
					text,
					{ selection = utils.join_lines(selected_text), buffer = buffer_id, win = win_id }
				)
			end
			vim.api.nvim_buf_set_lines(previewer_buffer, 0, -1, false, utils.split_text(text))
		end,
	})

	local opts = {
		---@diagnostic disable-next-line: no-unknown
		finder = finder,
		---@diagnostic disable-next-line: no-unknown
		previewer = previewer,
		attach_mappings = function(buf, map)
			---@diagnostic disable-next-line: no-unknown
			local picker = actions_state.get_current_picker(buf)
			local preview_buffer = vim.api.nvim_win_get_buf(picker.preview_win)
			---@type number
			local prompt_buffer = picker.prompt_bufnr

			map("i", "<c-y>", function()
				vim.notify("yanked result", vim.log.levels.INFO, {})
				local text = utils.join_lines(vim.api.nvim_buf_get_lines(preview_buffer, 0, -1, true))
				vim.fn.setreg("+", text)
				actions.close(prompt_buffer)
			end)

			map("i", "<c-p>", function()
				local text = vim.api.nvim_buf_get_lines(preview_buffer, 0, -1, true)
				utils.buffer_replace_selection(text, { buffer = buffer_id })
				actions.close(prompt_buffer)
			end)

			actions.select_default:replace(function()
				---@diagnostic disable-next-line: no-unknown
				local entry = actions_state.get_selected_entry()
				local prompt = utils.join_lines(vim.api.nvim_buf_get_lines(preview_buffer, 0, -1, true))
				utils.buffer_replace_content("loading...", { buffer = preview_buffer })
				local endpoint = entry.value.endpoint or "copletions"

				if prompt and prompt ~= "" then
					local body = {
						temperature = entry.value.temperature or config.temperature or 0.0,
						model = entry.value.model or config.completion_model or "text-davinci-003",
					}
					if endpoint == "completions" then
						body.prompt = prompt
						body.max_tokens = entry.value.max_tokens or config.max_tokens or 256
					elseif endpoint == "edits" then
						if selected_text then
							body.input = utils.ensure_get_text(selected_text)
						end
						body.instruction = prompt
					end
					vim.pretty_print("body", body)
					openai.call(endpoint, body, function(err, output)
						---@type string?
						local text = err or output.choices[1].text
						if text then
							if entry.value.trim_result then
								text = vim.trim(text)
							end
							if vim.api.nvim_buf_is_valid(preview_buffer) then
								utils.buffer_replace_content(text, { buffer = preview_buffer })
							end
						end
					end)
				end
			end)

			return true
		end,
	}

	pickers
		.new(opts, {
			prompt_title = "prompter",
			---@diagnostic disable-next-line: no-unknown
			sorter = conf.generic_sorter(opts),
		})
		:find()
end

return M
