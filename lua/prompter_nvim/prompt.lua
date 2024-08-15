---@type table
local lyaml = require("lyaml")

local context = require("prompter_nvim.context")
local Project = require("prompter_nvim.project").Project

--- @class Text
--- @field content string
--- @field cache boolean | nil
--- Text class definition
---
local Text = {}
Text.__index = Text

--- @param text string | nil
function Text:new(text)
  return setmetatable({ content = text }, { __index = self })
end

--- @class Message
--- @field role string Role of the message sender
--- @field content Text[] Content of the message.
--- Message class definition
---
local Message = {}
Message.__index = Message

--- @param data Message | nil Initial data for Message.
--- @return Message New instance of Message.
function Message:new(data)
  return setmetatable(data or {}, { __index = self })
end

--- @param new_content string | string[] | Text Content to be added
--- @return Message The updated message instance
function Message:add_content(new_content)
  self.content = self.content or {}

  if type(new_content) == "table" and not getmetatable(new_content) then
    for _, content in ipairs(new_content) do
      table.insert(self.content, Text:new(content))
    end
  elseif type(new_content) == "table" and new_content.__index == Text then
    table.insert(self.content, new_content)
  else
    --- @cast new_content string
    table.insert(self.content, Text:new(new_content))
  end

  return self
end

--- Insert content at a specific index in the message
--- @param idx number The index at which to insert the content
--- @param new_content string | string[] | Text Content to be inserted
--- @return Message The updated message instance
function Message:insert_content(idx, new_content)
  self.content = self.content or {}

  local function insert_content(content)
    if type(content) == "table" and not getmetatable(content) then
      for i = #content, 1, -1 do
        table.insert(self.content, idx, Text:new(content[i]))
      end
    elseif type(content) == "table" and content.__index == Text then
      table.insert(self.content, idx, content)
    else
      table.insert(self.content, idx, Text:new(content))
    end
  end

  insert_content(new_content)

  return self
end

--- @class Prompt
--- @field file_path string Prompt file path.
--- @field name string Prompt name.
--- @field vendor string[] List of vendors.
--- @field model string | nil Model.
--- @field max_tokens integer | nil Maximum number of tokens.
--- @field temperature number | nil Temperature setting.
--- @field stop_sequences string[] | nil The set of character sequences that will stop output generation
--- @field remove_tags string[] | nil List of string to remove.
--- @field system string System message.
--- @field messages Message[] List of messages.
--- @field tools string[] | nil
--- @field project boolean | nil
--- Prompt class definition
local Prompt = {}
Prompt.__index = Prompt

--- @param data Prompt Initial data for Prompt.
--- @return Prompt New instance of Prompt.
function Prompt:new(data)
  local obj = setmetatable(data or {}, { __index = self })
  obj.messages = obj.messages or { Message:new() }

  -- Convert existing messages to Message objects
  for i, msg in ipairs(obj.messages) do
    if type(msg) == "table" and not getmetatable(msg) then
      obj.messages[i] = Message:new(msg)
    end
  end

  return obj
end

--- Reads a YAML file and converts its content to a Lua table.
--- If the file cannot be opened or the content cannot be parsed, it notifies the user.
--- @param file_path string: The path to the YAML file.
--- @return Prompt?: The parsed YAML content as a Lua table, or nil if an error occurs.
function Prompt:from_yaml(file_path)
  -- Attempt to open the file in read mode.
  local file, err = io.open(file_path, "r")
  if not file then
    vim.notify(
      string.format("Failed to open file: %s", err),
      vim.log.levels.ERROR
    )
    return nil
  end

  -- Read the entire content of the file.
  local content = file:read("*all")
  file:close()

  -- Attempt to parse the content as YAML.
  --- @type boolean, Prompt?
  local success, result = pcall(lyaml.load, content)
  if not success then
    vim.notify(
      string.format("Failed to parse YAML: %s", result),
      vim.log.levels.ERROR
    )
    return nil
  end

  ---@cast result Prompt
  local prompt = Prompt:new(result)
  for _, message in ipairs(prompt.messages) do
    ---@diagnostic disable-next-line: param-type-mismatch
    message.content = { Text:new(message.content) }
  end

  -- If the parsed YAML does not have a 'name' field, derive it from the file path.
  if not prompt.name then
    ---@type string
    prompt.name = file_path:match("^.+/(.+)%..+$"):gsub("_", " ")
  end

  prompt.file_path = file_path

  return result
end

--- Get the content of the last message
--- @return Text[] | nil Content of the last message, or nil if there are no messages
function Prompt:last_message_content()
  if #self.messages == 0 then
    return nil
  end
  local last_message = self.messages[#self.messages]
  return last_message.role ~= "user" and last_message.content or nil
end

--- @class BasicBufferParams
--- @field buffnr integer Buffer number
--- @field winnr integer Window number
--- @field cwd string Current working directory
--- @field filename string Filename
--- @field filetype string File type
--- @field commentstring string Comment string
local BasicBufferParams = {}
BasicBufferParams.__index = BasicBufferParams

---@param content string
function Prompt:fill(content)
  local function replace_placeholders(text)
    return text:gsub("{{context}}", content):gsub(
      "# XML Structure for Code Analysis.*",
      context.build_xml_description(content)
    )
  end

  local function inject_project_content()
    if self.project then
      local project = Project:new()
      project:load_config()
      local project_content = Text:new(project:to_xml())
      project_content.cache = true
      self.messages[1]:insert_content(1, project_content)
    end
  end

  inject_project_content()

  for _, message in ipairs(self.messages) do
    for i, text in ipairs(message.content) do
      message.content[i].content = replace_placeholders(text.content)
    end
  end

  if self.system then
    self.system = replace_placeholders(self.system)
  end
end

function Prompt:content()
  local content = {}

  if self.system then
    table.insert(
      content,
      "<system>\n" .. vim.trim(self.system) .. "\n</system>"
    )
  end

  table.insert(content, "<messages>")
  for _, message in ipairs(self.messages) do
    local message_content = type(message.content) == "table"
        and table.concat(message.content, "\n")
      or message.content
    --- @cast message_content string
    table.insert(
      content,
      string.format(
        '<message role="%s">\n%s\n</message>',
        message.role,
        vim.trim(message_content)
      )
    )
  end
  table.insert(content, "</messages>")

  return vim.trim(table.concat(content, "\n"))
end

return {
  Prompt = Prompt,
}
