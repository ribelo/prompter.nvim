local nio = require("nio")

local M = {}

--- Represents the visually selected text.
---
--- @class Selection
--- @field content string The selected text as a single string.
--- @field range table A table containing the start and end positions of the selection.
local Selection = {}
Selection.__index = Selection
M.Selection = Selection

--- Creates a new Selection instance.
---
--- @param content string The selected text.
--- @param range table The range of the selection.
--- @return Selection A new Selection instance.
function Selection:new(content, range)
  return setmetatable({
    content = content,
    range = range,
  }, { __index = self })
end

--- Returns the visually selected text as a Selection instance.
---
--- @return Selection|nil The selected text as a Selection instance, or nil if no text is selected.
function Selection:get_selected_text()
  local _, srow, scol = unpack(vim.fn.getpos("v"))
  local _, erow, ecol = unpack(vim.fn.getpos("."))

  -- Handle visual line mode (V)
  if vim.fn.mode() == "V" then
    -- Ensure srow is always less than erow for consistent logic
    if srow > erow then
      srow, erow = erow, srow
    end
    -- Get lines from the buffer using the API
    return Selection:new(
      table.concat(vim.api.nvim_buf_get_lines(0, srow - 1, erow, true), "\n"),
      { start_line = srow, start_col = scol, end_line = erow, end_col = ecol }
    )
  end

  -- Handle regular visual mode (v)
  if vim.fn.mode() == "v" then
    -- Determine if selection is forward or backward
    if srow < erow or (srow == erow and scol <= ecol) then
      -- Get text from the buffer using the API for forward selection
      return Selection:new(
        table.concat(
          vim.api.nvim_buf_get_text(0, srow - 1, scol - 1, erow - 1, ecol, {}),
          "\n"
        ),
        { start_line = srow, start_col = scol, end_line = erow, end_col = ecol }
      )
    else
      -- Get text from the buffer using the API for backward selection
      return Selection:new(
        table.concat(
          vim.api.nvim_buf_get_text(0, erow - 1, ecol - 1, srow - 1, scol, {}),
          "\n"
        ),
        { start_line = erow, start_col = ecol, end_line = srow, end_col = scol }
      )
    end
  end

  -- Handle visual block mode (\22)
  if vim.fn.mode() == "\22" then
    local lines = {}
    -- Ensure srow and scol are always less than erow and ecol
    if srow > erow then
      srow, erow = erow, srow
    end
    if scol > ecol then
      scol, ecol = ecol, scol
    end
    -- Iterate through each line in the block
    for i = srow, erow do
      -- Get the line from the buffer and extract the relevant part based on scol and ecol
      table.insert(
        lines,
        vim.api.nvim_buf_get_lines(0, i - 1, i, true)[1]:sub(scol, ecol)
      )
    end
    return Selection:new(
      table.concat(lines, "\n"),
      { start_line = srow, start_col = scol, end_line = erow, end_col = ecol }
    )
  end
end

--- Represents a single content block within a file.
---
--- @class ContentBlock
--- @field tag string? XML tag of the content block.
--- @field description string? Description of the content block.
--- @field content string Content of the content block.
--- @field instruction string? Optional instruction for the LLM specific to this content block.
--- @field start_line integer Starting line number of the content block (1-based).
--- @field start_col integer Starting column number of the content block (1-based).
--- @field end_line integer Ending line number of the content block (1-based).
--- @field end_col integer Ending column number of the content block (1-based).
-- Define the ContentBlock class
local ContentBlock = {}
ContentBlock.__index = ContentBlock
M.ContentBlock = ContentBlock

--- Creates a new ContentBlock instance from the provided data.
---
--- @param data ContentBlock Data to initialize the ContentBlock with.
--- @return ContentBlock New ContentBlock instance with the provided data.
function ContentBlock:new(data)
  return setmetatable(data or {}, { __index = self })
end

--- Creates a new ContentBlock instance from the current selection.
---
--- @return ContentBlock? New ContentBlock instance containing the selection.
function ContentBlock:from_selection()
  local selection = Selection:get_selected_text()
  if selection then
    local content_block = ContentBlock:new({
      tag = nil,
      description = nil,
      content = selection.content,
      instructions = nil,
      start_line = selection.range.start_line,
      start_col = selection.range.start_col,
      end_line = selection.range.end_line,
      end_col = selection.range.end_col,
    })
    return content_block
  end
  return nil
