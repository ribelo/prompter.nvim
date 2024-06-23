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

--- Represents a single code block within a file.
---
--- @class CodeBlock
--- @field tag string? XML tag of the code block.
--- @field description string? Description of the code block.
--- @field content string Content of the code block.
--- @field instruction string? Optional instruction for the LLM specific to this code block.
--- @field start_line integer Starting line number of the code block (1-based).
--- @field start_col integer Starting column number of the code block (1-based).
--- @field end_line integer Ending line number of the code block (1-based).
--- @field end_col integer Ending column number of the code block (1-based).
-- Define the CodeBlock class
local CodeBlock = {}
CodeBlock.__index = CodeBlock
M.CodeBlock = CodeBlock

--- Creates a new CodeBlock instance from the provided data.
---
--- @param data CodeBlock Data to initialize the CodeBlock with.
--- @return CodeBlock New CodeBlock instance with the provided data.
function CodeBlock:new(data)
  return setmetatable(data or {}, { __index = self })
end

--- Creates a new CodeBlock instance from the current selection.
---
--- @return CodeBlock? New CodeBlock instance containing the selection.
function CodeBlock:from_selection()
  local selection = Selection:get_selected_text()
  if selection then
    local code_block = CodeBlock:new({
      tag = nil,
      description = nil,
      content = selection.content,
      instructions = nil,
      start_line = selection.range.start_line,
      start_col = selection.range.start_col,
      end_line = selection.range.end_line,
      end_col = selection.range.end_col,
    })
    return code_block
  end
  return nil
end

--- Sets the description of the code block.
---
--- @param tag string? XML tag of the code block.
function CodeBlock:set_tag(tag)
  self.tag = tag
end

--- Sets the description of the code block.
---
--- @param description string? Description of the code block.
function CodeBlock:set_description(description)
  self.description = description
end

--- Sets the instruction for the LLM specific to this code block.
---
--- @param instruction string Instruction for the LLM.
function CodeBlock:set_instruction(instruction)
  self.instruction = instruction
end

--- Represents a file containing code blocks.
---
--- @class SourceFile
--- @field path string Relative path to the file within the project.
--- @field cwd string Absolute path to the project's root directory.
--- @field filetype string Programming language or file type (e.g., "python", "javascript", "html").
--- @field code_blocks CodeBlock[] List of code blocks within the file.
--- @field diagnostics Diagnostic[] List of code blocks within the file.
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
  obj.path = vim.api.nvim_buf_get_name(current_buffer)
  obj.cwd = vim.fn.getcwd()
  obj.filetype = vim.bo[current_buffer].filetype
  obj.code_blocks = {}
  obj.diagnostics = {}
  return obj
end

--- Adds a code block to the source file.
---
--- @param code_block CodeBlock The code block to add.
--- @return SourceFile The current SourceFile instance for method chaining.
function SourceFile:add_code_block(code_block)
  table.insert(self.code_blocks, code_block)
  return self
end

--- Adds a diagnostic to the source file.
---
--- @param diagnostic Diagnostic The code block to add.
--- @return SourceFile The current SourceFile instance for method chaining.
function SourceFile:add_diagnostic(diagnostic)
  table.insert(self.diagnostics, diagnostic)
  return self
end

--- Creates a new SourceFile instance from the current selection.
---
--- @return SourceFile? New SourceFile instance containing the selection.
function SourceFile.from_selection()
  local code_block = CodeBlock:from_selection()
  if code_block then
    local self = SourceFile:default()
    self:add_code_block(code_block)
    return self
  end
  return nil
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
--- @field files SourceFile[] List of files with code blocks.
-- Define the Prompt class
local Context = {}
Context.__index = Context
M.Context = Context

--- Creates a new Prompt instance from the provided data.
---
--- @param data Context Data to initialize the Prompt with.
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

--- Retrieves a SourceFile instance based on its path.
---
--- @param path string The path of the SourceFile to retrieve.
--- @return SourceFile|nil The SourceFile instance with the given path, or nil if not found.
function Context:get_source_file(path)
  for _, file in ipairs(self.files) do
    if file.path == path then
      return file
    end
  end
  return nil
end

