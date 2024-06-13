---@type table
local lyaml = require("lyaml")

---@class Prompt
---@field vendor string | string[] List of vendors.
---@field model string? Model.
---@field max_tokens integer? Maximum number of tokens.
---@field temperature number? Temperature setting.
---@field stop_sequences string[]? The set of character sequences that will stop output generation
---@field remove string[] List of string to remove.
---@field system string System message.
---@field messages Message[] List of messages.
--- Prompt class definition
local Prompt = {}
Prompt.__index = Prompt

--- @param data Prompt Initial data for TranslatorConfig.
--- @return Prompt New instance of TranslatorConfig.
function Prompt.new(data)
  data = data or {}
  setmetatable(data, Prompt)
  return data
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
function Message.new(data)
  data = data or {}
  setmetatable(data, Message)
  return data
end

--- Reads a YAML file and converts its content to a Lua table.
--- If the file cannot be opened or the content cannot be parsed, it notifies the user.
--- @param file_path string: The path to the YAML file.
--- @return table|nil: The parsed YAML content as a Lua table, or nil if an error occurs.
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
  --- @type boolean, any
  local success, result = pcall(lyaml.load, content)
  if not success then
    vim.notify(
      string.format("Failed to parse YAML: %s", result),
      vim.log.levels.ERROR
    )
    return nil
  end

  -- If the parsed YAML does not have a 'name' field, derive it from the file path.
  if not result.name then
    ---@type string
    result.name = file_path:match(".+/(.+)..+"):gsub("_", " ")
  end

  return result
end

return {
  Prompt = Prompt,
}
