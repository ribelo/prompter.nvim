local config = require("prompter_nvim.config")
local browser = require("prompter_nvim.browser")
local utils = require("prompter_nvim.utils")
local tags = require("prompter_nvim.tags")
local Prompt = require("prompter_nvim.prompt")

-- local command = require("prompter_nvim.command")

---@type Prompt
local prompt = Prompt:new()
local M = {}

M.browser = function()
  local selected_text = utils.join_lines(utils.get_selected_text())
  browser.show_browser({
    selected_text = selected_text,
    pre_prompt = prompt:join(),
  })
end
-- M.prompter_continue = command.prompter_continue
-- M.prompter_replace = command.prompter_replace
-- M.prompter_edit = command.prompter_edit

local function mkdir(path)
  vim.fn.mkdir(path)
end

local function exists(path)
  ---@type any
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil
end

local function create_dir(path)
  if exists(path) then
    return
  end
  mkdir(path)
end

create_dir(config.global_prompts_path)

M.setup = function(opts)
  config = vim.tbl_extend("force", config, opts)
  -- vim.api.nvim_create_user_command("PrompterContinue", function(args)
  -- 	M.prompter_continue(args)
  -- end, {
  -- 	range = true,
  -- 	nargs = "*",
  -- })
  --
  -- vim.api.nvim_create_user_command("PrompterReplace", function(args)
  -- 	M.prompter_replace(args)
  -- end, {
  -- 	range = true,
  -- 	nargs = "*",
  -- })
  --
  -- vim.api.nvim_create_user_command("PrompterEdit", function(args)
  -- 	M.prompter_edit(args)
  -- end, {
  -- 	range = true,
  -- 	nargs = "+",
  -- })

  -- vim.api.nvim_create_user_command("PrompterBrowser", function(args)
  --   M.browser(args, prompt:join("\n"))
  -- end, {
  --   range = true,
  --   nargs = "*",
  -- })
end

---@param tag string|nil
M.push_prompt = function(tag)
  ---@type Chunk
  local chunk = {
    cwd = vim.fn.getcwd(),
    filepath = vim.api.nvim_buf_get_name(0),
    content = utils.join_lines(utils.get_selected_text()),
    tag = tag,
  }
  prompt:push(chunk)
end

M.pop_prompt = function()
  prompt:pop()
end

M.clear_prompt = function()
  prompt:clear()
end

M.open_prompt_buffer = function()
  -- Get the current window and create a new window on the right
  local current_win = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  local prompt_win = vim.api.nvim_get_current_win()

  -- Create a new buffer and set it as the buffer for the prompt window
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(prompt_win, prompt_buf)

  -- Set the contents of the prompt buffer to the prompt_chunks
  local prompt_lines = vim.split(prompt:join(), "\n")
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, prompt_lines)

  -- Set the buffer options
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = prompt_buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = prompt_buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = prompt_buf })

  -- Set the window options
  vim.api.nvim_set_option_value("number", false, { win = prompt_win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = prompt_win })
  vim.api.nvim_set_option_value("wrap", false, { win = prompt_win })

  -- Switch back to the original window
  vim.api.nvim_set_current_win(current_win)
end

M.add_tag = tags.add_tag

return M
