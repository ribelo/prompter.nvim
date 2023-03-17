local M = {}

local utils = require("prompter_nvim.utils")
local Prompt = require("prompter_nvim.prompt")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")

local global_prompt_path = vim.fn.stdpath("data") .. "/prompts"

local function find_recursive_prompts_path(path, root)
	local prompt_path = path .. "/.prompts"
	if vim.fn.isdirectory(prompt_path) == 1 then
		return prompt_path
	elseif path == root then
		return nil
	else
		return find_recursive_prompts_path(path:match("(.-)[\\/][^\\/]+$"), root)
	end
end

local function get_prompt_files(prompt_path)
	if not prompt_path then
		return {}
	else
		return vim.fn.glob(prompt_path .. "/*.json", false, true)
	end
end

local function read_json(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*all")
	file:close()

	return vim.fn.json_decode(content)
end

---@return Prompt[]
local function get_saved_prompts()
	local cwd = vim.loop.cwd()
	local root = vim.loop.fs_realpath("/") or "/"

	local local_prompt_path = find_recursive_prompts_path(cwd, root)
	local local_prompt_files = get_prompt_files(local_prompt_path)

	local global_prompt_files = get_prompt_files(global_prompt_path)

	local all_prompt_files = vim.tbl_flatten({ local_prompt_files, global_prompt_files })

	local prompts = {}
	for _, file_path in ipairs(all_prompt_files) do
		local json_object = read_json(file_path)
		local prompt = Prompt:new(json_object)
		if prompt then
			table.insert(prompts, prompt)
		end
	end

	return prompts
end

---@param models string|string[]
---@param on_choice fun(model: string)
local function choice_model(models, on_choice)
	if type(models) == "string" then
		on_choice(models)
	elseif type(models) == "table" then
		local Menu = require("nui.menu")
		---@param model string
		local lines = vim.tbl_map(function(model)
			return Menu.item(model)
		end, models)

		local menu = Menu({
			zindex = 1000,
			relative = "editor",
			position = "50%",
			size = {
				width = 25,
				height = 5,
			},
			border = {
				style = "rounded",
				text = {
					top = " Choose a Model ",
					top_align = "center",
				},
			},
			win_options = {
				winhighlight = "Normal:Normal,FloatBorder:Normal",
			},
		}, {
			lines = lines,
			max_width = 20,
			keymap = {
				focus_next = { "j", "<Down>", "<Tab>" },
				focus_prev = { "k", "<Up>", "<S-Tab>" },
				close = { "<Esc>", "<C-c>" },
				submit = { "<CR>" },
			},
			on_submit = function(item)
				on_choice(item.text)
			end,
		})
		vim.schedule(function()
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<ESC>", true, false, true), "n", true)
			menu:mount()
		end)
	end
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
		---@param entry {value: Prompt}
		preview_fn = function(_, entry, status)
			local prompt = entry.value
			local previewer_buffer = vim.api.nvim_win_get_buf(status.preview_win)
			---@type string[]
			local content = {}
			local template_params = { buffer = buffer_id, win = win_id }
			if selected_text and #selected_text > 0 then
				template_params.selection = utils.join_lines(selected_text)
			end
			prompt:fill(template_params)
			for _, message in ipairs(prompt.messages) do
				if message.role == "system" then
					table.insert(content, "system: ")
					table.insert(content, "")
				elseif message.role == "user" then
					table.insert(content, "user: ")
					table.insert(content, "")
				elseif message.role == "assistant" then
					table.insert(content, "assistant: ")
					table.insert(content, "")
				end
				for line in message.content:gmatch("[^\n]+") do
					table.insert(content, line)
				end
				table.insert(content, "")
			end
			vim.api.nvim_buf_set_lines(previewer_buffer, 0, -1, false, content)
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
				utils.buffer_replace_content("loading...", { buffer = preview_buffer })
				---@type {value: Prompt}
				local entry = actions_state.get_selected_entry()
				local prompt = entry.value
				local send = function(model)
					if not model then
						return
					end
					prompt.model = model
					prompt:send(function(err, output)
						vim.pretty_print("output", output)
						---@type string?
						local text = err or output.choices[1].text or output.choices[1].message.content
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
				choice_model(entry.value.model, send)
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
