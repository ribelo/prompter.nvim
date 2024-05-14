local config = require("prompter_nvim/config")

local M = {}
M.models = {
  "gpt-4o",
  "gpt-4-turbo-2024-04-09",
  "gpt-3.5-turbo",
}

---@alias completion_choice {text: string, index: integer, logprobs: any?, finish_reason: string}
---@alias edit_choice {text: string, index: integer}

---@alias chat_message {role: string, content: string}
---@alias chat_choice {message: chat_message, index: integer, finish_reason: string}

---@class OpenAiResponse
---@field id string
---@field object string
---@field created integer
---@field model string
---@field usage {prompt_tokens: integer, completion_tokens: integer, total_tokens: integer}

---@class OpenAiCompletionsResponse: OpenAiResponse
---@field choices completion_choice[]

---@class OpenAiEditsResponse: OpenAiResponse
---@field choices completion_choice[]

---@class OpenAiChatResponse: OpenAiResponse
---@field choices chat_choice[]

M.exec = function(cmd, args, on_result)
  local stdout = vim.loop.new_pipe()
  local stdout_chunks = {}
  local function on_stdout_read(_, data)
    if data then
      table.insert(stdout_chunks, data)
    end
  end

  local stderr = vim.loop.new_pipe()
  local stderr_chunks = {}
  local function on_stderr_read(_, data)
    if data then
      table.insert(stderr_chunks, data)
    end
  end

  local handle, err
  handle, err = vim.loop.spawn(
    cmd,
    { args = args, stdio = { nil, stdout, stderr } },
    function(code, _signal)
      if stdout then
        stdout:close()
      end
      if stderr then
        stderr:close()
      end
      if handle then
        handle:close()
      end

      vim.schedule(function()
        if code ~= 0 then
          on_result(vim.trim(table.concat(stderr_chunks, "")), nil)
        else
          on_result(nil, vim.trim(table.concat(stdout_chunks, "")))
        end
      end)
    end
  )

  if not handle then
    on_result(cmd .. " could net be started: " .. err)
  else
    if stdout then
      stdout:read_start(on_stdout_read)
    end
    if stderr then
      stderr:read_start(on_stderr_read)
    end
  end
end

M.call = function(body, on_result)
  local curl_args = {
    "-X",
    "POST",
    "--silent",
    "--show-error",
    "-L",
    "https://api.openai.com/v1/chat/completions",
    "-m",
    config.timeout or 10000,
    "-H",
    "Content-Type: application/json",
    "-H",
    "Authorization: Bearer " .. config.openai_api_key,
    "-d",
    vim.json.encode(body),
  }
  M.exec("curl", curl_args, function(err, output)
    if err then
      on_result(err, nil)
    else
      ---@class JsonError
      ---@field code number
      ---@field message string

      ---@class Json
      ---@field decode fun(str: string): any
      ---@field error JsonError
      local json = vim.json.decode(output)
      if json.error then
        on_result(json.error.message, nil)
      else
        on_result(nil, json)
      end
    end
  end)
end

return M
