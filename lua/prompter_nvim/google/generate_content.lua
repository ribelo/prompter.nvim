local curl = require("plenary.curl")

local Gemini = require("prompter_nvim.google").Gemini
local SafetySettings = require("prompter_nvim.google").SafetySettings

local Role = require("prompter_nvim.google.message").Role
local Part = require("prompter_nvim.google.message").Part
local Content = require("prompter_nvim.google.message").Content
local Tool = require("prompter_nvim.google.tool").Tool
local find_tool = require("prompter_nvim.google.tool").find_tool

models = {
  "gemini-1.5-pro-latest",
  "gemini-1.5-flash-latest",
}

---@class GeminiGenerateContentResponse
---@field candidates GeminiResponseCandidate[]
---@field promptFeedback GeminiPromptFeedback?
---@field usageMetadata GeminiUsageMetadata?
---@field model string
local GeminiGenerateContentResponse = {}
GeminiGenerateContentResponse.__index = GeminiGenerateContentResponse

--- @param data table
--- @response GeminiGenerateContentResponse
function GeminiGenerateContentResponse:new(data)
  return setmetatable(data, { __index = self })
end

--- @param tools GeminiTool[]
--- @return GeminiContent?
function GeminiGenerateContentResponse:invoke_function_calls(tools)
  vim.print("GeminiGenerateContentResponse:invoke_function_calls")
  local content = Content:new_user()
  for _, part in ipairs(self.candidates[1].content.parts) do
    vim.print("foo", vim.inspect({ fn = part.functionCall }))
    if part.functionCall then
      vim.print(
        "GeminiGenerateContentResponse:invoke_function_calls have function call",
        part.functionCall.name
      )
      local tool = find_tool(part.functionCall.name, tools)
      if tool then
        local function_response = tool:invoke(part.functionCall.args)
        content:add(Part:new(function_response))
      else
        error("Tool not found: " .. part.functionCall.name)
      end
    end
  end
  return content
end

---@class GeminiResponseCandidate
---@field content GeminiContent
---@field finishReason string
---@field index integer
---@field safetyRatings GeminiSafetyRating[]?
local GeminiResponseCandidate = {}
GeminiResponseCandidate.__index = GeminiResponseCandidate

---@enum GeminiBlockReason
local GeminiBlockReason = {
  BLOCK_REASON_UNSPECIFIED = "BLOCK_REASON_UNSPECIFIED",
  SAFETY = "SAFETY",
  OTHER = "OTHER",
}

---@class GeminiPromptFeedback
---@field blockReason GeminiBlockReason
---@field safetyRatings GeminiSafetyRating[]
local GeminiPromptFeedback = {}
GeminiPromptFeedback.__index = GeminiPromptFeedback

---@class GeminiUsageMetadata
---@field promptTokenCount integer
---@field candidatesTokenCount integer?
---@field totalTokenCount integer
local GeminiUsageMetadata = {}
GeminiUsageMetadata.__index = GeminiUsageMetadata

---@class GeminiGenerateContentRequest
---@field gemini Gemini
---@field contents GeminiContent[]
---@field tools? GeminiTool[]
---@field safetySettings GeminiSafetySettings
---@field systemInstruction GeminiContent?
---@field generationConfig GeminiGenerationConfig?
---@field model string
local GenerateContentRequest = {}
GenerateContentRequest.__index = GenerateContentRequest

---@return GeminiGenerateContentRequest
function GenerateContentRequest:default()
  local obj = setmetatable({}, { __index = self })
  obj.gemini = Gemini:default()
  obj.contents = {}
  obj.safetySettings = SafetySettings:default()
  return obj
end

---@param content string | GeminiPart | GeminiContent
function GenerateContentRequest:add_content(content)
  if type(content) == "string" then
    table.insert(self.contents, Content:new_user(content))
  elseif type(content) == "table" and content.__index == Part then
    table.insert(self.contents, Content:new_user(content))
  elseif type(content) == "table" and content.__index == Content then
    table.insert(self.contents, content)
  else
    error("content must be of type string, GeminiPart, or GeminiContent")
  end
end

---Builder class for GenerateContentRequest
---@class GeminiGenerateContentRequestBuilder
---@field gemini Gemini?
---@field contents GeminiContent[]
---@field tools GeminiTool[]?
---@field safetySettings GeminiSafetySettings?
---@field systemInstruction GeminiContent?
---@field generationConfig GeminiGenerationConfig?
---@field model string?
local GenerateContentRequestBuilder = {}
GenerateContentRequestBuilder.__index = GenerateContentRequestBuilder

---Creates a new builder instance
---@return GeminiGenerateContentRequestBuilder
function GenerateContentRequestBuilder:default()
  return setmetatable({ contents = {} }, { __index = self })
