vim.opt.runtimepath:append("~/projects/nvim_plugins/prompter.nvim")

local M = {}

local config = require("prompter_nvim.config")
local browser = require("prompter_nvim.browser")
local command = require("prompter_nvim.command")

M.browser = browser.show_browser
M.prompter_continue = command.prompter_continue
M.prompter_replace = command.prompter_replace
M.prompter_edit = command.prompter_edit

local function mkdir(path, mode)
	vim.loop.fs_mkdir(path, mode)
end

local function exists(path)
	local stat = vim.loop.fs_stat(path)
	return stat ~= nil
end

local function create_dir(path, mode)
	if exists(path) then
		return
	end
	mkdir(path, mode)
end

create_dir(config.global_prompts_path, 511)

return M
