local nio = require("nio")

local M = {}

--- @class OutputContent
--- @field id string
--- @field content string
--- @field language string | nil
--- @field tags_to_remove string[] | nil
--- @field usage ClaudeUsage | nil
local Content = {}
Content.__index = Content

M.Content = Content

--- Remove XML tags from the input string.
--- @param text string The input string potentially containing XML tags.
--- @param tags? string[] tags to remove, without brackets.
--- @return string The input string with XML tags removed.
local function remove_xml_tags(text, tags)
  -- Grug remove tags one by one. Simple and clear.
  for _, tag in ipairs(tags or {}) do
    -- Grug make pattern for each tag. Easy to understand.
    local open_tag_pattern = "<" .. tag .. "[^>]*>"
    local close_tag_pattern = "</" .. tag .. ">"
    -- Grug remove tags, keep content.
    text = text:gsub(open_tag_pattern, ""):gsub(close_tag_pattern, "")
  end
  -- Grug give back clean text. Job done.
  return vim.trim(text)
end

--- Remove Markdown code block ticks from the input string.
--- @param text string The input string potentially containing Markdown code block ticks.
--- @return string The input string with Markdown code block ticks removed.
local function remove_markdown_ticks(text)
  -- Use a more flexible pattern to remove leading and trailing triple backticks,
  -- optionally followed by a language identifier.
  return text:gsub("^```[^\n]*\n*(.-)\n*```$", "%1")
end

-- local tmp =
--   '<code lang="lua">\n\n--- Get the content of the last message\n--- @return string? Content of the last message, or nil if there are no messages\nfunction Prompt:last_message_content()\n  if #self.messages == 0 then\n    return nil\n  end\n  local last_message = self.messages[#self.messages]\n  return last_message.role ~= "user" and last_message.content or nil\nend\n</code>'

--- Extract language from code tag
--- @param content string
--- @return string?
local function extract_language(content)
  local lang = content:match('<code%s+lang="([^"]+)"')
  return lang
end

--- Create a new Content instance.
--- @param content string | nil The actual content.
--- @param usage ClaudeUsage | nil The actual content.
--- @param tags_to_remove string[] | nil The actual content.
--- @return OutputContent | nil
function Content:new(content, usage, tags_to_remove)
  if not content then
    return
  end

  local obj = setmetatable({}, { __index = self })
  ---@diagnostic disable-next-line: assign-type-mismatch
  obj.id = os.date("%Y-%m-%d %H:%M:%S")
  obj.content = vim.trim(content)
  obj.language = extract_language(content)
  obj.tags_to_remove = tags_to_remove
  obj.usage = usage

  return obj
end

-- Grug add cleanup method. Simple and clear.
---@return string
function Content:cleanup()
  -- Grug remove XML tags. Keep it simple.
  local content = remove_xml_tags(self.content, self.tags_to_remove)

  -- Grug remove Markdown ticks. Easy peasy.
  content = remove_markdown_ticks(content)

  -- Grug trim content again. Just in case.
  content = vim.trim(content)

  return content
end

--- @class Output
--- @field contents OutputContent[]
local Output = {}
Output.__index = Output

M.Output = Output

--- Create a new Output instance.
--- @return Output
function Output:default()
  return setmetatable({ contents = {} }, { __index = self })
end

--- Render the output as a markdown string.
--- @return string Markdown The markdown representation of the output.
function Output:render()
  local markdown = {}
  table.sort(self.contents, function(a, b)
    return a.id > b.id
  end)

  for _, content in ipairs(self.contents) do
    table.insert(markdown, "# " .. tostring(content.id))

    if content.language then
      table.insert(
        markdown,
        string.format("```%s\n%s\n```", content.language, content:cleanup())
      )
    else
      table.insert(markdown, content:cleanup())
    end

    if content.usage then
      table.insert(markdown, "**Usage:**")
      local usage_info = {
        { "Input tokens", content.usage.input_tokens },
        { "Output tokens", content.usage.output_tokens },
        {
          "Cache creation input tokens",
          content.usage.cache_creation_input_tokens,
        },
        { "Cache read input tokens", content.usage.cache_read_input_tokens },
      }

      for _, info in ipairs(usage_info) do
        if info[2] then
          table.insert(markdown, string.format("- %s: %s", info[1], info[2]))
        end
      end
    end

    table.insert(markdown, "") -- Add an empty line between entries
  end

  return table.concat(markdown, "\n")
end

--- Add content to the output.
--- @param content string | OutputContent The actual content.
--- @param tags_to_remove string[]? The actual content.
function Output:add_content(content, tags_to_remove)
  table.insert(
    self.contents,
    type(content) == "string" and Content:new(content, tags_to_remove)
      or content
  )
  M.refresh_output_buffer()
end

--- Remove content from the output by ID.
--- @param id number The ID of the content to remove.
function Output:remove_content(id)
  for i, content in ipairs(self.contents) do
    if content.id == id then
      table.remove(self.contents, i)
      M.refresh_output_buffer()
      break
    end
  end
end

--- Clear all content from the output.
function Output:clear()
  self.contents = {}
  M.refresh_output_buffer()
end

local output_buf = nil

---@type Output
local output = Output:default()

M.get_output_buffer = function()
  if not output_buf or not nio.api.nvim_buf_is_valid(output_buf) then
    output_buf = nio.api.nvim_create_buf(false, true)
    local output_buf_name = "prompter://output"
    nio.api.nvim_buf_set_name(output_buf, output_buf_name)

    local buf_options = {
      buftype = "nofile",
      bufhidden = "wipe",
      swapfile = false,
      filetype = "markdown",
    }
    for option, value in pairs(buf_options) do
      nio.api.nvim_set_option_value(option, value, { buf = output_buf })
    end
  end
  return output_buf
end

M.open_output_window = function()
  -- Create a new window on the right
  local output_win = nio.api.nvim_open_win(0, true, {
    split = "right",
  })

  local buf = M.get_output_buffer()

  -- Set the buffer options
  local buf_options = {
    buftype = "nofile",
    bufhidden = "wipe",
    swapfile = false,
    filetype = "markdown",
  }
  for option, value in pairs(buf_options) do
    nio.api.nvim_set_option_value(option, value, { buf = buf })
  end

  nio.api.nvim_win_set_buf(output_win, buf)
  local output_lines = vim.split(output:render(), "\n")
  nio.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)

  -- Set the window options
  local win_options = {
    number = false,
    relativenumber = false,
    wrap = false,
  }

  for option, value in pairs(win_options) do
    nio.api.nvim_set_option_value(option, value, { win = output_win })
  end
end

M.close_output_window = function()
  -- Find the window with the OUTPUT_BUF
  local win_id = vim.fn.win_findbuf(output_buf)[1]

  if win_id then
    -- Close the window
    nio.api.nvim_win_close(win_id, false)
  else
    vim.notify("Output window not found", vim.log.levels.WARN)
  end
end

M.toggle_output_window = function()
  local win_id = vim.fn.win_findbuf(output_buf)[1]

  if win_id then
    M.close_output_window()
  else
    M.open_output_window()
  end
end

M.refresh_output_buffer = function()
  local buf = M.get_output_buffer()
  local output_lines = vim.split(output:render(), "\n")
  nio.api.nvim_buf_set_lines(buf, 0, -1, false, output_lines)
end

--- @generic T
--- @param cb fun(o: Output): T
--- @return T
M.with_global_output = function(cb)
  return cb(output)
end

return M
