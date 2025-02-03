local Color = require("extractor.util.color")
local System = require("extractor.util.system")
local Table = require("extractor.util.table")
local Vim = require("extractor.util.vim")

local M = {}

local function is_colorschemes_valid(colorschemes)
  return type(colorschemes) == "table" and #colorschemes > 0
end

local function is_output_path_valid(output_path)
  return type(output_path) == "string" and #output_path > 0
end

--- For each installed colorscheme, try both light and dark backgrounds, then
--- extracts the color groups and writes them to a file.
--- @param output_path string The path to write the extracted color groups to. Optional.
function M.extract(output_path)
  local colorschemes = Vim.get_colorschemes()
  if not is_colorschemes_valid(colorschemes) then
    error("No valid colorschemes.")
  end

  local color_group_names = Vim.get_color_group_names()

  local data = {}

  for _, colorscheme in ipairs(colorschemes) do
    pcall(function()
      vim.cmd("silent! colorscheme " .. colorscheme)
    end)

    local configured_colorscheme = vim.fn.execute("colorscheme"):match("^%s*(.-)%s*$")
    if configured_colorscheme ~= colorscheme then
      goto next_colorscheme
    end

    for _, background in ipairs({ "light", "dark" }) do
      pcall(function()
        vim.cmd("set background=" .. background)
      end)

      configured_colorscheme = vim.fn.execute("colorscheme"):match("^%s*(.-)%s*$")
      if configured_colorscheme ~= colorscheme then
        pcall(function()
          vim.cmd("silent! colorscheme " .. colorscheme)
        end)
        goto next_background
      end

      local configured_background = vim.o.background
      if configured_background ~= background then
        goto next_background
      end

      local normal_bg_color_value = Vim.get_color_group_value("Normal", "bg#") or "#000000"

      local is_current_background_light = Color.is_light(normal_bg_color_value)
      if
        is_current_background_light and background == "dark"
        or not is_current_background_light and background == "light"
      then
        goto next_background
      end

      data[configured_colorscheme] = data[configured_colorscheme] or {}
      data[configured_colorscheme][background] = data[configured_colorscheme][background] or {}

      local normal_fg_color_value = Vim.get_color_group_value("Normal", "fg#") or "#ffffff"

      for _, color_group_name in ipairs(color_group_names) do
        table.insert(data[configured_colorscheme][background], {
          name = color_group_name .. "Fg",
          hexCode = Vim.get_color_group_value(color_group_name, "fg#") or normal_fg_color_value,
        })

        table.insert(data[configured_colorscheme][background], {
          name = color_group_name .. "Bg",
          hexCode = Vim.get_color_group_value(color_group_name, "bg#") or normal_bg_color_value,
        })
      end

      ::next_background::
    end

    ::next_colorscheme::
  end

  local json = Table.to_json(data)

  if is_output_path_valid(output_path) then
    System.write(output_path, json)
  end
end

--- Returns a list of installed colorschemes.
--- @param output_path string The path to write the extracted color groups to. Optional.
--- @return table The colorschemes.
function M.colorschemes(output_path)
  local colorschemes = Vim.get_colorschemes()
  local json = Table.to_json(colorschemes)
  if is_output_path_valid(output_path) then
    System.write(output_path, json)
  end
  return colorschemes
end

return M
