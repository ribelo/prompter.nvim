local config = require("prompter_nvim/config")

local M = {}

M.models = {
  "claude-3-opus-20240229",
  "claude-3-haiku-20240307",
  "claude-3-sonet-20240229",
}

---@class CluadeResponse
---@field id string
---@field model string
---@field created integer
---@field role string
---@field stop_reason string
---@filed stop_sequence string|nil
---@field type string
---@field usage {input_tokens: integer, output_tokens: integer}
---@field content {text: string, type: string}

M.exec = function(cmd, args, on_result)
  local stdout = vim.uv.new_pipe()
  local stdout_chunks = {}
  local function on_stdout_read(_, data)
    if data then
      table.insert(stdout_chunks, data)
    end
  end

  local stderr = vim.uv.new_pipe()
  local stderr_chunks = {}
  local function on_stderr_read(_, data)
    if data then
      table.insert(stderr_chunks, data)
    end
  end

  local handle, err
  handle, err = vim.uv.spawn(
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

local config = config.get()

M.call = function(endpoint, body, on_result)
  local curl_args = {
    "-X",
    "POST",
    "--silent",
    "--show-error",
    "-L",
    "https://api.anthropic.com/v1/" .. endpoint,
    "-m",
    config.timeout or 10000,
    "-H",
    "x-api-key: " .. config.anthropic_api_key,
    "-H",
    "anthropic-version: 2023-06-01",
    "-H",
    "Content-Type: application/json",
    "-d",
    vim.json.encode(body),
  }
  M.exec("curl", curl_args, function(err, output)
    if err then
      vim.print({ err = err })
      on_result(err, nil)
    else
      ---@class JsonError
      ---@field code number
      ---@field message string

      ---@class Json
      ---@field decode fun(str: string): any
      ---@field error JsonError
      local json = vim.json.decode(output)
      vim.print("request completed")
      if json.error then
        on_result(json.error.message, nil)
      else
        on_result(nil, json)
      end
    end
  end)
end

return M
