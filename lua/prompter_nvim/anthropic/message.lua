---@enum ClaudeRole
local Role = {
  User = "user",
  Assistant = "assistant",
}

--- Translates a role string to its corresponding GeminiRole value.
--- Throws an error if the role is invalid.
--- @param role string The role to translate.
--- @return ClaudeRole The translated role.
function Role:from(role)
  if role == "user" then
    return Role.User
  elseif role == "model" or role == "assistant" then
    return Role.Assistant
  else
    error("Invalid role: " .. role) -- Throw an error if the role is invalid
  end
end

--- @class ClaudeBase64
--- @field media_type string,
--- @field data string
local Base64 = {}
Base64.__index = Base64

--- Create new ClaudeBase64
---@param media_type string The media type of the base64 encoded data.
---@param data string The base64 encoded data.
---@return ClaudeBase64
function Base64:new(media_type, data)
  return setmetatable(
    { media_type = media_type, data = data },
    { __index = self }
  )
end

--- @class ClaudeImageSource
--- @field base64 ClaudeBase64
local ImageSource = {}
ImageSource.__index = ImageSource

--- Create a new ClaudeImageSource instance.
---@param base64 ClaudeBase64 The base64 encoded image data.
---@return ClaudeImageSource The new ClaudeImageSource instance.
function ImageSource:new(base64)
  return setmetatable({ base64 = base64 }, { __index = self })
end

---@class ClaudeImage
---@field source ClaudeImageSource
local Image = {}
Image.__index = Image

--- Create a new ClaudeImage instance.
---@param source ClaudeImageSource The source of the image.
---@return ClaudeImage The new ClaudeImage instance.
function Image:new(source)
  return setmetatable({ source = source }, { __index = self })
end

---@class ClaudeText
---@field text string
---@field type string
local Text = {}
Text.__index = Text

--- @param text string | ClaudeText
--- @return ClaudeText
function Text:new(text)
  if type(text) == "string" then
    return setmetatable({ text = text, type = "text" }, self)
  elseif type(text) == "table" and text.__index == Text then
    --- @cast text ClaudeText
    return text
  else
    error(
      "bad argument #1 to 'Text:new' (string or ClaudeText expected, got "
        .. type(text)
        .. ")"
    )
  end
end

--- @class ClaudeToolUse
--- @field id string
--- @field name string
--- @field input table
local ToolUse = {}
ToolUse.__index = ToolUse

--- @param id string
--- @param name string
--- @param input table
--- @return ClaudeToolUse
function ToolUse:new(id, name, input)
  return setmetatable(
    { id = id, name = name, input = input },
    { __index = self }
  )
end

--- @class ClaudeToolResult
--- @field id string
--- @field content table
--- @field is_error boolean
local ToolResult = {}
ToolResult.__index = ToolResult

--- @param id string
--- @param content table
--- @param is_error boolean
--- @return ClaudeToolResult
function ToolResult:new(id, content, is_error)
  return setmetatable(
    { id = id, content = content, is_error = is_error },
    { __index = self }
  )
end

---@alias ClaudeMultiModalContent ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult

---@class ClaudeMessage
---@field role ClaudeRole
---@field content ClaudeMultiModalContent[]
---@field name? string
local Message = {}
Message.__index = Message

---@param role ClaudeRole
---@param content? ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
---@return ClaudeMessage
function Message:new(role, content)
  local obj = setmetatable({ role = role, content = {} }, { __index = self })

  if content then
    table.insert(obj.content, content)
  end

  return obj
end

---@param data? ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
---@return ClaudeMessage
function Message:user(data)
  return Message:new(Role.User, data)
end

---@param data? ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
---@return ClaudeMessage
function Message:Assistant(data)
  return Message:new(Role.Assistant, data)
end

---@param data  ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
function Message:add(data)
  table.insert(self.content, data)
end

function Message:is_empty()
  return #self.content == 0
end

function Message:serialize()
  return vim.json.encode(self)
end

return {
  Role = Role,
  Base64 = Base64,
  ImageSource = ImageSource,
  Image = Image,
  Text = Text,
  ToolUse = ToolUse,
  ToolResult = ToolResult,
  Message = Message,
}
