local M = {}

local utils = require("prompter_nvim.utils")
local yaml = require("prompter_nvim.yaml")
local AnthropicChatRequest = require("prompter_nvim.anthropic.chat")
local OpenAiChatCompletionRequest = require("prompter_nvim.openai.chat")
local GroqChatCompletionRequest = require("prompter_nvim.groq.chat")
local anthropic_api = require("prompter_nvim.anthropic.api")
local openai_api = require("prompter_nvim.openai.api")
local groq_api = require("prompter_nvim.groq.api")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")

local global_prompt_path = vim.fn.stdpath("data") .. "/prompts"

M.output = ""

local function find_recursive_prompts_path(path, root)
  if not path then
    return nil
  end
  ---@type string
  local prompt_path = path .. "/.prompts"
  if vim.fn.isdirectory(prompt_path) == 1 then
    return prompt_path
  elseif path == root then
    return nil
  else
    -- Extract the parent directory path
    ---@type string
    local parent_path = path:match("(.-)[\\/][^\\/]+$")
    return find_recursive_prompts_path(parent_path, root)
  end
end

local function get_prompt_files(prompt_path)
  if not prompt_path then
    return {}
  end

  -- Use Lua's io.popen to execute the glob command and capture the output
  local cmd = string.format("ls %s/*.yaml 2>/dev/null", prompt_path)
  local pipe = io.popen(cmd)
  if not pipe then
    return {}
  end

  local files = {}
  for file in pipe:lines() do
    table.insert(files, file)
  end
  pipe:close()

  return files
end

local function read_yaml(file_path)
  local file, err = io.open(file_path, "r")
  if not file then
    vim.notify(
      string.format("Failed to open file: %s", err),
      vim.log.levels.ERROR
    )
    return nil
  end

  local content = file:read("*all")
  file:close()

  local success, result = pcall(yaml.deserialize, content)
  if not success then
    vim.notify(
      string.format("Failed to parse YAML: %s", result),
      vim.log.levels.ERROR
    )
    return nil
  end

  local prompt = result
  if not prompt.name then
    prompt.name = file_path:match(".+/(.+)%..+"):gsub("_", " ")
  end

  return prompt
end

---@return {endpoint: string}[]
local function get_saved_prompts()
  local cwd = vim.fn.getcwd()
  local root = vim.fn.fnamemodify("/", ":p")
  local local_prompt_path = find_recursive_prompts_path(cwd, root)
  local local_prompt_files = get_prompt_files(local_prompt_path)
  local global_prompt_files = get_prompt_files(global_prompt_path)
  local all_prompt_files =
    vim.list_extend(local_prompt_files, global_prompt_files)

  local prompts = {}
  for _, file_path in ipairs(all_prompt_files) do
    local prompt = read_yaml(file_path)
    if prompt then
      table.insert(prompts, prompt)
    end
  end

  return prompts
end

---@param prompt {model: string|string[], vendor: string|string[]}
---@param on_choice fun(prompt: AnthropicChatRequest | OpenAiChatCompletionRequest | GroqChatCompletionRequest)
local function choose_model_and_vendor(prompt, on_choice)
  local Menu = require("nui.menu")

  ---@param title string
  ---@param lines string[]
  ---@param on_submit fun(item: NuiTree.Node)
  ---@return NuiMenu
  local create_menu = function(title, lines, on_submit)
    return Menu({
      zindex = 1000,
      relative = "editor",
      position = "50%",
      size = {
        width = 25,
        height = #lines,
      },
      border = {
        style = "rounded",
        text = {
          top = " " .. title .. " ",
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
        close = { "<Esc>", "<C-c>", "q" },
        submit = { "<CR>" },
      },
      on_submit = on_submit,
    })
  end

  local get_models = function(vendor)
    if vendor == "anthropic" then
      return anthropic_api.models
    elseif vendor == "openai" then
      return openai_api.models
    elseif vendor == "groq" then
      return groq_api.models
    else
      vim.notify(
        "Invalid vendor. Please choose either 'anthropic' or 'openai'",
        vim.log.levels.ERROR
      )
      return {}
    end
  end

  local on_choice_inner = function()
    if prompt.vendor == "anthropic" then
      on_choice(AnthropicChatRequest:new(prompt))
    elseif prompt.vendor == "openai" then
      on_choice(OpenAiChatCompletionRequest:new(prompt))
    elseif prompt.vendor == "groq" then
      on_choice(GroqChatCompletionRequest:new(prompt))
    else
      vim.notify(
        "Invalid vendor. Please choose either 'anthropic' or 'openai'",
        vim.log.levels.ERROR
      )
    end
  end

  local choose_model = function(vendor)
    local lines = vim.tbl_map(function(model)
      return Menu.item(model)
    end, get_models(vendor))
    ---@param model string
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
  local choose_vendor = function()
    if type(prompt.vendor) == "string" then
      choose_model()
      return
    end
    if type(prompt.vendor) == "table" then
      ---@param vendor string
      local lines = vim.tbl_map(function(vendor)
        return Menu.item(vendor)
      end, prompt.vendor)
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
    ---@param entry {value: {endpoint: string}}
    preview_fn = function(_, entry, status)
      local json_object = entry.value

      local previewer_buffer = vim.api.nvim_win_get_buf(status.preview_win)
      ---@type string[]
      local content = {}

      local prompt = AnthropicChatRequest:new(json_object)
      ---@type {buffer: number, win: number, content?: string}
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
        if message.role == "user" then
          table.insert(content, "user: ")
          table.insert(content, "")
        elseif message.role == "assistant" then
          table.insert(content, "assistant: ")
          table.insert(content, "")
        end

        if type(message.content) == "string" then
          ---@diagnostic disable-next-line: cast-type-mismatch, param-type-mismatch
          for line in message.content:gmatch("[^\n]+") do
            table.insert(content, line)
          end
        elseif type(message.content) == "table" then
          ---@diagnostic disable-next-line: cast-type-mismatch, param-type-mismatch
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
      end

      local send = function(prompt)
        prompt:send(function(err, output)
          ---@type string?
          vim.print({ err = err, output = output })
          local text = err
            or (output.content and output.content[1] and output.content[1].text)
            or (
              output.choices
              and output.choices[1]
              and output.choices[1].message
              and output.choices[1].message.content
            )
          if text then
            if prompt.remove_tags then
              text = utils.remove_tags(text, prompt.remove_tags)
            elseif prompt.extract_tags then
              text = utils.extract_text_between_tags(text, prompt.extract_tags)
            end
            if vim.api.nvim_buf_is_valid(preview_buffer) then
              utils.buffer_replace_content(
                vim.trim(text),
                { buffer = preview_buffer }
              )
            end
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
