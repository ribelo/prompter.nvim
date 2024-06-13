---@class Gemini
---@field api_key string
---@field api_version string
local Gemini = {}
Gemini.__index = Gemini

--- Create a new Gemini instance.
---@param api_key string The API key for the Gemini API.
---@param api_version string The version of the Gemini API to use.
---@return Gemini A new Gemini instance.
function Gemini.new(api_key, api_version)
  local self = {
    api_key = api_key,
    api_version = api_version or "v1beta", -- Default to v1 if not provided
  }
  setmetatable(self, { __index = Gemini })
  return self
end

---@return Gemini A new Gemini instance.
function Gemini.default()
  ---@diagnostic disable-next-line: param-type-mismatch
  return Gemini.new(os.getenv("GEMINI_API_KEY"), "v1beta")
end

---@class GeminiResponseSchema
---@field type string
---@field format string|nil
---@field description string|nil
---@field nullable boolean|nil
---@field enum_ string[]|nil
---@field properties table<string, GeminiResponseSchema>|nil
---@field required string[]|nil
---@field items GeminiResponseSchema|nil
local GeminiResponseSchema = {}
GeminiResponseSchema.__index = GeminiResponseSchema

--- Create a new ResponseSchema instance.
---@param data GeminiResponseSchema?
---@return GeminiResponseSchema
function GeminiResponseSchema:new(data)
  -- Initialize a new table with metatable for object-oriented access
  local obj = setmetatable({}, { __index = self })

  -- Lua doesn't have a concept of optional values like TypeScript,
  -- so we simply initialize the object with all fields as nil.
  obj.type = data and data.type or "object"
  obj.format = data and data.format
  obj.description = data and data.description
  obj.nullable = data and data.nullable
  obj.enum_ = data and data.enum_
  obj.properties = data and data.properties
  obj.required = data and data.required
  obj.items = data and data.items

  -- Return the newly created object.
  return obj
end

---@class GeminiGenerationConfig
---@field stop_sequences string[]?
---@field response_mime_type string?
---@field response_schema GeminiResponseSchema?
---@field candidate_count integer?
---@field max_output_tokens integer?
---@field temperature number?
---@field top_p number?
---@field top_k integer?
local GeminiGenerationConfig = {}
GeminiGenerationConfig.__index = GeminiGenerationConfig

--- Create a new GenerationConfig instance.
---@param data GeminiGenerationConfig?
---@return GeminiGenerationConfig
function GeminiGenerationConfig:new(data)
  -- Lua doesn't have a concept of optional values like TypeScript,
  -- so we simply initialize the object with all fields using data or nil
  local obj = setmetatable({
    stop_sequences = data and data.stop_sequences,
    response_mime_type = data and data.response_mime_type,
    response_schema = data and data.response_schema,
    candidate_count = data and data.candidate_count,
    max_output_tokens = data and data.max_output_tokens,
    temperature = data and data.temperature,
    top_p = data and data.top_p,
    top_k = data and data.top_k,
  }, { __index = self })
  return obj
end

---@enum GeminiHarmBlockThreshold
local GeminiHarmBlockThreshold = {
  HARM_BLOCK_THRESHOLD_UNSPECIFIED = "HARM_BLOCK_THRESHOLD_UNSPECIFIED",
  BLOCK_LOW_AND_ABOVE = "BLOCK_LOW_AND_ABOVE",
  BLOCK_MEDIUM_AND_ABOVE = "BLOCK_MEDIUM_AND_ABOVE",
  BLOCK_ONLY_HIGH = "BLOCK_ONLY_HIGH",
  BLOCK_NONE = "BLOCK_NONE",
}

---@enum GeminiHarmCategory
local GeminiHarmCategory = {
  HARM_CATEGORY_UNSPECIFIED = "HARM_CATEGORY_UNSPECIFIED",
  HARM_CATEGORY_DEROGATORY = "HARM_CATEGORY_DEROGATORY",
  HARM_CATEGORY_TOXICITY = "HARM_CATEGORY_TOXICITY",
  HARM_CATEGORY_VIOLENCE = "HARM_CATEGORY_VIOLENCE",
  HARM_CATEGORY_SEXUAL = "HARM_CATEGORY_SEXUAL",
  HARM_CATEGORY_MEDICAL = "HARM_CATEGORY_MEDICAL",
  HARM_CATEGORY_DANGEROUS = "HARM_CATEGORY_DANGEROUS",
  HARM_CATEGORY_HARASSMENT = "HARM_CATEGORY_HARASSMENT",
  HARM_CATEGORY_HATE_SPEECH = "HARM_CATEGORY_HATE_SPEECH",
  HARM_CATEGORY_SEXUALLY_EXPLICIT = "HARM_CATEGORY_SEXUALLY_EXPLICIT",
  HARM_CATEGORY_DANGEROUS_CONTENT = "HARM_CATEGORY_DANGEROUS_CONTENT",
}

