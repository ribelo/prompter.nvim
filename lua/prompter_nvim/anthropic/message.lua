---@enum ClaudeRole
local Role = {
  USER = "user",
  ASSISTANT = "assistant",
}

---@enum Cerebro.Anthropic.CacheType
local CacheType = {
  EPHEMERAL = "ephemeral",
}

--- @class Cerebro.Anthropic.CacheControl
--- @field type Cerebro.Anthropic.CacheType
local CacheControl = {}
CacheControl.__index = CacheControl
---
---@return Cerebro.Anthropic.CacheControl
function CacheControl:enable()
  return setmetatable({ type = CacheType.EPHEMERAL }, { __index = self })
end

--- Translates a role string to its corresponding GeminiRole value.
--- Throws an error if the role is invalid.
--- @param role string The role to translate.
--- @return ClaudeRole The translated role.
function Role:from(role)
  if role == "user" then
    return Role.USER
  elseif role == "model" or role == "assistant" then
    return Role.ASSISTANT
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

--- @class ClaudeImage
--- @field source ClaudeImageSource
--- @field type string
--- @field cache_control Cerebro.Anthropic.CacheControl | nil
local Image = {}
Image.__index = Image

--- Create a new ClaudeImage instance.
---@param source ClaudeImageSource The source of the image.
---@return ClaudeImage The new ClaudeImage instance.
function Image:new(source)
  return setmetatable({ type = "image", source = source }, { __index = self })
end

--- @class ClaudeText
--- @field text string
--- @field type string
--- @field cache_control Cerebro.Anthropic.CacheControl | nil
local Text = {}
Text.__index = Text

--- @param text string | ClaudeText
--- @return ClaudeText
function Text:new(text)
  if type(text) == "string" then
    return setmetatable({ type = "text", text = text }, self)
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

function Text:cache()
  self.cache_control = CacheControl:enable()
  return self
end

--- @class ClaudeToolUse
--- @field id string
--- @field name string
--- @field input table
--- @field type string
--- @field cache_control Cerebro.Anthropic.CacheControl | nil
local ToolUse = {}
ToolUse.__index = ToolUse

--- @param data table
--- @return ClaudeToolUse
function ToolUse:new(data)
  return setmetatable(data, { __index = self })
end

--- @class ClaudeToolResult
--- @field tool_use_id string
--- @field content ClaudeMultiModalContent[]
--- @field is_error boolean
--- @field type string
--- @field cache_control Cerebro.Anthropic.CacheControl | nil
local ToolResult = {}
ToolResult.__index = ToolResult

--- @param data table
--- @return ClaudeToolResult
function ToolResult:new(data)
  return setmetatable(data, { __index = self })
end

--- @param id string
--- @param content ClaudeMultiModalContent
--- @return ClaudeToolResult
function ToolResult:success(id, content)
  return setmetatable({
    type = "tool_result",
    tool_use_id = id,
    content = { content },
    is_error = false,
  }, { __index = self })
end

--- @param id string
--- @param content ClaudeMultiModalContent
--- @return ClaudeToolResult
function ToolResult:error(id, content)
  return setmetatable({
    type = "tool_result",
    tool_use_id = id,
    content = { content },
    is_error = true,
  }, { __index = self })
end

---@alias ClaudeMultiModalContent ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
local MultimodalContent = {}
MultimodalContent.__index = MultimodalContent

--- @param content table
--- @return ClaudeMultiModalContent
function MultimodalContent:new(content)
  if type(content) ~= "table" or type(content.type) ~= "string" then
    error("Invalid content format. Expected table with 'type' field.")
  end

  if content["type"] == "text" then
    return Text:new(content.text)
  elseif content["type"] == "image" then
    return Image:new(content)
  elseif content["type"] == "tool_use" then
    return ToolUse:new(content)
  elseif content["type"] == "tool_result" then
    return ToolResult:new(content)
  else
    error(string.format("Unsupported content type: %s", content.type))
  end
end

---@class ClaudeMessage
---@field role ClaudeRole
---@field content ClaudeMultiModalContent[]
---@field name? string
local Message = {}
Message.__index = Message

---@param role ClaudeRole
---@param content? ClaudeMessage | ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
---@return ClaudeMessage
function Message:new(role, content)
  if type(content) == "table" and content.__index == self then
    --- @cast content ClaudeMessage
    return content
  end
  local obj = setmetatable({ role = role, content = {} }, { __index = self })

  if content then
    table.insert(obj.content, content)
  end

  return obj
end

---@param data? ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
---@return ClaudeMessage
function Message:user(data)
  return Message:new(Role.USER, data)
end

---@param data? ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
---@return ClaudeMessage
function Message:Assistant(data)
  return Message:new(Role.ASSISTANT, data)
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

--- @return ClaudeMessage
function Message:cache()
  if #self.content == 0 then
    return self
  end

  local last_content = self.content[#self.content]
  if type(last_content) == "table" then
    last_content.cache_control = CacheControl:enable()
  end

  return self
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
  MultimodalContent = MultimodalContent,
}
