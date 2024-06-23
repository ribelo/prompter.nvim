---@type table
local lyaml = require("lyaml")

local context = require("prompter_nvim.context")

---@class Prompt
---@field file_path string Prompt file path.
---@field name string Prompt name.
---@field vendor string[] List of vendors.
---@field model? string Model.
---@field max_tokens? integer Maximum number of tokens.
---@field temperature? number Temperature setting.
---@field stop_sequences? string[] The set of character sequences that will stop output generation
---@field remove_tags? string[] List of string to remove.
---@field system string System message.
---@field messages Message[] List of messages.
---@field tools? string[]
--- Prompt class definition
local Prompt = {}
Prompt.__index = Prompt

--- @param data Prompt Initial data for TranslatorConfig.
--- @return Prompt New instance of TranslatorConfig.
function Prompt:new(data)
  return setmetatable(data or {}, { __index = self })
end

---@class Message
---@field role string Role of the message sender
---@field content string Content of the message.
--- Message class definition
---
local Message = {}
Message.__index = Message

--- @param data Message Initial data for Message.
--- @return Message New instance of Message.
function Message:new(data)
  return setmetatable(data or {}, { __index = self })
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

  -- If the parsed YAML does not have a 'name' field, derive it from the file path.
  if not prompt.name then
    ---@type string
    prompt.name = file_path:match("^.+/(.+)%..+$"):gsub("_", " ")
  end

  prompt.file_path = file_path

  return result
end

--- Get the content of the last message
--- @return string? Content of the last message, or nil if there are no messages
function Prompt:last_message_content()
  if #self.messages == 0 then
    return nil
  end
  local last_message = self.messages[#self.messages]
  return last_message.role ~= "user" and last_message.content or nil
end

---@class BasicBufferParams
---@field buffnr integer Buffer number
---@field winnr integer Window number
---@field cwd string Current working directory
---@field filename string Filename
---@field filetype string File type
---@field commentstring string Comment string
local BasicBufferParams = {}
BasicBufferParams.__index = BasicBufferParams

---@param content string
function Prompt:fill(content)
  -- Loop through all message and replace content.
  for _, message in ipairs(self.messages) do
    message.content = message.content:gsub("{{context}}", content)
    message.content = message.content:gsub(
      "{{xml_description}}",
      context.build_xml_description(content)
    )
  end

  -- Replace context in system message.
  if self.system then
    self.system = self.system:gsub("{{context}}", content)
    self.system = self.system:gsub(
      "{{xml_description}}",
      context.build_xml_description(content)
    )
  end
end

return {
  Prompt = Prompt,
}