---@class GeminiSafetyRating
---@field category GeminiSafetyRating
---@field probability string
local GeminiSafetyRating = {}
GeminiSafetyRating.__index = GeminiSafetyRating

--- Create a new GeminiSafetyRating instance.
---@param data GeminiSafetyRating
---@return GeminiSafetyRating
function GeminiSafetyRating:new(data)
  -- Lua doesn't have a concept of optional values like TypeScript,
  -- so we simply initialize the object with all fields using data or nil
  local obj = setmetatable({
    category = data.category,
    probability = data.probability,
  }, { __index = self })
  return obj
end

---@class GeminiSafetySetting
---@field category GeminiHarmCategory
---@field threshold GeminiHarmBlockThreshold
local GeminiSafetySetting = {}
GeminiSafetySetting.__index = GeminiSafetySetting

--- Create a new SafetySetting instance.
---@param category GeminiHarmCategory
---@param threshold GeminiHarmBlockThreshold
---@return GeminiSafetySetting
function GeminiSafetySetting:new(category, threshold)
  local obj = {
    category = category,
    threshold = threshold,
  }
  setmetatable(obj, { __index = self })
  return obj
end

---@class GeminiSafetySettings
---@field settings GeminiSafetySetting[]
local GeminiSafetySettings = {}
GeminiSafetySettings.__index = GeminiSafetySettings

--- Create a new SafetySettings instance.
---@return GeminiSafetySettings
function GeminiSafetySettings:new()
  local obj = {
    settings = {},
  }
  setmetatable(obj, { __index = self })
  return obj
end

--- Add a category to the settings.
---@param category GeminiHarmCategory
---@param threshold GeminiHarmBlockThreshold
---@return GeminiSafetySettings
function GeminiSafetySettings:add_category(category, threshold)
  table.insert(self.settings, GeminiSafetySetting:new(category, threshold))
  return self
end

--- Create a default SafetySettings instance.
---@return GeminiSafetySettings
function GeminiSafetySettings.default()
  local self = GeminiSafetySettings:new()
  self
    :add_category(
      GeminiHarmCategory.HARM_CATEGORY_HARASSMENT,
      GeminiHarmBlockThreshold.BLOCK_NONE
    )
    :add_category(
      GeminiHarmCategory.HARM_CATEGORY_HATE_SPEECH,
      GeminiHarmBlockThreshold.BLOCK_NONE
    )
    :add_category(
      GeminiHarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT,
      GeminiHarmBlockThreshold.BLOCK_NONE
    )
    :add_category(
      GeminiHarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT,
      GeminiHarmBlockThreshold.BLOCK_NONE
    )
  return self
end

return {
  Gemini = Gemini,
  ResponseSchema = GeminiResponseSchema,
  GenerationConfig = GeminiGenerationConfig,
  HarmBlockThreshold = GeminiHarmBlockThreshold,
  HarmCategory = GeminiHarmCategory,
  SafetyRating = GeminiSafetyRating,
  SafetySetting = GeminiSafetySetting,
  SafetySettings = GeminiSafetySettings,
}

------@param on_result fun(err: string, response: GeminiResponse)
---function GeminiChatCompletionRequest:send(on_result)
---  local body = GeminiChatCompletionRequestBody::new(temperature, max_tokens)
---  if self.system then
---    body.systemInstruction =
---      { role = "user", parts = { { text = self.system } } }
---  end
---  -- Add the messages
---  for _, message in ipairs(self.messages) do
---    if message.role == "assistant" then
---      message.role = "model"
---    end
---    local content =
---      { role = message.role, parts = { { text = message.content } } }
---    table.insert(body.contents, content)
---  end
---
---  gemini.call(self.model, body, on_result)
---end
---
------@param params table?
---function GeminiChatCompletionRequest:fill(params)
---  if self.messages == nil then
---    return
---  end
---  for _, message in ipairs(self.messages) do
---    for _, part in ipairs(message.parts) do
---      part.text = template.fill_template(part.text, params)
---    end
---  end
---end
---
---return GeminiChatCompletionRequest
