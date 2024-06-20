local curl = require("plenary.curl")

local Role = require("prompter_nvim.anthropic.message").Role
local Text = require("prompter_nvim.anthropic.message").Text
local Message = require("prompter_nvim.anthropic.message").Message

local models = {
  "claude-3-5-sonnet-20240620",
  "claude-3-haiku-20240307",
  "claude-3-opus-20240229",
  "claude-3-sonet-20240229",
}

---@class ClaudeMessagesRequest
---@field messages ClaudeMessage
----@field tools Tools
---@field model string
---@field system string?
---@field max_tokens integer
---@field stop_sequences string[]?
---@field stream boolean?
---@field temperature number?
---@field top_p number?
---@field top_k integer?
local MessagesRequest = {}
MessagesRequest.__index = MessagesRequest

---@param data table
---@return ClaudeMessagesRequest
function MessagesRequest:new(data)
  return setmetatable(data, { __index = self })
end

---Adds a message to the request
---@param self ClaudeMessagesRequest
---@param role ClaudeRole
---@param data?  ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
function MessagesRequest:add_message(role, data)
  -- Create a new ClaudeMessage and add it to the messages field
  table.insert(self.messages, Message:new(role, data))
end

---@class ClaudeMessagesRequestBuilder
---@field messages ClaudeMessage?
---@field tools any?
---@field model string?
---@field system string?
---@field max_tokens integer?
---@field stop_sequences string[]?
---@field stream boolean?
---@field temperature number?
---@field top_p number?
---@field top_k integer?
local MessagesRequestBuilder = {}
MessagesRequestBuilder.__index = MessagesRequestBuilder

---Creates a new builder instance
---@return ClaudeMessagesRequestBuilder
function MessagesRequestBuilder:default()
  return setmetatable({ messages = {}, tools = {} }, { __index = self })
end

---@return ClaudeMessagesRequest
function MessagesRequestBuilder:build()
  -- Check if messages or model field is missing
  if not self.messages or not self.model then
    error("MessagesRequest requires both messages and model fields to be set")
  end

  -- Create and return the request object
  return MessagesRequest:new({
    messages = self.messages,
    -- tools = self.tools or {},
    model = self.model,
    system = self.system,
    max_tokens = self.max_tokens,
    stop_sequences = self.stop_sequences,
    stream = self.stream,
    temperature = self.temperature,
    top_p = self.top_p,
    top_k = self.top_k,
  })
end

---Adds a message to the request
---@param self ClaudeMessagesRequestBuilder
---@param role ClaudeRole
---@param data? ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
function MessagesRequestBuilder:add_message(role, data)
  -- Create a new ClaudeMessage and add it to the messages field
  table.insert(self.messages, Message:new(role, data))
end

---@param prompt Prompt
---@return ClaudeMessagesRequestBuilder
function MessagesRequest:from_prompt(prompt)
  -- Create a new ClaudeMessagesRequestBuilder with default values.
  local request = MessagesRequestBuilder:default()

  -- Set the system message if provided in the prompt.
  if prompt.system then
    request.system = prompt.system
  end

  -- Set the stop sequences if provided in the prompt.
  if prompt.stop_sequences and #prompt.stop_sequences > 0 then
    request.stop_sequences = prompt.stop_sequences
  end

  request.max_tokens = prompt.max_tokens or 4096

  -- if prompt.tools and #prompt.tools > 0 then
  --   local tools = {}
  --   for _, tool_name in ipairs(prompt.tools) do
  --     vim.print({ tool_name = tool_name })
  --     ---@type GeminiTool?
  --     local tool = TOOLS[tool_name]
  --     if tool then
  --       table.insert(tools, tool)
  --     else
  --       vim.notify("Tool not found: " .. tool_name, vim.log.levels.WARN)
  --     end
  --   end
  --   request.tools = tools
  -- end

  -- Set the model if provided in the prompt.
  request.model = prompt.model

  -- Add each message from the prompt to the request.
  for _, message in ipairs(prompt.messages) do
    local role = Role:from(message.role)
    vim.print({ raw = message.role, role = role })
    request:add_message(role, Text:new(message.content))
  end

  -- Return the fully constructed ClaudeMessagesRequestBuilder.
  return request
