local nio = require("nio")

local Role = require("prompter_nvim.anthropic.message").Role
local Text = require("prompter_nvim.anthropic.message").Text
local Message = require("prompter_nvim.anthropic.message").Message
local MultimodalContent =
  require("prompter_nvim.anthropic.message").MultimodalContent
local ToolUse = require("prompter_nvim.anthropic.tool").ToolUse
local Tool = require("prompter_nvim.anthropic.tool").Tool
local find_tool = require("prompter_nvim.anthropic.tool").find_tool

local models = {
  "claude-3-5-sonnet-20240620",
  "claude-3-haiku-20240307",
  "claude-3-opus-20240229",
  "claude-3-sonet-20240229",
}

--- @class ClaudeMessagesRequest
--- @field messages ClaudeMessage[] Messages to send to Claude
--- @field tools ClaudeTool[]
--- @field model string Model to use for the request
--- @field system string? Optional system message
--- @field max_tokens integer Maximum number of tokens in the response
--- @field stop_sequences string[]? Optional sequences to stop generation
--- @field stream boolean? Whether to stream the response
--- @field temperature number? Controls randomness (0.0 to 1.0)
--- @field top_p number? Controls diversity via nucleus sampling
--- @field top_k integer? Limits vocabulary to top K tokens
local MessagesRequest = {}
MessagesRequest.__index = MessagesRequest

--- Creates a new ClaudeMessagesRequest object
---@param data table Table containing request parameters
---@return ClaudeMessagesRequest New ClaudeMessagesRequest instance
function MessagesRequest:new(data)
  return setmetatable(data, { __index = self })
end

---Adds a message to the request
---@param self ClaudeMessagesRequest
---@param role ClaudeRole
---@param data? ClaudeMessage|ClaudeText|ClaudeImage|ClaudeToolUse|ClaudeToolResult
function MessagesRequest:add_message(role, data)
  if not data then
    return
  end

  if type(data) == "table" and data.__index == Message then
    table.insert(self.messages, data)
    return
  end

  ---@diagnostic disable-next-line: param-type-mismatch
  table.insert(self.messages, Message:new(role, data))
end

---@class ClaudeMessagesRequestBuilder
---@field messages ClaudeMessage?
---@field tools ClaudeTool[]
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
    tools = self.tools or {},
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
---@param data? ClaudeMessage | ClaudeText | ClaudeImage | ClaudeToolUse | ClaudeToolResult
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

  if prompt.tools and #prompt.tools > 0 then
    --- @type ClaudeTool[]
    local tools = {}
    for _, tool_name in ipairs(prompt.tools) do
      ---@type ClaudeTool?
      local tool = TOOLS[tool_name]
      if tool then
        table.insert(tools, tool)
      else
        vim.notify(
          string.format("Tool not found: %s", tool_name),
          vim.log.levels.WARN,
          { title = "Cerebro" }
        )
      end
    end
    request.tools = tools
  end

  -- Set the model if provided in the prompt.
  request.model = prompt.model

  -- Add each message from the prompt to the request.
  local total_chars = 0
  for _, prompt_message in ipairs(prompt.messages) do
    local role = Role:from(prompt_message.role)
    local message = Message:new(role)
    for _, msg_text in ipairs(prompt_message.content) do
      local text = Text:new(msg_text.content)
      total_chars = total_chars + #msg_text.content
      local estimated_tokens = math.floor(total_chars / 4)
      if msg_text.cache and estimated_tokens > 2048 then
        vim.notify(
          "Caching applied: Estimated tokens " .. estimated_tokens,
          vim.log.levels.INFO,
          {
            title = "Cerebro",
            icon = "🧠",
          }
        )
        text:cache()
      elseif msg_text.cache then
        vim.notify(
          "No caching applied: Estimated tokens " .. estimated_tokens,
          vim.log.levels.INFO,
          {
            title = "Cerebro",
            icon = "ℹ️",
          }
        )
      end
      message:add(text)
    end
    request:add_message(role, message)
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
---@field input_tokens number | nil The number of input tokens used by Claude.
---@field output_tokens number | nil The number of output tokens used by Claude.
---@field cache_creation_input_tokens number | nil The number of input tokens used for cache creation.
---@field cache_read_input_tokens number | nil The number of input tokens used for cache reading.
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
---@field total_usage ClaudeUsage | nil
local MessagesResponse = {}
MessagesResponse.__index = MessagesResponse

--- @response string
function MessagesResponse:get_content()
  return self.content[1].text
end

--- @response string
function MessagesResponse:get_usage()
  return self.total_usage or self.usage
end

--- @param data table
--- @response MessagesResponse
function MessagesResponse:new(data)
  local obj = setmetatable({}, { __index = self })
  obj.id = data.id
  obj.type = data.type
  obj.role = Role:from(data.role)
  --- @param elem table
  obj.content = vim.tbl_map(function(elem)
    return MultimodalContent:new(elem)
  end, data.content)
  obj.model = data.model
  obj.stop_reason = data.stop_reason
  obj.stop_sequence = data.stop_sequence
  obj.usage = data.usage
  return obj
end