end

--- Sets the description of the content block.
---
--- @param tag string? XML tag of the content block.
function ContentBlock:set_tag(tag)
  self.tag = tag
end

--- Sets the description of the content block.
---
--- @param description string? Description of the content block.
function ContentBlock:set_description(description)
  self.description = description
end

--- Sets the instruction for the LLM specific to this content block.
---
--- @param instruction string Instruction for the LLM.
function ContentBlock:set_instruction(instruction)
  self.instruction = instruction
end

--- Represents a file containing content blocks.
---
--- @class SourceFile
--- @field uri string URI of the file within the project.
--- @field cwd string Absolute path to the project's root directory.
--- @field filetype string Programming language or file type (e.g., "python", "javascript", "html").
--- @field content_blocks ContentBlock[] List of content blocks within the file.
--- @field diagnostics Diagnostic[] List of content blocks within the file.
-- Define the SourceFile class
local SourceFile = {}
SourceFile.__index = SourceFile
M.SourceFile = SourceFile

--- Creates a new SourceFile instance with default values.
---
--- @return SourceFile New SourceFile instance with default values.
function SourceFile:default()
  local current_buffer = vim.api.nvim_get_current_buf()
  local obj = setmetatable({}, { __index = self })
  obj.uri = vim.uri_from_bufnr(current_buffer)
  obj.cwd = vim.fn.getcwd()
  obj.filetype = vim.bo[current_buffer].filetype
  obj.content_blocks = {}
  obj.diagnostics = {}
  return obj
end

--- Adds a content block to the source file.
---
--- @param content_block ContentBlock The content block to add.
--- @return SourceFile The current SourceFile instance for method chaining.
function SourceFile:add_content_block(content_block)
  table.insert(self.content_blocks, content_block)
  return self
end

--- Adds a diagnostic to the source file.
---
--- @param diagnostic Diagnostic The content block to add.
--- @return SourceFile The current SourceFile instance for method chaining.
function SourceFile:add_diagnostic(diagnostic)
  table.insert(self.diagnostics, diagnostic)
  return self
end

--- Creates a new SourceFile instance from the current selection.
---
--- @return SourceFile? New SourceFile instance containing the selection.
function SourceFile.from_selection()
  local content_block = ContentBlock:from_selection()
  if content_block then
    local self = SourceFile:default()
    self:add_content_block(content_block)
    return self
  end
  return nil
end

--- Reads the content of a file and creates a SourceFile instance.
---
--- @param file_path string The path to the file to be read.
--- @return SourceFile|nil The SourceFile instance if successful, nil otherwise.
function SourceFile:read_file(file_path)
  local content, err = nio.fn.readfile(file_path)
  if err then
    vim.notify(
      "Failed to read file: " .. err,
      vim.log.levels.ERROR,
      { title = "Cerebro" }
    )
    return nil
  end

  local uri = vim.uri_from_fname(file_path)
  local cwd = vim.fn.getcwd()
  local filetype = vim.filetype.match({ filename = file_path }) or ""

  local source_file = SourceFile:default()
  source_file.uri = uri
  source_file.cwd = cwd
  source_file.filetype = filetype

  local content_block = ContentBlock:new({
    content = table.concat(content, "\n"),
    start_line = 1,
    start_col = 1,
    end_line = #content,
    end_col = #content[#content],
  })

  source_file:add_content_block(content_block)

  return source_file
end

--- Represents a diagnostic message, based on the format returned by Neovim.
---
--- @class Diagnostic
--- @field bufnr integer Buffer number.
--- @field code string The diagnostic code.
--- @field col integer The starting column of the diagnostic (1-based).
--- @field end_col integer The ending column of the diagnostic (1-based).
--- @field end_lnum integer The ending line of the diagnostic (1-based).
--- @field lnum integer The starting line of the diagnostic (1-based).
--- @field message string The diagnostic message.
--- @field namespace integer The namespace of the diagnostic.
--- @field severity DiagnosticSeverity The severity of the diagnostic.
--- @field source string The source of the diagnostic.
--- @field user_data table? Additional user data associated with the diagnostic.
local Diagnostic = {}
Diagnostic.__index = Diagnostic
M.Diagnostic = Diagnostic

