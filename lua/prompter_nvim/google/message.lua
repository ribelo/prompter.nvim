---@enum GeminiRole
local Role = {
  User = "user",
  Model = "model",
}

--- Translates a role string to its corresponding GeminiRole value.
--- Throws an error if the role is invalid.
--- @param role string The role to translate.
--- @return GeminiRole The translated role.
function Role:translate(role)
  if role == "user" then
    return Role.User
  elseif role == "model" or role == "assistant" then
    return Role.Model
  else
    error("Invalid role: " .. role) -- Throw an error if the role is invalid
  end
end

---@class GeminiBlob
---@field mime_type string
---@field data string
local Blob = {}
Blob.__index = Blob

---@param mime_type string
---@param data string
---@return GeminiBlob
function Blob:new(mime_type, data)
  local obj = setmetatable({}, self)
  obj.mime_type = mime_type
  obj.data = data
  return obj
end

---@class GeminiFunctionCall
---@field name string
---@field args table<string, any> | nil
local FunctionCall = {}
FunctionCall.__index = FunctionCall

---@param name string
---@param args table<string, any> | nil
---@return GeminiFunctionCall
function FunctionCall:new(name, args)
  local obj = setmetatable({}, self)
  obj.name = name
  obj.args = args
  return obj
end

---@class GeminiFunctionResponse
---@field name string
---@field response table<string, any>
local FunctionResponse = {}
FunctionResponse.__index = FunctionResponse

---@param name string
---@param response table<string, any>
---@return GeminiFunctionResponse
function FunctionResponse:new(name, response)
  local obj = setmetatable({}, self)
  obj.name = name
  obj.response = response
  return obj
end

---@class GeminiFileData
---@field mime_type string | nil
---@field file_uri string
local FileData = {}
FileData.__index = FileData

---@param mime_type string | nil
---@param file_uri string
---@return GeminiFileData
function FileData:new(mime_type, file_uri)
  local obj = setmetatable({}, self)
  obj.mime_type = mime_type
  obj.file_uri = file_uri
  return obj
end

---@class GeminiPart
---@field text string?
---@field inline_data GeminiBlob?
---@field function_call GeminiFunctionCall?
---@field function_response GeminiFunctionResponse?
---@field file_data GeminiFileData?
local Part = {}
Part.__index = Part

---@param data string | GeminiBlob | GeminiFunctionCall | GeminiFunctionResponse | GeminiFileData
---@return GeminiPart
function Part:new(data)
  local obj = setmetatable({}, self)

  -- Check the type of data and set the appropriate field.
  if type(data) == "string" then
    obj.text = data
  elseif type(data) == "table" and data.__index == Blob then
    ---@cast data GeminiBlob
    obj.inline_data = data
  elseif type(data) == "table" and data.__index == FunctionCall then
    ---@cast data GeminiFunctionCall
    obj.function_call = data
  elseif type(data) == "table" and data.__index == FunctionResponse then
    ---@cast data GeminiFunctionResponse
    obj.function_response = data
  elseif type(data) == "table" and data.__index == FileData then
    ---@cast data GeminiFileData
    obj.file_data = data
  end

  return obj
end

---@class GeminiContent
---@field role GeminiRole?
---@field parts GeminiPart[]?
local Content = {}
Content.__index = Content

---@param role GeminiRole?
---@param data string | GeminiPart | GeminiPart[] | GeminiContent?
---@return GeminiContent
function Content:new(data, role)
  if type(data) == "table" and data.__index == Content then
    ---@cast data GeminiContent
    return data -- quick return if data is GeminiContent
  end

  local obj = setmetatable({}, self)
  obj.role = role or Role.User

  if type(data) == "string" then
    obj.parts = { Part:new(data) }
  elseif type(data) == "table" and data.__index == Part then
    ---@cast data GeminiPart
    obj.parts = { data }
  elseif type(data) == "table" and #data > 0 and data[1].__index == Part then
    ---@cast data GeminiPart[]
    obj.parts = data
  end

  return obj
end

---@param data string | GeminiPart | GeminiPart[]?
---@return GeminiContent
function Content:new_user(data)
  return Content:new(data, Role.User)
end

---@param data GeminiPart[]?
---@return GeminiContent
function Content:new_model(data)
  return Content:new(data, Role.Model)
end

---@param part string | GeminiPart
function Content:add(part)
  -- Add the given part to the list of parts.
  if type(part) == "string" then
    table.insert(self.parts, Part:new(part))
  elseif type(part) == "table" and part.__index == Part then
    table.insert(self.parts, part)
  end
end

return {
  Role = Role,
  Blob = Blob,
  FunctionCall = FunctionCall,
  FunctionResponse = FunctionResponse,
  FileData = FileData,
  Part = Part,
  Content = Content,
}
