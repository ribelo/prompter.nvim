---@diagnostic disable-next-line: no-unknown
local anthropic = require("prompter_nvim.anthropic.api")
local template = require("prompter_nvim.template")

---@enum endpoints
local ENDPOINTS = {
  "messages",
}

---@enum roles
local ROLES = {
  "user",
  "assistant",
}

---@alias message {role: roles, content: string|{type: string, text: string}[]}
---@alias on_result fun(err: string, output: string)

---@class AnthropicChatCompletionRequest
---@field endpoint endpoints
---@field model string
---@field messages message[]
---@field system string
---@field max_tokens integer
---@field metadata table
---@field stop_sequences string[]
---@field stream boolean
---@field temperature number
---@field top_p number
---@field top_k integer
local ChatCompletionRequest = {}
ChatCompletionRequest.__index = ChatCompletionRequest

function ChatCompletionRequest:new(o)
  return setmetatable(o, self)
end

---@param on_result fun(err: string, response: CompletionsResponse|EditsResponse|ChatResponse)
function ChatCompletionRequest:send(on_result)
  local body = {
    model = self.model,
    messages = self.messages,
  }
  if self.system then
    body.system = self.system
  end
  body.max_tokens = self.max_tokens
  if self.metadata then
    body.metadata = self.metadata
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
  anthropic.call(self.endpoint, body, on_result)
end

---@param params table?
function ChatCompletionRequest:fill(params)
  if self.endpoint == "messages" then
    for _, message in ipairs(self.messages) do
      if type(message.content) == "string" then
        message.content = template.fill_template(message.content, params)
      elseif type(message.content) == "table" then
        for _, block in ipairs(message.content) do
          if block.type == "text" then
            block.text = template.fill_template(block.text, params)
          end
        end
      end
    end
  else
    assert(false, "bad endpoint for this request type: " .. self.endpoint)
  end
end

return ChatCompletionRequest
