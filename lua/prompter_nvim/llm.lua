---@enum RequestType
local RequestType = {
  Google = 0,
  OpenAi = 1,
  Anthropic = 2,
}

---@param vendor string
---@return RequestType
function RequestType:from_string(vendor)
  if vendor == "goole" or vendor == "google" then
    return RequestType.Google
  elseif vendor == "openai" then
    return RequestType.OpenAi
  elseif vendor == "anthropic" or vendor == "claude" then
    return RequestType.Anthropic
  else
    error("Invalid vendor: " .. vendor)
  end
end

---@class GenerateContentResponse
---@field type RequestType
---@field err? string
---@field res? GeminiGenerateContentResponse | ClaudeMessagesResponse
---@field on_result fun(err: string?, res: GenerateContentResponse)
local GenerateContentResponse = {}
GenerateContentResponse.__index = GenerateContentResponse

---@param err string?
---@param res ClaudeMessagesResponse
---@return GenerateContentResponse
function GenerateContentResponse:from_claude(err, res)
  return setmetatable(
    { type = RequestType.Anthropic, err = err, res = res },
    { __index = self }
  )
end

---@param err string?
---@param res GeminiGenerateContentResponse
---@return GenerateContentResponse
function GenerateContentResponse:from_gemini(err, res)
  return setmetatable(
    { type = RequestType.Google, err = err, res = res },
    { __index = self }
  )
end

---@return string?
function GenerateContentResponse:content()
  if self.err then
    return self.err
  end

  if self.type == RequestType.Google then
    local res = self.res
    ---@cast res GeminiGenerateContentResponse
    return res.candidates
      and res.candidates[1]
      and res.candidates[1].content
      and res.candidates[1].content.parts
      and res.candidates[1].content.parts[1]
      and res.candidates[1].content.parts[1].text
  elseif self.type == RequestType.Anthropic then
    local res = self.res
    ---@cast res ClaudeMessagesResponse
    return res.content[1].text
  else
    error("Unsupported request type: " .. tostring(self.type))
  end
end

---@class GenerateContentRequest
---@field type RequestType
---@field send_fn fun(on_result: fun(err: string?, res: GenerateContentResponse?))
local GenerateContentRequest = {}
GenerateContentRequest.__index = GenerateContentRequest

---@param on_result fun(err: string?, res: GenerateContentResponse?)
function GenerateContentRequest:send(on_result)
  self.send_fn(on_result)
end

---@param request ClaudeMessagesRequest
---@return GenerateContentRequest
function GenerateContentRequest:from_claude(request)
  local obj = setmetatable({ type = RequestType.Anthropic }, { __index = self })

  ---@param on_result fun(err: string, res: GenerateContentResponse)
  obj.send_fn = function(on_result)
    request:send(function(err, res)
      on_result(err, GenerateContentResponse:from_claude(err, res))
    end)
  end

  return obj
end

---@param request GeminiGenerateContentRequest
---@return GenerateContentRequest
function GenerateContentRequest:from_gemini(request)
  local obj = setmetatable({ type = RequestType.Google }, { __index = self })

  ---@param on_result fun(err: string, res: GenerateContentResponse)
  obj.send_fn = function(on_result)
    request:send(function(err, res)
      on_result(err, GenerateContentResponse:from_gemini(err, res))
    end)
  end

  return obj
end

return {
  RequestType = RequestType,
  GenerateContentRequest = GenerateContentRequest,
}
