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
local function choose_model(prompt, on_choice)
  ---@param vendor string
  ---@return string[]
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

  ---@class ChooserItem
  ---@field vendor string
  ---@field model string
  local items = {}

  for _, vendor in ipairs(prompt.vendor) do
    for _, model in ipairs(get_models(vendor)) do
      table.insert(items, { vendor = vendor, model = model })
    end
  end

  vim.ui.select(
    items,
    {
      prompt = "Choose a Model",

      ---@param item ChooserItem
      format_item = function(item)
        return item.vendor .. ": " .. item.model
      end,
    },
    ---@param item ChooserItem?
    function(item)
      if not item then
        return
      end
      prompt.model = item.model

      if item.vendor == "google" then
        local request = GeminiChatCompletionRequest:from_prompt(prompt):build()
        on_choice(GenerateContentRequest:from_gemini(request))
      else
        vim.notify(
          "Invalid vendor. Please choose 'google'.",
          vim.log.levels.ERROR
        )
      end
    end
  )
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

  local opts = require("telescope.themes").get_dropdown()
  opts.finder = finder
  opts.attach_mappings = function(buf, map)
    ---@diagnostic disable-next-line: no-unknown
    local picker = actions_state.get_current_picker(buf)
    ---@type number
    local prompt_buffer = picker.prompt_bufnr
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
      choose_model(entry.value, send)
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
