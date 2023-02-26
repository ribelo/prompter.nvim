local config = require("prompter_nvim/config")

local M = {}

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
	handle, err = vim.loop.spawn(cmd, { args = args, stdio = { nil, stdout, stderr } }, function(code, _signal)
		---@diagnostic disable-next-line: need-check-nil
		stdout:close()
		---@diagnostic disable-next-line: need-check-nil
		stderr:close()
		handle:close()

		vim.schedule(function()
			if code ~= 0 then
				on_result(vim.trim(table.concat(stderr_chunks, "")), nil)
			else
				on_result(nil, vim.trim(table.concat(stdout_chunks, "")))
			end
		end)
	end)

	if not handle then
		on_result(cmd .. " could net be started: " .. err)
	else
		---@diagnostic disable-next-line: need-check-nil
		stdout:read_start(on_stdout_read)
		---@diagnostic disable-next-line: need-check-nil
		stderr:read_start(on_stderr_read)
	end
end

M.call = function(endpoint, body, on_result)
	local curl_args = {
		"-X",
		"POST",
		"--silent",
		"--show-error",
		"-L",
		"https://api.openai.com/v1/" .. endpoint,
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