---@enum DiagnosticSeverity
Diagnostic.DiagnosticSeverity = {
  Error = 1,
  Warning = 2,
  Information = 3,
  Hint = 4,
}

local severity_mapping = {
  [1] = "Error",
  [2] = "Warning",
  [3] = "Information",
  [4] = "Hint",
}

--- Creates a new Diagnostic instance from Neovim diagnostic data.
---
--- @param diagnostic_data table Neovim diagnostic data table.
--- @return Diagnostic New Diagnostic instance.
function Diagnostic.from_nvim_diagnostic(diagnostic_data)
  diagnostic_data.severity = severity_mapping[diagnostic_data.severity]
    or "Information"
  return Diagnostic:new(diagnostic_data)
end

--- Creates a new Diagnostic instance.
---
--- @param diagnostic_data table Data to populate the Diagnostic instance.
--- @return Diagnostic New Diagnostic instance.
function Diagnostic:new(diagnostic_data)
  ---@type table<string, any>
  local obj = setmetatable({}, { __index = self })
  for k, v in pairs(diagnostic_data) do
    obj[k] = v
  end
  return obj
end

--- Represents a prompt containing code from one or more files, along with instructions for the LLM.
---
--- @class Context
--- @field id number Unique identifier of the prompt.
--- @field description string? Optional general description for the LLM regarding the entire prompt.
--- @field instruction string? Optional general instruction for the LLM regarding the entire prompt.
--- @field files SourceFile[] List of files with content blocks.
-- Define the Prompt class
local Context = {}
Context.__index = Context
M.Context = Context

--- Creates a new Prompt instance from the provided data.
---
--- @param data Context | nil Data to initialize the Prompt with.
--- @return Context New Prompt instance with the provided data.
function Context:new(data)
  data = data or {}
  local obj = setmetatable(data, { __index = self })
  obj.id = data.id or os.time()
  obj.files = data.files or {}
  obj.description = data.description
  obj.instruction = data.instruction
  return obj
end

-- Creates a new Prompt instance pre-populated with empty project data.
---
--- @return Context New prompt instance with default values.
function Context:default()
  local data = {
    description = nil,
    instruction = nil,
    files = {},
  }
  return Context:new(data)
end

--- Adds a new file to the Context.
---
--- @param file_path string The path to the file to be added.
--- @return boolean Success True if the file was successfully added, false otherwise.
function Context:add_file(file_path)
  if not file_path or type(file_path) ~= "string" then
    vim.notify(
      "Invalid file path provided",
      vim.log.levels.ERROR,
      { title = "Cerebro" }
    )
    return false
  end

  local source_file = SourceFile:read_file(file_path)
  if not source_file then
    return false
  end

  table.insert(self.files, source_file)
  return true
end

--- Sets the description for the prompt.
---
--- @param self Context The Prompt instance.
--- @param description string? The new description for the prompt.
function Context:set_description(description)
  self.description = description
end

--- Set instruction for the prompt.
---
--- @param self Context The Prompt instance.
--- @param instruction string? The new instruction to add.
function Context:set_instruction(instruction)
  self.instruction = instruction
end

--- Retrieves a SourceFile instance based on its uri.
---
--- @param uri string The URI of the SourceFile to retrieve.
--- @return SourceFile|nil The SourceFile instance with the given URI, or nil if not found.
function Context:get_source_file(uri)
  for _, file in ipairs(self.files) do
    if file.uri == uri then
      return file
    end
  end
  return nil
end

--- @param tag string? XML tag of the content block.
--- @param description string? Description of the content block.
--- @param instruction string? Instructions for the LLM specific to this content block.
--- @return Context? Prompt instance with the added selection.
function Context:add_selection(tag, description, instruction)
  -- Get the selected text as a ContentBlock
  local content_block = ContentBlock:from_selection()
  -- If no selection is found, return without doing anything
  if not content_block then
    return
  end
  -- Set the XML tag of the code block if provided
  if tag then
    content_block:set_tag(tag)
  end
  -- Set the description of the code block if provided
  if description then
    content_block:set_description(description)
  end
  -- Set the instruction to the code block if provided
  if instruction then
    content_block:set_instruction(instruction)
  end
  -- Cast the code_block to CodeBlock for type safety
  ---@cast content_block ContentBlock
  -- Find the current file in the list of source files
  local current_file = nil
  for _, file in ipairs(self.files) do
    if file.uri == vim.api.nvim_buf_get_name(0) then
      current_file = file
      break
    end
  end
  -- If the current file is not found, create a new SourceFile from the selection
  if not current_file then
    current_file = SourceFile:default()
    -- Add the new SourceFile to the list of source files
    table.insert(self.files, current_file)
    -- Cast the current_file to SourceFile for type safety
    ---@cast current_file SourceFile
  end
  -- Add the code block to the current file
  current_file:add_content_block(content_block)
  -- Return the updated Prompt instance
  M.refresh_context_buffer()
  return self