end

---@param content string | GeminiPart | GeminiContent
function GenerateContentRequestBuilder:add_content(content)
  if type(content) == "string" then
    table.insert(self.contents, Content:new_user(content))
  elseif type(content) == "table" and content.__index == Part then
    table.insert(self.contents, Content:new_user(content))
  elseif type(content) == "table" and content.__index == Content then
    table.insert(self.contents, content)
  else
    error(
      string.format(
        "Content must be of type string, GeminiPart, or GeminiContent. Content: %s",
        content
      )
    )
  end
end

---@return GeminiGenerateContentRequest
function GenerateContentRequestBuilder:build()
  -- Check if contents or model field is missing
  if not self.contents or not self.model then
    error(
      "GenerateContentRequest requires both contents and model fields to be set"
    )
  end

  -- Create and return the request object
  return setmetatable({
    gemini = self.gemini or Gemini:default(),
    contents = self.contents,
    tools = self.tools,
    safetySettings = self.safetySettings,
    systemInstruction = self.systemInstruction,
    generationConfig = self.generationConfig,
    model = self.model,
  }, GenerateContentRequest)
end

---@param prompt Prompt
---@return GeminiGenerateContentRequestBuilder
function GenerateContentRequest:from_prompt(prompt)
  local request = GenerateContentRequestBuilder:default()
  if prompt.system then
    request.systemInstruction = Content:new(prompt.system)
  end
  if prompt.stop_sequences and #prompt.stop_sequences > 0 then
    request.generationConfig.stop_sequences = prompt.stop_sequences
  end
  if prompt.tools and #prompt.tools > 0 then
    local tools = {}
    for _, tool_name in ipairs(prompt.tools) do
      vim.print({ tool_name = tool_name })
      ---@type GeminiTool?
      local tool = TOOLS[tool_name]
      if tool then
        table.insert(tools, tool)
      else
        vim.notify("Tool not found: " .. tool_name, vim.log.levels.WARN)
      end
    end
    request.tools = tools
  end
  request.model = prompt.model
  for _, message in ipairs(prompt.messages) do
    vim.print({ message = message })
    local role = Role:translate(message.role)
    vim.print(vim.inspect({ content2 = message.content, role = role }))
    request:add_content(Content:new(message.content, role))
  end

  return request
end

--- @param response GeminiGenerateContentResponse
--- @param on_result fun(err: string?, res: GeminiGenerateContentResponse)
function GenerateContentRequest:handle(response, on_result)
  local function_responses = response:invoke_function_calls(self.tools)
  if function_responses and not function_responses:is_empty() then
    local response_content =
      Content:new(response.candidates[1].content, Role.Model)
    vim.print(vim.inspect({ response = response.candidates[1].content }))
    self:add_content(response_content)
    self:add_content(function_responses)
    -- vim.print(vim.inspect({ self = self }))
    self:send(on_result)
  else
    vim.print(vim.inspect({ response = response }))
    vim.schedule_wrap(on_result)(nil, response)
  end
end

---Sends the request to the API using plenary.curl
---@param on_result fun(err: string?, res: GeminiGenerateContentResponse)
function GenerateContentRequest:send(on_result)
  -- Get configuration settings
  local config = require("prompter_nvim.config").get()

  -- :streamGenerateContent?alt=sse
  -- Build the request URL
  local url = string.format(
    "https://generativelanguage.googleapis.com/%s/models/%s:generateContent?key=%s",
    self.gemini.api_version,
    self.model,
    self.gemini.api_key
  )

  -- Build request body
  local body = {
    contents = self.contents,
    safetySettings = self.safetySettings,
    systemInstruction = self.systemInstruction,
    generationConfig = self.generationConfig,
  }
  if self.tools and #self.tools > 0 then
    body.tools = {}
    local function_declarations = vim.tbl_map(Tool.serializable, self.tools)
    body.tools[1] = { functionDeclarations = function_declarations }
  end
  -- Send the request using plenary.curl
  curl.post(url, {
    body = vim.json.encode(body),
    accept = "application/json",
    headers = {
      content_type = "application/json",
    },
    timeout = (config.timeout and config.timeout / 1000) or 60,
    callback = function(response)
      if response.exit ~= 0 then
        vim.schedule_wrap(on_result)(response.body, nil)
      else
        local json_response = vim.json.decode(response.body)
        if json_response.error then
          vim.schedule_wrap(on_result)(json_response.error.message, nil)
        else
          local gemini_response =
            GeminiGenerateContentResponse:new(json_response)
          self:handle(gemini_response, on_result)
        end
      end
    end,
  })
end

return {
  models = models,
  GenerateContentRequest = GenerateContentRequest,
  GeminiGenerateContentResponse = GeminiGenerateContentResponse,
}