--- @param tag string? XML tag of the code block.
--- @param description string? Description of the code block.
--- @param instruction string? Instructions for the LLM specific to this code block.
--- @return Context? Prompt instance with the added selection.
function Context:add_selection(tag, description, instruction)
  -- Get the selected text as a CodeBlock
  local code_block = CodeBlock:from_selection()
  -- If no selection is found, return without doing anything
  if not code_block then
    return
  end
  -- Set the XML tag of the code block if provided
  if tag then
    code_block:set_tag(tag)
  end
  -- Set the description of the code block if provided
  if description then
    code_block:set_description(description)
  end
  -- Set the instruction to the code block if provided
  if instruction then
    code_block:set_instruction(instruction)
  end
  -- Cast the code_block to CodeBlock for type safety
  ---@cast code_block CodeBlock
  -- Find the current file in the list of source files
  local current_file = nil
  for _, file in ipairs(self.files) do
    if file.path == vim.api.nvim_buf_get_name(0) then
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
  current_file:add_code_block(code_block)
  -- Return the updated Prompt instance
  return self
end

--- Adds diagnostic to the prompt.
---
--- @param diagnostic table Neovim diagnostic data map.
--- @return Context Prompt instance with added diagnostics.
function Context:add_diagnostic(diagnostic)
  local current_file = nil
  for _, file in ipairs(self.files) do
    if file.path == vim.api.nvim_buf_get_name(0) then
      current_file = file
      break
    end
  end
  if not current_file then
    current_file = SourceFile:default()
    table.insert(self.files, current_file)
    ---@cast current_file SourceFile
  end
  current_file:add_diagnostic(diagnostic)
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
  return self
end

--- Displays the prompt in a beautifully formatted Markdown string.
---
--- @return string The formatted Markdown string representing the prompt.
function Context:to_markdown()
  ---@type string
  local markdown = "# Context\n\n"

  -- ## General Instructions
  -- This section displays any general instructions provided for the prompt.
  if self.instruction and self.instruction ~= "" then
    markdown = markdown .. "## Instruction\n\n"
    markdown = markdown .. self.instruction .. "\n\n"
  end

  -- ## Source Files
  -- This section displays the source files with code blocks and their respective descriptions, instructions, and diagnostics.
  for i, file in ipairs(self.files) do
    markdown = markdown .. "## " .. "File nr: " .. i .. "\n\n"
    if file.path or file.cwd or file.filetype then
      markdown = markdown .. "### File Metadata \n\n"
      markdown = markdown .. "- path: " .. file.path .. "\n"
      markdown = markdown .. "- cwd: " .. file.cwd .. "\n"
      markdown = markdown .. "- filetype: " .. file.filetype .. "\n"
    end

    -- ### Code Blocks
    -- This section displays the code blocks within each source file.
    for j, code_block in ipairs(file.code_blocks) do
      markdown = markdown .. "### Code Block nr: " .. j .. "\n\n"

      markdown = markdown .. "#### Code Block Metadata \n\n"
      markdown = markdown .. "- start_line: " .. code_block.start_line .. "\n"
      markdown = markdown .. "- start_col: " .. code_block.start_col .. "\n"
      markdown = markdown .. "- end_line: " .. code_block.end_line .. "\n"
      markdown = markdown .. "- end_col: " .. code_block.end_col .. "\n\n"

      if code_block.description and code_block.description ~= "" then
        markdown = markdown .. "#### Description" .. "\n\n"
        markdown = markdown .. code_block.description .. "\n\n"
      end

      -- #### Instructions
      -- This section displays any instructions specific to a code block.
      if code_block.instruction and code_block.instruction ~= "" then
        markdown = markdown .. "#### Code Block Instruction\n\n"
        markdown = markdown .. code_block.instruction .. "\n\n"
      end

      -- Code block content
      markdown = markdown .. "```" .. file.filetype .. "\n"
      markdown = markdown .. code_block.content .. "\n"
      markdown = markdown .. "```\n\n"
    end

    -- ### Diagnostics
    -- This section displays any diagnostics related to a source file.
    if file.diagnostics and #file.diagnostics > 0 then
      markdown = markdown .. "### Diagnostics\n\n"
      for _, diagnostic in ipairs(file.diagnostics) do
        markdown = markdown
          .. "- **"
          .. diagnostic.severity
          .. ":** "
          .. diagnostic.message
          .. "\n"
      end
      markdown = markdown .. "\n"
    end
  end

  return markdown
end

--- Returns the prompt as a pretty-formatted JSON string.
---
--- @return string JSON string representing the prompt.
function Context:to_json()
  return vim.fn.json_encode(self)
end

