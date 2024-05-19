---@diagnostic disable-next-line: no-unknown
local gemini = require("prompter_nvim.google.api")
local template = require("prompter_nvim.template")

---@enum endpoints
local ENDPOINTS = {
  "generateContent",
}

---@enum roles
local ROLES = {
  "user",
  "model",
}

---@alias message {role: roles, parts: {text: string}[]}
---@alias on_result fun(err: string, response: GeminiResponse)

---@class GeminiChatCompletionRequest
---@field model string
---@field messages message[]
---@field system string | nil
---@field metadata table
---@field temperature number | nil
---@field max_tokens number | nil
local GeminiChatCompletionRequest = {}
GeminiChatCompletionRequest.__index = GeminiChatCompletionRequest

function GeminiChatCompletionRequest:new(o)
  return setmetatable(o, self)
end

---@param on_result fun(err: string, response: GeminiResponse)
function GeminiChatCompletionRequest:send(on_result)
  local body = {
    contents = {},
    generationConfig = {
      temperature = self.temperature or 1.0,
      maxOutputTokens = self.max_tokens or 4096,
    },
  }
  if self.system then
    body.systemInstruction =
      { role = "user", parts = { { text = self.system } } }
  end
  -- Add the messages
  for _, message in ipairs(self.messages) do
    if message.role == "assistant" then
      message.role = "model"
    end
    local content =
      { role = message.role, parts = { { text = message.content } } }
    table.insert(body.contents, content)
  end

  vim.print({ gemini = { body = body, model = self.model } })
  gemini.call(self.model, body, on_result)
end

---@param params table?
function GeminiChatCompletionRequest:fill(params)
  if self.messages == nil then
    return
  end
  for _, message in ipairs(self.messages) do
    for _, part in ipairs(message.parts) do
      part.text = template.fill_template(part.text, params)
    end
  end
end

return GeminiChatCompletionRequest
