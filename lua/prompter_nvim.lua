local config = require("prompter_nvim.config")
-- local browser = require("prompter_nvim.browser_back")
local browser = require("prompter_nvim.browser")
local utils = require("prompter_nvim.utils")
local context = require("prompter_nvim.context")
local output = require("prompter_nvim.output")
local nio = require("nio")
require("prompter_nvim.tools")

local M = {}

--- Show the browser window.
--- @param action Browser.ActionType | nil
M.browser = function(action)
  nio.run(function()
    -- Get the currently selected text in the Neovim buffer.
    ---@diagnostic disable-next-line: param-type-mismatch
    local selected_text = utils.get_selected_text()

    -- Show the browser with the selected text and pre-filled prompt,
    -- or with the XML context if no text is selected.
    if selected_text and selected_text ~= "" then
      browser.show_browser(table.concat(selected_text, "\n"), action)
    else
      browser.show_browser(context.get_context():to_xml(), action)
    end
  end)
end

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
  nio.run(function()
    -- Get the tag from the user.
    local tag = nio.ui.input({ prompt = "Enter tag: " })
    if tag == "" then
      tag = nil
    end

    -- Get the instruction from the user.
    local instruction = nio.ui.input({ prompt = "Enter instruction: " })

    -- Get the description from the user.
    local description = nio.ui.input({ prompt = "Enter description: " })

    -- Add the selection to the prompter.
    context.get_context():add_selection(tag, description, instruction)

    -- Notify the user that the selection has been added.
    vim.notify(
      string.format("Selection <%s> added", tag or "content"),
      vim.log.levels.INFO,
      { title = "Cerebro" }
    )

    -- Clear the command line.
    nio.api.nvim_feedkeys(
      nio.api.nvim_replace_termcodes("<Esc>", true, false, true),
      "n",
      false
    )
  end)
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
      context.get_context():add_diagnostic(diagnostic)
    end

    -- Notify the user that diagnostics have been added.
    vim.notify(
      string.format("Added <%s> diagnostics", #diagnostics),
      vim.log.levels.INFO,
      { title = "Cerebro" }
    )
  end
end

--- Adds a new selection to the prompter, without any metadata or user input.
M.fast_add_selection = function()
  -- Add an empty selection to the prompter.
  context.get_context():add_selection(nil, nil, nil)

  -- Tell the user we added a selection.
  vim.notify(
    string.format("Selection <%s> added", "content"),
    vim.log.levels.INFO,
    { title = "Cerebro" }
  )

  -- Clear the command line.
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
    "n",
    false
  )
end

M.pop_last = function()
  local last_selection = context.get_context():pop_last()

  if last_selection then
    vim.notify(
      "Last context removed",
      vim.log.levels.INFO,
      { title = "Cerebro" }
    )
  else
    vim.notify(
      "No context to remove",
      vim.log.levels.WARN,
      { title = "Cerebro" }
    )
  end
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
    context.get_context():set_description(nil)
    vim.notify(
      "Description not set",
      vim.log.levels.WARN,
      { title = "Cerebro" }
    )
    return
  end

  -- Set the description on the prompter.
  context.get_context():set_description(description)

  -- Notify the user that the description has been set.
  vim.notify(
    "Description set successfully",
    vim.log.levels.INFO,
    { title = "Cerebro" }
  )

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
    context.get_context():set_instruction(nil)
    vim.notify(
      "Instruction not set",
      vim.log.levels.WARN,
      { title = "Cerebro" }
    )
    return
  end

  -- Set the instruction on the prompter.
  context.get_context():set_instruction(instruction)

  -- Notify the user that the instruction has been set.
  vim.notify(
    "Instruction set successfully",
    vim.log.levels.INFO,
    { title = "Cerebro" }
  )

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
  context.get_context():clear()
  vim.notify("Prompt cleared", vim.log.levels.INFO, { title = "Cerebro" })
end

M.toggle_context_window = context.toggle_context_window

M.toggle_output_window = require("prompter_nvim.output").toggle_output_window

M.clear_output_buffer = function()
  output.with_global_output(function(o)
    o:clear()
    return nil
  end)
end

return M