end

--- Removes and returns the last selection from the context.
---
--- @return ContentBlock|nil The last selection, or nil if no selections exist.
function Context:pop_last()
  local current_uri = vim.uri_from_bufnr(vim.api.nvim_get_current_buf())
  for i, file in ipairs(self.files) do
    if file.uri == current_uri then
      local last_block = table.remove(file.content_blocks)
      if #file.content_blocks == 0 then
        table.remove(self.files, i)
      end
      M.refresh_context_buffer()
      return last_block
    end
  end
  return nil
end

--- Adds diagnostic to the prompt.
---
--- @param diagnostic table Neovim diagnostic data map.
--- @return Context Prompt instance with added diagnostics.
function Context:add_diagnostic(diagnostic)
  local current_file = self:get_source_file(vim.uri_from_bufnr(0))
  if not current_file then
    current_file = SourceFile:default()
    table.insert(self.files, current_file)
  end
  current_file:add_diagnostic(diagnostic)
  M.refresh_context_buffer()
  return self
end

--- Adds diagnostics to the prompt.
---
--- @param diagnostics table[] Neovim diagnostics array.
--- @return Context Prompt instance with added diagnostics.
function Context:add_diagnostics(diagnostics)
  for _, diagnostic in ipairs(diagnostics) do
    self:add_diagnostic(diagnostic)
  end
  return self
end

--- Clears the prompt, resetting it to its default state.
---
--- @return Context The cleared Prompt instance.
function Context:clear()
  self.description = nil
  self.instruction = nil
  self.files = {}
  M.refresh_context_buffer()
  return self
end

local function escape_xml(s)
  return (
    s:gsub("&", "&amp;")
      :gsub("<", "&lt;")
      :gsub(">", "&gt;")
      :gsub("'", "&apos;")
      :gsub('"', "&quot;")
  )
end

function Context:to_xml()
  local parts = { "<context>" }

  if self.instruction then
    table.insert(
      parts,
      string.format("<instruction>%s</instruction>", self.instruction)
    )
  end

  for _, file in ipairs(self.files) do
    table.insert(parts, string.format('<file uri="%s">', file.uri))
    if file.filetype then
      table.insert(
        parts,
        string.format("<filetype>%s</filetype>", file.filetype)
      )
    end

    for _, content_block in ipairs(file.content_blocks) do
      table.insert(parts, "<block>")
      if content_block.description then
        table.insert(
          parts,
          string.format(
            "<description>%s</description>",
            content_block.description
          )
        )
      end
      if content_block.instruction then
        table.insert(
          parts,
          string.format(
            "<instruction>%s</instruction>",
            content_block.instruction
          )
        )
      end
      table.insert(parts, "<content>")
      table.insert(parts, string.format("<%s>", content_block.tag or "default"))
      table.insert(parts, content_block.content)
      table.insert(
        parts,
        string.format("</%s>", content_block.tag or "default")
      )
      table.insert(parts, "</content>")
      table.insert(
        parts,
        string.format("<start_line>%d</start_line>", content_block.start_line)
      )
      table.insert(
        parts,
        string.format("<start_col>%d</start_col>", content_block.start_col)
      )
      table.insert(
        parts,
        string.format("<end_line>%d</end_line>", content_block.end_line)
      )
      table.insert(
        parts,
        string.format("<end_col>%d</end_col>", content_block.end_col)
      )
      table.insert(parts, "</block>")
    end

    for _, diagnostic in ipairs(file.diagnostics) do
      table.insert(parts, "<diagnostic>")
      if diagnostic.message then
        table.insert(
          parts,
          string.format("<message>%s</message>", diagnostic.message)
        )
      end
      if diagnostic.code then
        table.insert(parts, string.format("%s", diagnostic.code))
      end
      if diagnostic.source then
        table.insert(
          parts,
          string.format("<source>%s</source>", diagnostic.source)
        )
      end
      if diagnostic.severity then
        table.insert(
          parts,
          string.format(
            "<severity>%s</severity>",
            tostring(diagnostic.severity)
          )
        )
      end
      table.insert(
        parts,
        string.format("<start_line>%d</start_line>", diagnostic.lnum)
      )
      table.insert(
        parts,
        string.format("<start_col>%d</start_col>", diagnostic.col)
      )
      table.insert(
        parts,
        string.format("<end_line>%d</end_line>", diagnostic.end_lnum)
      )
      table.insert(
        parts,
        string.format("<end_col>%d</end_col>", diagnostic.end_col)
      )
      table.insert(parts, "</diagnostic>")
    end

    table.insert(parts, "</file>")
  end

  table.insert(parts, "</context>")
  return table.concat(parts, "\n")
