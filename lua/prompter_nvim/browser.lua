local M = {}

local utils = require("prompter_nvim.utils")
local Prompt = require("prompter_nvim.prompt").Prompt
local AnthropicChatRequest = require("prompter_nvim.anthropic.chat")
local OpenAiChatCompletionRequest = require("prompter_nvim.openai.chat")
local GroqChatCompletionRequest = require("prompter_nvim.groq.chat")
local GeminiChatCompletionRequest =
  require("prompter_nvim.google.generate_content")

local GenerateContentRequest =
  require("prompter_nvim.llm").GenerateContentRequest

local anthropic_api = require("prompter_nvim.anthropic.api")
local openai_api = require("prompter_nvim.openai.api")
local groq_api = require("prompter_nvim.groq.api")
local google_api = require("prompter_nvim.google.api")

local Output = require("prompter_nvim.output").Output

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")

local global_prompt_path = vim.fn.stdpath("data") .. "/prompts"

---@type Output
OUTPUT = Output:new()

---@param path string The path to start searching from
---@param root string The root directory to stop searching at
---@return string|nil The path to the .prompts directory, or nil if not found
local function find_recursive_prompts_path(path, root)
  if not path then
    return nil
  end

  -- Construct the path to the .prompts directory
  local prompt_path = path .. "/.prompts"

  -- Check if the .prompts directory exists
  if vim.fn.isdirectory(prompt_path) == 1 then
    return prompt_path
  end

  -- If we've reached the root directory, stop searching
  if path == root then
    return nil
  end

  -- Extract the parent directory path
  local parent_path = path:match("(.-)[\\/][^\\/]+$")

  -- Recursively search the parent directory
  return find_recursive_prompts_path(parent_path, root)
end

---@param prompt_path string? The path to the prompts directory.
---@return string[] A list of prompt files found.
local function get_prompt_files(prompt_path)
  -- If no path is given, return an empty list.
  if not prompt_path then
    return {}
  end

  -- Build the command to list YAML files in the prompts directory.
  local command = string.format("ls %s/*.yaml 2>/dev/null", prompt_path)

  -- Execute the command and capture the output.
  local pipe = io.popen(command)

  -- If the command fails, return an empty list.
  if not pipe then
    return {}
  end

  -- Read the output line by line and store the file paths in a table.
  local files = {}
  for file in pipe:lines() do
    table.insert(files, file)
  end

  -- Close the pipe and return the list of files.
  pipe:close()
  return files
end

---@return Prompt[] List of saved prompts.
local function get_saved_prompts()
  -- Get the current working directory and the root directory.
  local current_working_directory = vim.fn.getcwd()
  local root_directory = vim.fn.fnamemodify("/", ":p")

  -- Find the local and global prompt paths.
  local local_prompt_path =
    find_recursive_prompts_path(current_working_directory, root_directory)

  -- Get the local and global prompt files.
  local local_prompt_files = get_prompt_files(local_prompt_path)
  local global_prompt_files = get_prompt_files(global_prompt_path)

  -- Combine the local and global prompt files.
  local all_prompt_files =
    vim.list_extend(local_prompt_files, global_prompt_files)

  -- Read the prompts from the files.
  local prompts = {}
  for _, file_path in ipairs(all_prompt_files) do
    local prompt = Prompt:from_yaml(file_path)
    if prompt then
      table.insert(prompts, prompt)
    end
  end

  -- Return the prompts.
  return prompts
end

---@param prompt Prompt
---@param on_choice fun(prompt: GenerateContentRequest)
local function choose_model_and_vendor(prompt, on_choice)
  local Menu = require("nui.menu")

  local function create_menu(title, lines, on_submit)
    return Menu({
      zindex = 1000,
      relative = "editor",
      position = "50%",
      size = { width = 25, height = #lines },
      border = {
        style = "rounded",
        text = { top = " " .. title .. " ", top_align = "center" },
      },
      win_options = { winhighlight = "Normal:Normal,FloatBorder:Normal" },
    }, {
      lines = lines,
      max_width = 20,
      keymap = {
        focus_next = { "j", "<Down>", "<Tab>" },
        focus_prev = { "k", "<Up>", "<S-Tab>" },
        close = { "<Esc>", "<C-c>", "q" },
        submit = { "<CR>" },
      },
      on_submit = on_submit,
    })
  end

  local function get_models(vendor)
    if vendor == "anthropic" then
      return anthropic_api.models
    elseif vendor == "openai" then
      return openai_api.models
    elseif vendor == "groq" then
      return groq_api.models
    elseif vendor == "google" then
      return google_api.models
    else
      vim.notify(
        "Invalid vendor. Please choose either 'anthropic', 'openai' or 'groq'",
        vim.log.levels.ERROR
      )
      return {}
    end
  end

  local function on_choice_inner()
    if prompt.vendor == "anthropic" then
      on_choice(AnthropicChatRequest:new(prompt))
    elseif prompt.vendor == "openai" then
      on_choice(OpenAiChatCompletionRequest:new(prompt))
    elseif prompt.vendor == "groq" then
      on_choice(GroqChatCompletionRequest:new(prompt))
    elseif prompt.vendor == "google" then
      local request = GeminiChatCompletionRequest:from_prompt(prompt):build()
      on_choice(GenerateContentRequest:from_gemini(request))
    else
      vim.notify(
        "Invalid vendor. Please choose either 'anthropic', 'openai' or 'groq'",
        vim.log.levels.ERROR
      )
    end
  end

  local function choose_model(vendor)
    local lines = vim.tbl_map(Menu.item, get_models(vendor))
    local menu = create_menu("Choose a Model", lines, function(item)
      prompt.model = item.text
      on_choice_inner()
    end)
    vim.schedule(function()
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("<ESC>", true, false, true),
        "n",
        true
      )
      menu:mount()
    end)
  end

  local function choose_vendor()
    if type(prompt.vendor) == "string" then
      choose_model(prompt.vendor)
    elseif type(prompt.vendor) == "table" then
      local lines = vim.tbl_map(Menu.item, prompt.vendor)
      local menu = create_menu("Choose a Vendor", lines, function(item)
        prompt.vendor = item.text
        choose_model(prompt.vendor)
      end)
      vim.schedule(function()
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes("<ESC>", true, false, true),
          "n",
          true
        )
        menu:mount()
      end)
    end
  end

  choose_vendor()
