local config = require("prompter_nvim.config")
-- local browser = require("prompter_nvim.browser_back")
local browser = require("prompter_nvim.browser")
local utils = require("prompter_nvim.utils")
local Context = require("prompter_nvim.context").Context
local Output = require("prompter_nvim.output").Output
require("prompter_nvim.tools")

-- local command = require("prompter_nvim.command")

---@type Context
CONTEXT = Context:default()

---@type Output
OUTPUT = Output:default()

local M = {}

--- Show the browser window.
M.browser = function()
  -- Get the currently selected text in the Neovim buffer.
  local selected_text = utils.join_lines(utils.get_selected_text())

  -- Show the browser with the selected text and pre-filled prompt,
  -- or with the XML context if no text is selected.
  if selected_text and selected_text ~= "" then
    browser.show_browser(selected_text)
  else
    browser.show_browser(CONTEXT:to_xml())
  end
end

-- M.prompter_continue = command.prompter_continue
-- M.prompter_replace = command.prompter_replace
-- M.prompter_edit = command.prompter_edit

local function mkdir(path)
  vim.fn.mkdir(path)
end

local function exists(path)
  ---@type any
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil
end

local function create_dir(path)
  if exists(path) then
    return
  end
  mkdir(path)
end

create_dir(config.get().global_prompts_path)

M.setup = function(opts)
  config.set(opts)
end

--- Adds a new selection to the prompter.
---
--- This function prompts the user for a tag, instruction, and description,
--- then adds a new selection with the provided information.
M.add_selection_with_meta = function()
  -- Get the tag from the user.
  local tag = vim.fn.input("Enter tag: ")
  if tag == "" then
    tag = nil
  end
  vim.wait(100, function() end) -- Small delay for better user experience

  -- Get the instruction from the user.
  local instruction = vim.fn.input("Enter instruction: ")
  vim.wait(100, function() end) -- Small delay for better user experience

  -- Get the description from the user.
  local description = vim.fn.input("Enter description: ")

  -- Add the selection to the prompter.
  CONTEXT:add_selection(tag, description, instruction)

  -- Notify the user that the selection has been added.
  vim.notify(
    string.format("Selection <%s> added", tag or "content"),
    vim.log.levels.INFO
  )

  -- Clear the command line.
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
    "n",
    false
  )
end

--- Adds a diagnostic to the prompter.
---
--- This function retrieves diagnostics from the current cursor position
--- and adds them to the prompter.
M.add_diagnostic = function()
  -- Get the current cursor position.
  local cursor_position = vim.api.nvim_win_get_cursor(0)

  -- Get diagnostics for the current line. Note the offset for line numbers in lua.
  local diagnostics = vim.diagnostic.get(
    0,
    { lnum = cursor_position[1] - 1, col = cursor_position[2] }
  )

  -- If there are any diagnostics, add them to the prompter.
  if #diagnostics > 0 then
    for _, diagnostic in ipairs(diagnostics) do
      CONTEXT:add_diagnostic(diagnostic)
    end

    -- Notify the user that diagnostics have been added.
    vim.notify(
      string.format("Added <%s> diagnostics", #diagnostics),
      vim.log.levels.INFO
    )
  end
end

--- Adds a new selection to the prompter, without any metadata or user input.
M.fast_add_selection = function()
  -- Add an empty selection to the prompter.
  CONTEXT:add_selection(nil, nil, nil)

  -- Tell the user we added a selection.
  vim.notify(
    string.format("Selection <s> added", "content"),
    vim.log.levels.INFO
  )

  -- Clear the command line.
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
    "n",
    false
  )
end

--- Sets the description for the prompter.
---
--- Prompts the user for a description and sets it on the prompter.
--- If the user cancels the input, the description is set to nil.
M.set_description = function()
  -- Prompt the user for a description.
  local description = vim.fn.input("Enter description: ")

  -- If the user cancels the input, set description to nil.
  if description == "" then
    CONTEXT:set_description(nil)
    vim.notify("Description not set", vim.log.levels.WARN)
    return
  end

  -- Set the description on the prompter.
  CONTEXT:set_description(description)

  -- Notify the user that the description has been set.
  vim.notify("Description set successfully", vim.log.levels.INFO)

  -- Exit insert mode.
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
    "n",
    false
  )
end

--- Sets the instruction for the prompter.
---
--- Prompts the user for an instruction and sets it on the prompter.
--- If the user cancels the input, the instruction is set to nil.
M.set_instruction = function()
  -- Prompt the user for an instruction.
  local instruction = vim.fn.input("Enter instruction: ")

  -- If the user cancels the input, set instruction to nil.
  if instruction == "" then
    CONTEXT:set_instruction(nil)
    vim.notify("Instruction not set", vim.log.levels.WARN)
    return
  end

  -- Set the instruction on the prompter.
  CONTEXT:set_instruction(instruction)

  -- Notify the user that the instruction has been set.
  vim.notify("Instruction set successfully", vim.log.levels.INFO)

  -- Exit insert mode.
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
    "n",
    false
  )
end

