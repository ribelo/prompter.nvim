local FunctionResponse =
  require("prompter_nvim.google.message").FunctionResponse

--- Type represents the OpenAPI data types.
--- @enum JsonType
local JsonType = {
  TYPE_UNSPECIFIED = "TYPE_UNSPECIFIED",
  STRING = "string",
  NUMBER = "number",
  INTEGER = "integer",
  BOOLEAN = "boolean",
  ARRAY = "array",
  OBJECT = "object",
}

--- @class Property
--- @field type JsonType
--- @field description? string

--- @class JsonSchema
--- @field type JsonType
--- @field format? string
--- @field description? string
--- @field nullable? boolean
--- @field enum? string[]
--- @field properties table<string, Property>
--- @field required string[]
--- @field items? JsonSchema
local JsonSchema = {}
JsonSchema.__index = JsonSchema

---@param data table
---@return JsonSchema
function JsonSchema:new(data)
  return setmetatable(data, { __index = self })
end

--- Represents a tool, which is a wrapper for FunctionDeclaration.
--- @class GeminiTool
--- @field function_declaration GeminiFunctionDeclaration
local Tool = {}
Tool.__index = Tool

--- Represents a tool, which has a name, description, parameters, and a handler function.
---
--- @class GeminiFunctionDeclaration
--- @field name string The name of the tool.
--- @field description string A description of the tool.
--- @field parameters table A table of parameters for the tool.
--- @field handler fun(input: table, cx: table): any A function that handles the tool's invocation.
local FunctionDeclaration = {}
FunctionDeclaration.__index = FunctionDeclaration

--- Creates a new Tool instance.
---
--- @param name string The name of the tool.
--- @return GeminiTool
function Tool:new(name)
  local obj = setmetatable({}, { __index = self })
  local dec = setmetatable({}, FunctionDeclaration)
  dec.name = name
  obj.function_declaration = dec
  return obj
end

--- Sets the description of the tool.
---
--- @param description string A description of the tool.
--- @return GeminiTool
function Tool:with_description(description)
  self.function_declaration.description = description
  return self
end

--- Sets the handler for the tool.
---
--- @param handler fun(input: table, cx: table): table A function that handles the tool's invocation.
--- @return GeminiTool
function Tool:with_handler(handler)
  self.function_declaration.handler = handler
  return self
end

--- Sets the parameters for the tool.
---
--- @param data JsonSchema A table of parameters for the tool.
--- @return GeminiTool
function Tool:with_parameters(data)
  self.function_declaration.parameters = JsonSchema:new(data)
  return self
end

--- Invokes the tool's handler function with the given input and context.
---
--- @param input? table The input to the tool.
--- @param cx? table The context in which the tool is being invoked.
--- @return GeminiFunctionResponse Result of the tool's invocation, or nil if the tool has no handler function.
function Tool:invoke(input, cx)
  -- If tool has no handler, throw error.
  if not self.function_declaration.handler then
    error("Tool has no handler function.")
  end

  -- Try to invoke the tool's handler.
  local success, response = pcall(self.function_declaration.handler, input, cx)

  -- If successful, return the response.
  if success then
    return FunctionResponse:new(self.function_declaration.name, response)
  end

  -- If not successful, throw the error.
  error(response)
end

--- Serialize Tool to JSON, only including serializable values.
---
--- @return table
function Tool:serializable()
  return {
    name = self.function_declaration.name,
    description = self.function_declaration.description,
    parameters = self.function_declaration.parameters,
  }
end

--- Finds a tool by its name within a list of tools.
---
--- @param tool_name string The name of the tool to find.
--- @param tools GeminiTool[] The list of tools to search.
--- @return GeminiTool? The found tool, or nil if not found.
local function find_tool(tool_name, tools)
  for _, tool in ipairs(tools) do
    if tool.function_declaration.name == tool_name then
      return tool
    end
  end
  return nil
end

return {
  Tool = Tool,
  JsonType = JsonType,
  find_tool = find_tool,
}
