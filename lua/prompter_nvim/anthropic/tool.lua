local Text = require("prompter_nvim.anthropic.message").Text
local ToolUse = require("prompter_nvim.anthropic.message").ToolUse
local ToolResult = require("prompter_nvim.anthropic.message").ToolResult

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

--- Represents a tool, which has a name, description, parameters, and a handler function.
---
--- @class ClaudeTool
--- @field name string The name of the tool.
--- @field description string A description of the tool.
--- @field input_schema table A table of parameters for the tool.
--- @field handler? fun(input: table, cx: table): any A function that handles the tool's invocation.
local Tool = {}
Tool.__index = Tool

--- Creates a new Tool instance.
---
--- @param name string The name of the tool.
--- @return ClaudeTool
function Tool:new(name)
  local obj = setmetatable({}, { __index = self })
  obj.name = name
  return obj
end

--- Sets the description of the tool.
---
--- @param description string A description of the tool.
--- @return ClaudeTool
function Tool:with_description(description)
  self.description = description
  return self
end

--- Sets the handler for the tool.
---
--- @param handler async fun(input: table, cx: table): any A function that handles the tool's invocation.
--- @return ClaudeTool
function Tool:with_handler(handler)
  self.handler = handler
  return self
end

--- Sets the parameters for the tool.
---
--- @param data JsonSchema A table of parameters for the tool.
--- @return ClaudeTool
function Tool:with_parameters(data)
  self.input_schema = JsonSchema:new(data)
  return self
end

--- Invokes the tool's handler function with the given input and context.
---
--- @param tool_use ClaudeToolUse The input to the tool.
--- @param cx? table The context in which the tool is being invoked.
--- @return ClaudeToolResult Result of the tool's invocation, or nil if the tool has no handler function.
function Tool:invoke(tool_use, cx)
  -- If tool has no handler, throw error.
  if not self.handler then
    error("Tool has no handler function.")
  end

  local input = tool_use.input

  -- Try to invoke the tool's handler.
  local success, response = pcall(self.handler, input, cx)

  -- If successful, return the response.
  if success then
    return ToolResult:success(tool_use.id, Text:new(tostring(response)))
  end

  -- If not successful, return the error.
  return ToolResult:error(tool_use.id, Text:new(tostring(response)))
end

--- Serialize Tool to JSON, only including serializable values.
---
--- @return table
function Tool:serializable()
  return {
    name = self.name,
    description = self.description,
    input_schema = self.input_schema,
  }
end

--- Finds a tool by its name within a list of tools.
---
--- @param tool_name string The name of the tool to find.
--- @param tools ClaudeTool[] The list of tools to search.
--- @return ClaudeTool? The found tool, or nil if not found.
local function find_tool(tool_name, tools)
  for _, tool in ipairs(tools) do
    if tool.name == tool_name then
      return tool
    end
  end
  return nil
end

return {
  ToolUse = ToolUse,
  ToolResult = ToolResult,
  Tool = Tool,
  JsonType = JsonType,
  find_tool = find_tool,
}