end

---@param args {selected_text?: string, pre_prompt: string}
M.show_browser = function(args)
  local selected_text = args.selected_text
  local pre_prompt = args.pre_prompt
  local win_id = vim.api.nvim_get_current_win()
  local buffer_id = vim.api.nvim_get_current_buf()
  local prompts = get_saved_prompts()
  local prepend_output = ""

  ---@param entry {value: {name: string}, name: string}
  local entry_maker = function(entry)
    return {
      value = entry,
      display = entry.name,
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
    ---@param entry {value: {endpoint: string}}
    preview_fn = function(_, entry, status)
      local json_object = entry.value
      local previewer_buffer = vim.api.nvim_win_get_buf(status.preview_win)
      local content = {}
      local prompt = AnthropicChatRequest:new(json_object)
      local template_params = {
        buffer = buffer_id,
        win = win_id,
        content = pre_prompt,
      }
      if selected_text and #selected_text > 0 then
        template_params.content = template_params.content
          .. "\n"
          .. selected_text
      end
      prompt:fill(template_params)
      if prompt.system then
        table.insert(content, "system: ")
        vim.list_extend(content, utils.ensure_get_lines(prompt.system))
        table.insert(content, "")
      end
      for _, message in ipairs(prompt.messages) do
        table.insert(content, message.role .. ": ")
        table.insert(content, "")
        if type(message.content) == "string" then
          for line in message.content:gmatch("[^\n]+") do
            table.insert(content, line)
          end
        elseif type(message.content) == "table" then
          for _, item in ipairs(message.content) do
            if type(item) == "table" and item.type == "text" then
              table.insert(content, item.text)
            elseif type(item) == "string" then
              table.insert(content, item)
            end
          end
        end
        table.insert(content, "")
      end
      vim.api.nvim_buf_set_lines(previewer_buffer, 0, -1, false, content)
    end,
  })

  local opts = require("telescope.themes").get_dropdown()
  opts.finder = finder
  ---@diagnostic disable-next-line: no-unknown
  opts.previewer = previewer
  opts.attach_mappings = function(buf, map)
    ---@diagnostic disable-next-line: no-unknown
    local picker = actions_state.get_current_picker(buf)
    local preview_buffer = vim.api.nvim_win_get_buf(picker.preview_win)
    ---@type number
    local prompt_buffer = picker.prompt_bufnr
    map("i", "<c-y>", function()
      vim.notify("yanked result", vim.log.levels.INFO, {})
      local text = utils.join_lines(
        vim.api.nvim_buf_get_lines(preview_buffer, 0, -1, true)
      )
      vim.fn.setreg("+", text)
      actions.close(prompt_buffer)
    end)
    map("i", "<c-p>", function()
      local text = vim.api.nvim_buf_get_lines(preview_buffer, 0, -1, true)
      utils.buffer_replace_selection(text)
      actions.close(prompt_buffer)
    end)
    actions.select_default:replace(function()
      utils.buffer_replace_content("loading...", { buffer = preview_buffer })
      ---@type {value: {endpoint: string, model: string|string[], messages: {role: string, content: string|string[]}[], tags: string[]|nil}}
      local entry = actions_state.get_selected_entry()
      local json_object = entry.value
      if json_object.messages[#json_object.messages].role == "assistant" then
        ---@type string
        prepend_output = json_object.messages[#json_object.messages].content
        vim.print({ prepend_output1 = prepend_output })
      end

      ---@param prompt GenerateContentRequest
      local send = function(prompt)
        prompt:send(function(err, output)
          vim.notify("Got response from llm")
          ---@type string?
          local text = err
            or (output.content and output.content[1] and output.content[1].text)
            or (output.choices and output.choices[1] and output.choices[1].message and output.choices[1].message.content)
            or (
              output.candidates
              and output.candidates[1]
              and output.candidates[1].content
              and output.candidates[1].content.parts
              and output.candidates[1].content.parts[1]
              and output.candidates[1].content.parts[1].text
            )
          if text then
            if prompt.remove_tags then
              text = utils.remove_tags(text, prompt.remove_tags)
            elseif prompt.extract_tags then
              text = utils.extract_text_between_tags(text, prompt.extract_tags)
            end
            if prompt.unescape_xml then
              text = utils.unescape_xml(text)
            end
            if vim.api.nvim_buf_is_valid(preview_buffer) then
              -- utils.buffer_add_content(text, { buffer = preview_buffer })
              utils.buffer_replace_content(
                vim.trim(text),
                { buffer = preview_buffer }
              )
            end
            vim.print({ output2 = OUTPUT.add_content })
            OUTPUT:add_content(os.date("%Y-%m-%d %H:%M:%S"), text)
          end
        end)
      end
      choose_model_and_vendor(entry.value, send)
    end)
    return true
  end

  pickers
    .new(opts, {
      prompt_title = "prompter",
      ---@diagnostic disable-next-line: no-unknown
      sorter = conf.generic_sorter(opts),
    })
    :find()
end

return M