end

local context_buf = nil
local context = Context:default()

function M.get_context()
  return context
end

function M.get_context_buffer()
  if not context_buf or not nio.api.nvim_buf_is_valid(context_buf) then
    context_buf = nio.api.nvim_create_buf(false, true)
    local context_buf_name = "prompter://context"
    nio.api.nvim_buf_set_name(context_buf, context_buf_name)

    local buf_options = {
      buftype = "nofile",
      bufhidden = "wipe",
      swapfile = false,
      filetype = "xml",
    }
    for option, value in pairs(buf_options) do
      nio.api.nvim_set_option_value(option, value, { buf = context_buf })
    end
  end
  return context_buf
end

M.open_context_window = function()
  local context_win = nio.api.nvim_open_win(0, true, {
    split = "right",
  })

  local buf = M.get_context_buffer()

  nio.api.nvim_win_set_buf(context_win, buf)
  local context_lines = vim.split(context:to_xml(), "\n")
  nio.api.nvim_buf_set_lines(buf, 0, -1, false, context_lines)

  local win_options = {
    number = false,
    relativenumber = false,
    wrap = false,
  }

  for option, value in pairs(win_options) do
    nio.api.nvim_set_option_value(option, value, { win = context_win })
  end
end

M.close_context_window = function()
  local win_id = vim.fn.win_findbuf(context_buf)[1]

  if win_id then
    nio.api.nvim_win_close(win_id, false)
  else
    vim.notify("Context window not found", vim.log.levels.WARN)
  end
end

M.toggle_context_window = function()
  local win_id = vim.fn.win_findbuf(context_buf)[1]

  if win_id then
    M.close_context_window()
  else
    M.open_context_window()
  end
end

M.refresh_context_buffer = function()
  local buf = M.get_context_buffer()
  local context_lines = vim.split(context:to_xml(), "\n")
  nio.api.nvim_buf_set_lines(buf, 0, -1, false, context_lines)
end

--- @generic T
--- @param cb fun(c: Context): T
--- @return T
M.with_global_context = function(cb)
  return cb(context)
end

