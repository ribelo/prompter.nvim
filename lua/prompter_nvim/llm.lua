---@enum RequestType
local RequestType = {
  Gemini = 0,
  OpenAi = 1,
  Anthropic = 2,
}

---@param vendor string
---@return RequestType
function RequestType:from_string(vendor)
  if vendor == "gemini" then
    return RequestType.Gemini
  elseif vendor == "openai" then
    return RequestType.OpenAi
  elseif vendor == "anthropic" then
    return RequestType.Anthropic
  else
    error("Invalid vendor: " .. vendor)
  end
end

---@class GenerateContentRequest
---@field send_fn fun(on_result: fun(err: string|nil, res: table|nil))
---@field type RequestType
local GenerateContentRequest = {}
GenerateContentRequest.__index = GenerateContentRequest

---@param on_result fun(err: string|nil, res: table|nil)
function GenerateContentRequest:send(on_result)
  self.send_fn(on_result)
end

---@param request GeminiGenerateContentRequest
---@return GenerateContentRequest
function GenerateContentRequest:from_gemini(request)
  vim.print("foo", request, { send = request.send })
  local obj = setmetatable({ type = RequestType.Gemini }, self)
  obj.send_fn = function(on_result)
    request:send(on_result)
  end
  return obj
end

return {
  RequestType = RequestType,
  GenerateContentRequest = GenerateContentRequest,
}
