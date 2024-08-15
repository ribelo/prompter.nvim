local nio = require("nio")
local lyaml = require("lyaml")
local context = require("prompter_nvim.context")

local M = {}

--- Represents a project containing multiple contexts and global settings.
---
--- @class Project
--- @field root_dir string Root directory of the project.
--- @field context Context The main context of the project.
--- @field global_settings table Global settings for the project.
local Project = {}
Project.__index = Project
M.Project = Project

--- Creates a new Project instance.
---
--- @param data table | nil Data to initialize the Project with.
--- @return Project New Project instance.
function Project:new(data)
  data = data or {}
  local obj = setmetatable(data, { __index = self })
  obj.root_dir = data.root_dir or vim.fn.getcwd()
  obj.context = data.context or context.Context:new()
  obj.global_settings = data.global_settings or {}
  return obj
end

--- Loads project configuration from .cerebro/config.yaml
---
--- @return boolean success Whether the configuration was loaded successfully
function Project:load_config()
  local config_path = self.root_dir .. "/.cerebro/config.yaml"
  local file = io.open(config_path, "r")
  if not file then
    vim.notify(
      "Project config file not found: " .. config_path,
      vim.log.levels.WARN,
      { title = "Cerebro" }
    )
    return false
  end

  local content = file:read("*all")
  file:close()

  local ok, config = pcall(lyaml.load, content)
  if not ok or not config then
    vim.notify("Failed to parse project config file", vim.log.levels.ERROR)
    return false
  end

  self.global_settings = config.global_settings or {}
  return self:load_project_files(config.context_files or {})
end

--- Loads project files into the context
---
--- @param project_files string[] List of project file paths
--- @return boolean success Whether all files were loaded successfully
function Project:load_project_files(project_files)
  local success = true
  for _, file_path in ipairs(project_files) do
    local full_path =
      nio.fn.fnamemodify(self.root_dir .. "/.cerebro/" .. file_path, ":p")
    if not self.context:add_file(full_path) then
      vim.notify(
        "Failed to read file: " .. full_path,
        vim.log.levels.WARN,
        { title = "Cerebro" }
      )
    end
  end
  return success
end

--- @return string
function Project:to_xml()
  return self.context:to_xml()
end

return M
