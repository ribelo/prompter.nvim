---@diagnostic disable-next-line: no-unknown
local openai = require("prompter_nvim.groq.api")
local template = require("prompter_nvim.template")

---@enum roles
local ROLES = {
  "user",
  "assistant",
}

---@alias message {role: roles, content: string|{type: string, text: string}[]}
---@alias on_result fun(err: string, output: string)

---@class GroqChatCompletionRequest
---@field model string
---@field system string
---@field messages message[]
---@field max_tokens integer
---@field metadata table
---@field stop_sequences string[]
---@field stream boolean
---@field temperature number
---@field top_p number
---@field top_k integer
local GroqChatCompletionRequest = {}
GroqChatCompletionRequest.__index = GroqChatCompletionRequest

function GroqChatCompletionRequest:new(o)
  return setmetatable(o, self)
end

---@param on_result fun(err: string, response: any)
function GroqChatCompletionRequest:send(on_result)
  local body = {
    model = self.model,
    messages = {},
  }

  -- Add self.system as the first message if it exists
  if self.system then
    table.insert(body.messages, { role = "system", content = self.system })
  end

  -- Add the remaining messages
  for _, message in ipairs(self.messages) do
    table.insert(body.messages, message)
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

  openai.call(body, on_result)
end

---@param params table?
function GroqChatCompletionRequest:fill(params)
  if self.messages == nil then
    return
  end

  if self.system then
    self.system = template.fill_template(self.system, params)
  end
  for _, message in ipairs(self.messages) do
    message.content = template.fill_template(message.content, params)
  end
end

return GroqChatCompletionRequest