--- Clears the prompter's prompt.
---
--- This function clears the prompt displayed by the prompter and
--- notifies the user with a success message.
M.clear_prompt = function()
  CONTEXT:clear()
  vim.notify("Prompt cleared")
end

M.open_prompt_as_markdown = function()
  -- Create a new window on the right
  local prompt_win = vim.api.nvim_open_win(0, true, {
    -- relative = "win",
    win = 0,
    split = "right",
  })
  -- Create a new buffer
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(prompt_win, prompt_buf)

  -- Set the contents of the prompt buffer to the prompt_chunks
  local prompt_lines = vim.split(CONTEXT:to_markdown(), "\n")
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, prompt_lines)
  -- Set the buffer options
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = prompt_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = prompt_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = prompt_buf })

  -- Setn the buffer name
  local prompt_buf_name = "prompter://prompt"
  vim.api.nvim_buf_set_name(prompt_buf, prompt_buf_name)

  -- Set the filetype to markdown
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = prompt_buf })
  -- Set the window options
  vim.api.nvim_set_option_value("number", false, { win = prompt_win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = prompt_win })
  vim.api.nvim_set_option_value("wrap", false, { win = prompt_win })
end

M.open_prompt_as_json = function()
  -- Create a new window on the right
  local prompt_win = vim.api.nvim_open_win(0, true, {
    -- relative = "win",
    win = 0,
    split = "right",
  })
  -- Create a new buffer
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(prompt_win, prompt_buf)

  -- Set the contents of the prompt buffer to the prompt_chunks
  local prompt_lines = vim.split(CONTEXT:to_json(), "\n")
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, prompt_lines)
  -- Set the buffer options
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = prompt_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = prompt_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = prompt_buf })

  -- Setn the buffer name
  local prompt_buf_name = "prompter://prompt"
  vim.api.nvim_buf_set_name(prompt_buf, prompt_buf_name)

  -- Set the filetype to markdown
  vim.api.nvim_set_option_value("filetype", "json", { buf = prompt_buf })
  -- Set the window options
  vim.api.nvim_set_option_value("number", false, { win = prompt_win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = prompt_win })
  vim.api.nvim_set_option_value("wrap", false, { win = prompt_win })
end

M.open_prompt_as_xml = function()
  -- Create a new window on the right
  local prompt_win = vim.api.nvim_open_win(0, true, {
    -- relative = "win",
    win = 0,
    split = "right",
  })
  -- Create a new buffer
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(prompt_win, prompt_buf)

  -- Set the contents of the prompt buffer to the prompt_chunks
  local prompt_lines = vim.split(CONTEXT:to_xml(), "\n")
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, prompt_lines)
  -- Set the buffer options
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = prompt_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = prompt_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = prompt_buf })

  -- Setn the buffer name
  local prompt_buf_name = "prompter://prompt"
  vim.api.nvim_buf_set_name(prompt_buf, prompt_buf_name)

  -- Set the filetype to markdown
  vim.api.nvim_set_option_value("filetype", "xml", { buf = prompt_buf })
  -- Set the window options
  vim.api.nvim_set_option_value("number", false, { win = prompt_win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = prompt_win })
  vim.api.nvim_set_option_value("wrap", false, { win = prompt_win })
end

M.close_prompt_buffer = function()
  -- Find the prompt buffer by name
  local prompt_buf_name = "prompter://prompt"
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == prompt_buf_name then
      -- Delete the prompt buffer
      vim.api.nvim_buf_delete(buf, { force = true })

      -- Close the window associated with the prompt buffer
      local wins = vim.api.nvim_list_wins()
      for _, win in ipairs(wins) do
        if vim.api.nvim_win_get_buf(win) == buf then
          vim.api.nvim_win_close(win, false)
          break
        end
      end
      break
    end
  end
end

M.toggle_markdown_buffer = function()
  -- Find the prompt buffer by name
  local prompt_buf_name = "prompter://prompt"

  local prompt_buf_exists = false

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == prompt_buf_name then
      prompt_buf_exists = true

      break
    end
  end

  if prompt_buf_exists then
    M.close_prompt_buffer()
  else
    M.open_prompt_as_markdown()
  end
end

M.toggle_json_buffer = function()
  -- Find the prompt buffer by name
  local prompt_buf_name = "prompter://prompt"

  local prompt_buf_exists = false

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == prompt_buf_name then
      prompt_buf_exists = true

      break
    end
  end

  if prompt_buf_exists then
    M.close_prompt_buffer()
  else
    M.open_prompt_as_json()
  end
end

M.toggle_xml_buffer = function()
  -- Find the prompt buffer by name
  local prompt_buf_name = "prompter://prompt"

  local prompt_buf_exists = false

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == prompt_buf_name then
      prompt_buf_exists = true

      break
    end
  end

  if prompt_buf_exists then
    M.close_prompt_buffer()
  else
    M.open_prompt_as_xml()
  end
end

M.toggle_output_window = require("prompter_nvim.output").toggle_output_window
M.clear_output_buffer = require("prompter_nvim.output").clear_output_buffer

return M