--- @param tools ClaudeTool[]
--- @param cx table
--- @return ClaudeToolResult[]
function MessagesResponse:invoke_tools(tools, cx)
  local results = {}
  for _, content in ipairs(self.content) do
    if content.__index == ToolUse then
      local tool = find_tool(content.name, tools)
      if not tool then
        vim.notify(
          string.format("Tool not found: %s", content.name),
          vim.log.levels.ERROR,
          { title = "Cerebro" }
        )
        goto continue
      end

      local success, result = pcall(function()
        --- @cast content ClaudeToolUse
        return tool:invoke(content, cx)
      end)

      if success then
        vim.notify(
          string.format("Successfully used tool: %s", content.name),
          vim.log.levels.INFO,
          { title = "Cerebro" }
        )
        table.insert(results, result)
      else
        vim.notify(
          string.format(
            "Error using tool %s: %s",
            content.name,
            tostring(result)
          ),
          vim.log.levels.ERROR
        )
      end
    end
    ::continue::
  end
  return results
end

function MessagesResponse:log_api_usage()
  local usage = self.total_usage
  if not usage then
    return
  end
  local log_parts = {}

  local function add_usage(name, value)
    if value and value > 0 then
      table.insert(log_parts, string.format("%d %s tokens", value, name))
    end
  end

  add_usage("Input", usage.input_tokens)
  add_usage("Output", usage.output_tokens)
  add_usage("Cache Creation Input", usage.cache_creation_input_tokens)
  add_usage("Cache Read Input", usage.cache_read_input_tokens)

  if #log_parts > 0 then
    local message = table.concat(log_parts, "\n")
    vim.notify(message, vim.log.levels.INFO, { title = "Claude API Usage" })
  end
end

--- @param content ClaudeMultiModalContent[]
function MessagesRequest:add_assistant_message(content)
  local message = Message:Assistant()
  for _, content_item in ipairs(content) do
    message:add(content_item)
  end
  self:add_message(Role.ASSISTANT, message)
end

--- @param tool_results ClaudeToolResult[]
function MessagesRequest:add_tool_results(tool_results)
  for _, tool_result in ipairs(tool_results) do
    self:add_message(Role.USER, tool_result)
  end
end

--- @param previous_response ClaudeMessagesResponse
--- @param new_response ClaudeMessagesResponse
--- @return ClaudeUsage
local function calculate_total_usage(previous_response, new_response)
  if not previous_response then
    return {
      input_tokens = new_response.usage.input_tokens,
      output_tokens = new_response.usage.output_tokens,
    }
  end

  local prev_usage = previous_response.total_usage or previous_response.usage

  return {
    input_tokens = new_response.usage.input_tokens + prev_usage.input_tokens,
    output_tokens = new_response.usage.output_tokens + prev_usage.output_tokens,
  }
end

--- @async
--- @param request ClaudeMessagesRequest
--- @param response ClaudeMessagesResponse
local function handle_response(request, response)
  local current_response = response
  current_response.total_usage = vim.deepcopy(current_response.usage)

  while true do
    -- Invoke tools and handle results
    local tool_results = current_response:invoke_tools(request.tools, {})
    if #tool_results == 0 then
      break
    end

    -- Add assistant's response and tool results to the conversation
    request:add_assistant_message(current_response.content)
    request:add_tool_results(tool_results)

    -- Send a new request
    local new_response = request:send()
    if not new_response then
      vim.notify(
        "Failed to get a new response",
        vim.log.levels.ERROR,
        { title = "Cerebro" }
      )
      break
    end

    current_response.total_usage =
      calculate_total_usage(current_response, new_response)
    current_response = new_response
  end

  return current_response
end

--- @async
--- @param self ClaudeMessagesRequest
--- @return ClaudeMessagesResponse | nil
function MessagesRequest:send()
  -- Get the plugin configuration
  local config = require("prompter_nvim.config").get()

  -- Build the request url
  local url = "https://api.anthropic.com/v1/messages"

  -- Prepare the request body
  local body = {}
  body.messages = self.messages
  body.model = self.model

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

  if self.tools and #self.tools > 0 then
    body.tools = {}
    for _, tool in ipairs(self.tools) do
      table.insert(body.tools, {
        name = tool.name,
        description = tool.description,
        input_schema = tool.input_schema,
      })
    end
  end

  local json_body = vim.json.encode(body)
  local timeout =
    tostring(math.min(config.timeout and (config.timeout / 1000) or 60, 60))
  local curl_args = {
    "-s",
    "-X",
    "POST",
    "--max-time",
    tostring(timeout),
    url,
    "-H",
    "x-api-key: " .. config.anthropic_api_key,
    "-H",
    "anthropic-version: 2023-06-01",
    "-H",
    "content-type: application/json",
    "-H",
    "anthropic-beta: prompt-caching-2024-07-31",
    "-d",
    json_body,
  }

  local raw_response = nio.process
    .run({
      cmd = "curl",
      args = curl_args,
      timeout = (config.timeout and config.timeout / 1000) or 60,
    }).stdout
    .read()
  --- @cast raw_response string

  -- Decode the json response
  local ok, json_response = pcall(vim.json.decode, raw_response)
  if not ok then
    vim.notify(
      "Failed to decode JSON response: " .. tostring(json_response),
      vim.log.levels.ERROR
    )
    return
  end

  if json_response.error then
    local error_message = json_response.error.message or "Unknown error"
    local error_type = json_response.error.type or "Unknown type"
    vim.notify(
      string.format("API Error: %s (Type: %s)", error_message, error_type),
      vim.log.levels.ERROR,
      { title = "Cerebro" }
    )
    return nil
  end

  local response = MessagesResponse:new(json_response)

  ---@diagnostic disable-next-line: redefined-local
  local ok, result = pcall(handle_response, self, response)
  if not ok then
    vim.notify(
      "Error handling response: " .. tostring(result),
      vim.log.levels.ERROR
    )
    return
  end

  return result
end

return {
  models = models,
  MessagesRequest = MessagesRequest,
  MessagesResponse = MessagesResponse,
}
