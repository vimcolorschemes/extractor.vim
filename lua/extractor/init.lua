local Color = require("extractor.util.color")
local System = require("extractor.util.system")
local Table = require("extractor.util.table")
local Vim = require("extractor.util.vim")

local M = {}

local DEFAULT_COLOR_GROUP_NAMES = {
  "Normal",
  "StatusLine",
  "Cursor",
  "LineNr",
  "CursorLine",
  "CursorLineNr",
}

--- For each installed colorscheme, try both light and dark backgrounds, then
--- extracts the color groups and writes them to a file.
--- @param output_path string The path to write the extracted color groups to. Optional.
function M.extract(output_path)
  print("Starting color group extraction...")
  if output_path then
    print("Output path: " .. output_path)
  end

  local colorschemes = Vim.get_colorschemes()
  if #colorschemes == 0 then
    error("No custom colorschemes found.")
  end
  print("Colorschemes to analyze: " .. Table.to_json(colorschemes))

  local initial_colorscheme = vim.fn.execute("colorscheme")

  local color_group_names = Vim.get_color_group_names_in_buffer()
  Table.insert_many(color_group_names, unpack(DEFAULT_COLOR_GROUP_NAMES))
  print("Color groups to analyze: " .. Table.to_json(color_group_names))

  local data = {}

  for _, colorscheme in ipairs(colorschemes) do
    local success, err = pcall(function()
      vim.cmd("silent! colorscheme " .. colorscheme)
    end)
    if not success then
      print("Failed to load colorscheme " .. colorscheme .. ": " .. err)
      goto next_colorscheme
    end

    for _, background in ipairs({ "light", "dark" }) do
      success, err = pcall(function()
        vim.cmd("set background=" .. background)
      end)
      if not success then
        print("Failed to set background to " .. background .. ": " .. err)
        goto next_background
      end

      print("Extracting color groups for colorscheme " .. colorscheme .. " with background " .. background .. "...")

      local normal_bg_color_value = Vim.get_color_group_value("Normal", "bg#") or "#000000"

      local current_background = Color.is_light(normal_bg_color_value) and "light" or "dark"

      if background ~= current_background then
        print(colorscheme .. " has no " .. background .. " background.")
        goto next_background
      end

      data[colorscheme] = data[colorscheme] or {}
      data[colorscheme][background] = data[colorscheme][background] or {}

      local normal_fg_color_value = Vim.get_color_group_value("Normal", "fg#") or "#ffffff"

      for _, color_group_name in ipairs(color_group_names) do
        local fg_color_value = Vim.get_color_group_value(color_group_name, "fg#") or normal_fg_color_value
        local bg_color_value = Vim.get_color_group_value(color_group_name, "bg#") or normal_bg_color_value
        data[colorscheme][background][color_group_name] = { fg = fg_color_value, bg = bg_color_value }
      end

      ::next_background::
    end
    ::next_colorscheme::
  end

  local json = Table.to_json(data)

  if output_path then
    System.write(output_path, json)
    print("Color groups extracted to " .. output_path)
  end

  pcall(function()
    vim.cmd("silent! colorscheme " .. initial_colorscheme)
  end)

  print("Result: " .. json)
end

--- Returns a list of installed custom colorschemes.
--- @param output_path string The path to write the extracted color groups to. Optional.
--- @return table The extracted color groups.
function M.colorschemes(output_path)
  local colorschemes = Vim.get_colorschemes()
  local json = Table.to_json(colorschemes)
  print("Installed colorschemes: " .. json)
  if output_path then
    System.write(output_path, json)
    print("Installed colorschemes extracted to " .. output_path)
  end
  return colorschemes
end

return M