---
--- Converts the prompt to an XML string suitable for passing to an LLM.
---
--- @param self Context
--- @return string XML representation of the prompt.
function Context:to_xml()
  local xml = "<context>\n"
  if self.instruction and self.instruction ~= "" then
    xml = xml .. "<instruction>" .. self.instruction .. "</instruction>\n"
  end

  for _, file in ipairs(self.files) do
    xml = xml .. '<file path="' .. file.path .. '">\n'
    if file.filetype then
      xml = xml .. "<filetype>" .. file.filetype .. "</filetype>\n"
    end
    if #file.code_blocks > 0 then
      for _, code_block in ipairs(file.code_blocks) do
        xml = xml .. "<code_block>\n"
        if code_block.description and code_block.description ~= "" then
          xml = xml
            .. "<description>"
            .. code_block.description
            .. "</description>\n"
        end
        if code_block.instruction and code_block.instruction ~= "" then
          xml = xml
            .. "<instruction>"
            .. code_block.instruction
            .. "</instruction>\n"
        end
        xml = xml .. "<content>\n"
        if code_block.tag and code_block.tag ~= "" then
          xml = xml .. "<" .. code_block.tag .. ">"
        end
        xml = xml .. code_block.content
        if code_block.tag and code_block.tag ~= "" then
          xml = xml .. "</" .. code_block.tag .. ">"
        end
        xml = xml .. "\n</content>\n"
        xml = xml
          .. "<start_line>"
          .. code_block.start_line
          .. "</start_line>\n"
        xml = xml .. "<start_col>" .. code_block.start_col .. "</start_col>\n"
        xml = xml .. "<end_line>" .. code_block.end_line .. "</end_line>\n"
        xml = xml .. "<end_col>" .. code_block.end_col .. "</end_col>\n"
        xml = xml .. "</code_block>\n"
      end
    end
    if #file.diagnostics > 0 then
      for _, diagnostic in ipairs(file.diagnostics) do
        xml = xml .. "<diagnostic>\n"
        if diagnostic.message then
          xml = xml .. "<message>\n" .. diagnostic.message .. "</message>\n"
        end
        if diagnostic.code then
          xml = xml .. "<code>\n" .. diagnostic.code .. "</code>\n"
        end
        if diagnostic.source then
          xml = xml .. "<source>\n" .. diagnostic.source .. "</source>\n"
        end
        if diagnostic.severity then
          xml = xml
            .. "<severity>\n"
            .. severity_mapping[diagnostic.severity]
            .. "</severity>\n"
        end
        xml = xml .. "<start_line>" .. diagnostic.lnum .. "</start_line>\n"
        xml = xml .. "<start_col>" .. diagnostic.col .. "</start_col>\n"
        xml = xml .. "<end_line>" .. diagnostic.end_lnum .. "</end_line>\n"
        xml = xml .. "<end_col>" .. diagnostic.end_col .. "</end_col>\n"
        xml = xml .. "</diagnostic>\n"
      end
    end
    xml = xml .. "</file>\n"
  end

  xml = xml .. "</context>\n"
  return xml
end

M.xml_description = {
  intro = [[
# XML Structure for Code Analysis

You will receive requests in an XML format that encapsulates context, code blocks, instructions, and diagnostics for various code-related tasks. Your primary responsibility is to parse this XML structure, comprehend its contents, and generate appropriate responses tailored to the specific requirements outlined within.

This document describes in detail the XML structure used for these code analysis and modification tasks.
]],
  core = [[
## Core Elements

### `<context>`

The root element that encompasses all relevant information from user perspective about the code at hand.

- `<instruction>`: An optional tag containing a general instruction or prompt. This guides your overall approach to the task, providing high-level direction for how to process and respond to the entire context.

### `<file>`

Represents a single file within the context. This element allows for organization of code blocks and diagnostics within specific files.
- Attribute `path`: Specifies the file path, helping to understand the file's location within a project structure.
- `<filetype>`: Specifies the file type, primarily indicating the programming language used.

### `<code_block>`

Represents a distinct block of code within a file. This is a crucial element as it contains the actual code you'll be working with, analyzing, or modifying.

- Location tags: `<start_line>`, `<start_col>`, `<end_line>`, `<end_col>`: These specify the exact location of the code block within the file, helping to understand its context and relationships with other code blocks.
- `<content>`: Contains the actual code content. This is the primary focus of your analysis or modification efforts.
]],
  instruction = [[
- `<instruction>`: Specific instructions or prompts related to this particular code block. This guides your actions for this specific piece of code.
]],
  description = [[
- `<description>`: Providing additional context, comment or explanation about the code block's purpose, functionality, or any other relevant details.
]],
  test = [[
- `<test>`: Indicates that the code requires test creation. Your task may involve writing appropriate test cases to ensure the code's correctness and functionality.
]],
  document = [[
- `<document>`: Indicates that the code needs documentation. This could involve adding comments, writing docstrings, creating function/method descriptions, or even generating separate documentation files.
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
- `<grug>`: Suggests that the code should be simplified to "Grug-brained Developer" style, emphasizing straightforward solutions and minimal complexity.
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