M.xml_description = {
  intro = [[
# XML Structure for Code Analysis

You will receive requests in an XML format that encapsulates context, content blocks, instructions, and diagnostics for various code-related tasks. Your primary responsibility is to parse this XML structure, comprehend its contents, and generate appropriate responses tailored to the specific requirements outlined within.

This document describes in detail the XML structure used for these code analysis and modification tasks.
]],
  core = [[
## Core Elements

### `<context>`

The root element that encompasses all relevant information from user perspective about the code at hand.

- `<instruction>`: An optional tag containing a general instruction or prompt. This guides your overall approach to the task, providing high-level direction for how to process and respond to the entire context.

### `<file>`

Represents a single file within the context. This element allows for organization of code blocks and diagnostics within specific files.
- Attribute `uri`: Specifies the URI, helping to understand the file's location within a project structure.
- `<filetype>`: Specifies the file type, primarily indicating the programming language used.

### `<content_block>`

Represents a distinct block within a file. This is a crucial element as it contains the actual code you'll be working with, analyzing, or modifying.

- Location tags: `<start_line>`, `<start_col>`, `<end_line>`, `<end_col>`: These specify the exact location of the content block within the file, helping to understand its context and relationships with other content blocks.
- `<content>`: Contains the actual block content. This is the primary focus of your analysis or modification efforts.
]],
  instruction = [[
- `<instruction>`: Specific instructions or prompts related to this particular content block. This guides your actions for this specific piece of code.
]],
  description = [[
- `<description>`: Providing additional context, comment or explanation about the content block's purpose, functionality, or any other relevant details.
]],
  test = [[
- `<test>`: Indicates that the code requires test creation. Your task may involve writing appropriate test cases to ensure the code's correctness and functionality.
]],
  doc = [[
- `<doc>`: Indicates that the code needs documentation. This could involve adding comments, writing docstrings, creating function/method descriptions, or even generating separate documentation files.
]],
  hole = [[
- `<hole>`: Represents a placeholder or gap in the code that needs to be filled. Your task is to provide appropriate code to complete the functionality.
]],
  algo = [[
- `<algo>`: Indicates that the algorithm used in the code needs improvement or optimization. You should analyze the current algorithm and suggest or implement a better one.
]],
  implement = [[
- `<implement>`: Indicates that a new feature or functionality needs to be implemented. You're expected to write code to fulfill the specified requirements.
]],
  analyse = [[
- `<analyse>`: Request a comprehensive code review, including structural analysis, issue identification, and improvement suggestions.
]],
  optimize = [[
- `<optimize>`: Suggests that the code should be optimized for better performance or efficiency. Your task is to improve the code while maintaining its functionality.
]],
  refactor = [[
- `<refactor>`: Indicates that the code needs to be restructured or reorganized. The goal is to improve its internal structure without changing its external behavior.
]],
  fix = [[
- `<fix>`: Suggests there's a bug in the code that needs to be identified and fixed. You should find the issue and provide a solution.
]],
  grug = [[
- `<grug>`: Suggests that the code should be simplified to "Grug-brained Developer" style, emphasizing straightforward solutions and minimal complexity without changing its external behavior.
]],
  example = [[
  - `<example>`: Provides a specific instance or illustration that the model should follow. This is something the user wants to show as a representative case or pattern to be emulated in the response or implementation.
  ]],
  diagnostic = [[
### `<diagnostic>`
Represents a specific issue, warning, or informational message related to the source file. These diagnostics provide valuable insights into potential problems or areas that need attention.
- `<message>`: Contains a description of the diagnostic or issue. This message typically explains what the problem is or what needs attention.
- `<code>`: An optional tag containing a code or identifier associated with the diagnostic. This can help in categorizing or referencing specific types of issues.
- `<source>`: An optional tag specifying the tool or system that generated the diagnostic. This information can be useful in understanding the context and reliability of the diagnostic.
- `<severity>`: Indicates how critical or important the issue is. This helps in prioritizing which problems to address first.
- Location tags: `<start_line>`, `<start_col>`, `<end_line>`, `<end_col>`: Similar to code blocks, these specify the exact location of the issue within the source file, helping to pinpoint where attention is needed.
]],
  outro = [[
This XML structure provides a comprehensive framework for specifying various code-related tasks, from simple analyses to complex refactoring operations. Each tag is designed to convey specific information or instructions relevant to the code analysis process. Your task is to interpret this structure and respond accordingly, focusing on the particular requirements specified in each request.
]],
  project_file = [[
It represents a file that contains project-wide information, configurations, or settings relevant to the code being analyzed. This file can provide important context about the overall project structure, dependencies, or other global parameters that may influence the analysis or modifications of individual code blocks.
]],
}

--- Build XML description based on tags found in the XML string
--- @param xml_string string
--- @return string
function M.build_xml_description(xml_string)
  local description = { M.xml_description.intro, M.xml_description.core }
  --- @type table<string, boolean>
  local added_tags = {}

  for tag, content in pairs(M.xml_description) do
    if
      tag ~= "intro"
      and tag ~= "core"
      and tag ~= "outro"
      and not added_tags[tag]
    then
      if xml_string:match("<" .. tag .. "[^>]*>") then
        table.insert(description, content)
        added_tags[tag] = true
      end
    end
  end

  table.insert(description, M.xml_description.outro)

  return table.concat(description, "\n\n")
end

return M
