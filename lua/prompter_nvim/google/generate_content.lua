local curl = require("plenary.curl")

local Gemini = require("prompter_nvim.google").Gemini
local SafetySettings = require("prompter_nvim.google").SafetySettings

local Role = require("prompter_nvim.google.message").Role
local Part = require("prompter_nvim.google.message").Part
local Content = require("prompter_nvim.google.message").Content

---@class GeminiGenerateContentRequest
---@field gemini Gemini
---@field contents GeminiContent[]
---@field safetySettings GeminiSafetySettings
---@field systemInstruction GeminiContent?
---@field generationConfig GeminiGenerationConfig?
---@field model string
local GenerateContentRequest = {}
GenerateContentRequest.__index = GenerateContentRequest

---@return GeminiGenerateContentRequest
function GenerateContentRequest:default()
  local obj = setmetatable({}, self)
  obj.gemini = Gemini:default()
  obj.contents = {}
  obj.safetySettings = SafetySettings:default()
  return obj
end

---Builder class for GenerateContentRequest
---@class GeminiGenerateContentRequestBuilder
---@field gemini Gemini?
---@field contents GeminiContent[]
---@field safetySettings GeminiSafetySettings?
---@field systemInstruction GeminiContent?
---@field generationConfig GeminiGenerationConfig?
---@field model string?
local GenerateContentRequestBuilder = {}
GenerateContentRequestBuilder.__index = GenerateContentRequestBuilder

---Creates a new builder instance
---@return GeminiGenerateContentRequestBuilder
function GenerateContentRequestBuilder.default()
  return setmetatable({ contents = {} }, GenerateContentRequestBuilder)
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
    error("content must be of type string, GeminiPart, or GeminiContent")
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
  request.model = prompt.model
  for _, message in ipairs(prompt.messages) do
    vim.print({ message = message })
    local role = Role:translate(message.role)
    request:add_content(Content:new(message.content, role))
  end

  return request
end

---Sends the request to the API using plenary.curl
---@param on_result fun(err: string|nil, res: table|nil)
---@param stream false?
function GenerateContentRequest:send(on_result, stream)
  -- Get configuration settings
  local config = require("prompter_nvim.config").get()

  -- :streamGenerateContent?alt=sse
  -- Build the request URL
  local url = string.format(
    (
      stream
      and "https://generativelanguage.googleapis.com/%s/models/%s:streamGenerateContent?alt=sse&key=%s"
    )
      or "https://generativelanguage.googleapis.com/%s/models/%s:generateContent?key=%s",

    self.gemini.api_version,
    self.model,
    self.gemini.api_key
  )

  -- Build request body
  local body = vim.json.encode({
    contents = self.contents,
    safetySettings = self.safetySettings,
    systemInstruction = self.systemInstruction,
    generationConfig = self.generationConfig,
  })
  -- Send the request using plenary.curl
  curl.post(url, {
    body = body,
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
          vim.schedule_wrap(on_result)(nil, json_response)
        end
      end
    end,
    stream = stream and function(error, line)
      if error then
        -- If there's an error, print it and call the result handler with the error.
        vim.print("Error:", error)
        vim.schedule_wrap(on_result)(error, nil)
        return
      end

      -- Remove "data: " prefix if it exists
      line = line:gsub("^data: ", "")

      -- Ignore empty lines
      if line == "" then
        return
      end

      -- Try to decode the JSON response.
      local success, json_response = pcall(vim.json.decode, line)
      if not success then
        -- If JSON decoding fails, call the result handler with the error.
        vim.schedule_wrap(on_result)("Failed to decode JSON: " .. line, nil)
        return
      end
      vim.print("response", vim.inspect(json_response))
      -- Otherwise, call the result handler with the decoded JSON response.
      vim.schedule_wrap(on_result)(nil, json_response)
    end,
  })
end

return GenerateContentRequest