end

---@enum ClaudeStopReason
local StopReason = {
  EndTurn = "end_turn",
  MaxTokens = "max_tokens",
  StopSequence = "stop_sequence",
  ToolUse = "tool_use",
}

---@class ClaudeUsage
---@field input_tokens number The number of input tokens used by Claude.
---@field output_tokens number The number of output tokens used by Claude.
local Usage = {}

---@class ClaudeMessagesResponse
---@field id string
---@field type string
---@field role ClaudeRole
---@field content ClaudeMultiModalContent[]
---@field model string
---@field stop_reason ClaudeStopReason?
---@field stop_sequence string?
---@field usage ClaudeUsage
local MessagesResponse = {}
MessagesResponse.__index = MessagesResponse

--- @param data table
--- @response MessagesResponse
function MessagesResponse:new(data)
  return setmetatable(data, { __index = self })
end

--- @param response ClaudeMessagesResponse
--- @param on_result fun(err: string?, res: GeminiGenerateContentResponse)
function MessagesRequest:handle(response, on_result)
  -- local function_responses = response:invoke_function_calls(self.tools)
  -- if function_responses and not function_responses:is_empty() then
  --   local response_content =
  --     Content:new(response.candidates[1].content, Role.Model)
  --   vim.print(vim.inspect({ response = response.candidates[1].content }))
  --   self:add_content(response_content)
  --   self:add_content(function_responses)
  --   -- vim.print(vim.inspect({ self = self }))
  --   self:send(on_result)
  -- else
  --   vim.print(vim.inspect({ response = response }))
  --   vim.schedule_wrap(on_result)(nil, response)
  -- end
  vim.schedule_wrap(on_result)(nil, response)
end

---@param self ClaudeMessagesRequest
---@param on_result fun(err: string?, res: ClaudeMessagesResponse)
function MessagesRequest:send(on_result)
  -- Get the plugin configuration
  local config = require("prompter_nvim.config").get()

  -- Build the request url
  local url = "https://api.anthropic.com/v1/messages"

  -- Prepare the request body
  local body = self

  -- Add optional fields to the request body
  if self.system then
    body.system = self.system
  end
  if self.max_tokens then
    body.max_tokens = self.max_tokens
  end
  if self.stop_sequences then
    body.stop_sequences = self.stop_sequences
  end
  if self.stream then
    body.stream = self.stream
  end
  if self.temperature then
    body.temperature = self.temperature
  end
  if self.top_p then
    body.top_p = self.top_p
  end
  if self.top_k then
    body.top_k = self.top_k
  end
  vim.print(vim.inspect({ body = body }))
  vim.print(vim.inspect({ json = vim.json.encode(body) }))

  -- Send the request using plenary.curl
  curl.post(url, {
    body = vim.json.encode(body),
    accept = "application/json",
    headers = {
      ---@type string
      ["x-api-key"] = config.anthropic_api_key,
      ---@type string
      ["anthropic-version"] = "2023-06-01",
      ["content-type"] = "application/json",
    },
    timeout = (config.timeout and config.timeout / 1000) or 60,
    callback = function(response)
      if response.exit ~= 0 then
        vim.schedule_wrap(on_result)(response.body, nil)
        return
      end

      -- Decode the json response
      local json_response = vim.json.decode(response.body)

      -- Check if the response contains an error
      if json_response.error then
        vim.schedule_wrap(on_result)(json_response.error.message, nil)
        return
      end

      -- Create a new ClaudeMessagesResponse from the json_response
      local claude_response = MessagesResponse:new(json_response)
      self:handle(claude_response, on_result)
    end,
  })
end

return {
  models = models,
  MessagesRequest = MessagesRequest,
  MessagesResponse = MessagesResponse,
}
