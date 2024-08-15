local nio = require("nio")

local M = {}

local Prompt = require("prompter_nvim.prompt").Prompt

local ClaudeMessagesRequest =
  require("prompter_nvim.anthropic.messages").MessagesRequest
local anthropic_models = require("prompter_nvim.anthropic.messages").models

local GeminiChatCompletionRequest =
  require("prompter_nvim.google.generate_content").GenerateContentRequest
local gemini_models = require("prompter_nvim.google.generate_content").models

local GenerateContentRequest =
  require("prompter_nvim.llm").GenerateContentRequest

local openai_api = require("prompter_nvim.openai.api")
local groq_api = require("prompter_nvim.groq.api")

local output = require("prompter_nvim.output")

local global_prompt_path = vim.fn.stdpath("data") .. "/prompts"

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

--- @async
--- @param prompt Prompt
--- @return string | nil, Prompt | nil
local function choose_model(prompt)
  ---@param vendor string
  ---@return string[]
  local function get_models(vendor)
    if vendor == "anthropic" then
      return anthropic_models
    elseif vendor == "openai" then
      return openai_api.models
    elseif vendor == "groq" then
      return groq_api.models
    elseif vendor == "google" then
      return gemini_models
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

  ---@type ChooserItem?
  local item = nio.ui.select(items, {
    prompt = "Choose a Model",

    ---@param item ChooserItem
    format_item = function(item)
      return item.vendor .. ": " .. item.model
    end,
  })

  if not item then
    return
  end
  prompt.model = item.model

  return item.vendor, prompt
end

---@enum Browser.ActionType
local ActionType = {
  Send = "send",
  Prepare = "prepare",
}

--- @async
--- @param context string
--- @param action Browser.ActionType | nil
M.show_browser = function(context, action)
  local action = action or ActionType.Send
  local prompts = get_saved_prompts()

  --- @type Prompt?
  local prompt = nio.ui.select(prompts, {
    prompt = "Choose a Prompt",
    format_item = function(prompt)
      return prompt.name
    end,
  })

  if not prompt then
    return
  end

  prompt:fill(context)

  --- @async
  --- @param request ClaudeMessagesRequest
  local function send(request)
    local response = request:send()
    if not response then
      return
    end
    response:log_api_usage()
    local content_string = response:get_content()
    local last_requested_message_content = prompt:last_message_content()
    if last_requested_message_content then
      for _, text in ipairs(last_requested_message_content) do
        content_string = text.content .. "\n" .. content_string
      end
    end

    local content = output.Content:new(
      content_string,
      response.total_usage,
      prompt.remove_tags
    )
    if content then
      output.with_global_output(function(o)
        o:add_content(content)
        vim.fn.setreg("a", content:cleanup())
        return nil
      end)
    end
  end

  if action == ActionType.Send then
    local vendor, prepared_prompt = choose_model(prompt)
    if prepared_prompt and vendor == "anthropic" then
      local request = ClaudeMessagesRequest:from_prompt(prompt):build()
      send(request)
    else
      vim.notify(
        "Invalid vendor. Please choose 'google'.",
        vim.log.levels.ERROR
      )
    end
  elseif action == ActionType.Prepare then
    vim.fn.setreg("+", prompt:content())
    vim.notify("Prompt prepared", vim.log.levels.INFO, { title = "Cerebro" })
  end
end

return M
