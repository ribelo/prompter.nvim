--- @class OutputContent
--- @field id string
--- @field content string
--- @field language string?
local Content = {}
Content.__index = Content

--- Extracts the language from a Markdown code block.
---
---@param text string The input string potentially containing a Markdown code block.
---@return string|nil The language specified in the code block, or nil if no language is found.
local function extract_markdown_language(text)
  -- Use a capturing group to extract the language identifier (if any).
  local _, language = text:match("^```(?[^\n]*)")
  return language and language:trim() or nil
end

--- Remove XML tags from the input string.
--- @param text string The input string potentially containing XML tags.
--- @return string The input string with XML tags removed.
local function remove_xml_tags(text)
  -- Use a simple pattern to match and remove anything between '<' and '>'.
  return text:gsub("<[^>]+>", "")
end

--- Remove Markdown code block ticks from the input string.
--- @param text string The input string potentially containing Markdown code block ticks.
--- @return string The input string with Markdown code block ticks removed.
local function remove_markdown_ticks(text)
  -- Use a more flexible pattern to remove leading and trailing triple backticks,
  -- optionally followed by a language identifier.
  return text:gsub("^```[^\n]*\n*(.-)\n*```$", "%1")
end

--- Create a new Content instance.
--- @param content string? The actual content.
--- @return OutputContent?
function Content:new(content)
  if not content then
    return
  end

  local obj = setmetatable({}, { __index = self })
  ---@diagnostic disable-next-line: assign-type-mismatch
  obj.id = os.date("%Y-%m-%d %H:%M:%S")
  -- local cleaned_text = remove_xml_tags(content)
  obj.content = vim.trim(remove_markdown_ticks(content))
  obj.language = extract_markdown_language(content)

  return obj
end

--- @class Output
--- @field contents OutputContent[]
local Output = {}
Output.__index = Output

--- Create a new Output instance.
--- @return Output
function Output:default()
  return setmetatable({ contents = {} }, { __index = self })
end

--- Render the output as a markdown string.
--- @return string The markdown representation of the output.
function Output:render()
  local markdown = ""
  for _, content in ipairs(self.contents) do
    markdown = markdown .. "# " .. tostring(content.id) .. "\n"

    -- Wrap content in Markdown code block if language is defined
    if content.language then
      ---@diagnostic disable-next-line: no-unknown
      markdown = markdown
        .. "```"
        .. content.language
        .. "\n"
        .. content.content
        .. "\n```\n\n\n"
    else
      ---@diagnostic disable-next-line: no-unknown
      markdown = markdown .. content.content .. "\n\n"
    end
  end
  return markdown
end

--- Add content to the output.
--- @param content string | OutputContent The actual content.
function Output:add_content(content)
  table.insert(
    self.contents,
    type(content) == "string" and Content:new(content) or content
  )
end

--- Remove content from the output by ID.
--- @param id number The ID of the content to remove.
function Output:remove_content(id)
  for i, content in ipairs(self.contents) do
    if content.id == id then
      table.remove(self.contents, i)
      break
    end
  end
end

--- Clear all content from the output.
function Output:clear()
  self.contents = {}
end

return {
  Content = Content,
  Output = Output,
}
