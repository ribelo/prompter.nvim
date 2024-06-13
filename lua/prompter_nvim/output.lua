--- @class Content
--- @field id string
--- @field content string
local Content = {}
Content.__index = Content

--- Create a new Content instance.
--- @param id string The ID of the content.
--- @param content string The actual content.
--- @return Content
function Content.new(id, content)
  local self = setmetatable({}, Content)
  self.id = id
  self.content = content
  return self
end

--- @class Output
--- @field contents Content[]
local Output = {}
Output.__index = Output

--- Create a new Output instance.
--- @param contents Content[] The content for the output.
--- @return Output
function Output.new(contents)
  local self = setmetatable({}, Output)
  self.contents = contents
  return self
end

--- Render the output as a markdown string.
--- @return string The markdown representation of the output.
function Output:render()
  local markdown = ""
  for _, content in ipairs(self.contents) do
    markdown = markdown
      .. "#"
      .. tostring(content.id)
      .. "\n"
      .. content.content
      .. "\n\n\n"
  end
  return markdown
end

--- Add content to the output.
--- @param id string The ID of the content.
--- @param content string The actual content.
function Output:add_content(id, content)
  table.insert(self.contents, Content.new(id, content))
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
