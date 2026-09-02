-- thermal
--
-- A dark, low-contrast theme based on the PBTfans "Thermal" keycap set.
-- Neovim, Ghostty and Slack all generate from lua/thermal/palette.lua.
--
--   require("thermal").setup({})
--   vim.cmd.colorscheme("thermal")
--
-- This file is the public API and deliberately knows nothing about the engine
-- underneath. Swapping engines means changing `engine` below and nothing else.

local M = {}

local palette = require("thermal.palette")
local engine = require("thermal.catppuccin")

M.options = {}

--- @param opts? table passed through to the engine (styles, integrations, ...)
function M.setup(opts)
  M.options = opts or {}
  engine.setup(palette.default, M.options)
end

--- Apply a flavour.
--- @param name? string one of palette.order; defaults to palette.default
function M.load(name)
  name = name or palette.default

  if not palette.flavours[name] then
    vim.notify(
      ("thermal: unknown flavour '%s' (have: %s)"):format(name, table.concat(palette.order, ", ")),
      vim.log.levels.ERROR
    )
    return
  end

  -- setup() is idempotent but cheap to skip; catppuccin also self-setups on
  -- load, which would miss our flavour registration, so always go through here.
  engine.setup(name, M.options)
  require("catppuccin").load("thermal_" .. name)

  -- The engine sets colors_name to its own value. Take it back: anything
  -- keying off colors_name (lualine `theme = "auto"`, some statuslines) should
  -- see a thermal, not a catppuccin.
  vim.g.colors_name = name == palette.default and "thermal" or ("thermal-" .. name)

  -- The engine also derives terminal colours from its own slot mapping, which
  -- puts frost in the green slot -- so `:terminal` would disagree with the
  -- generated ghostty theme. Both must come from one place: engine.ansi().
  local ansi = engine.ansi(palette.flavours[name])
  for i = 0, 15 do
    vim.g["terminal_color_" .. i] = ansi[i + 1]
  end
end

--- The active flavour's palette, in OUR names, for statuslines and configs.
--- @param name? string
--- @return table
function M.palette(name)
  return palette.flavours[name or palette.default]
end

--- Heat ramp coldest to hottest, resolved to hex, for building gradient strips.
--- @param name? string
--- @return string[]
function M.ramp(name)
  local p = M.palette(name)
  return vim.tbl_map(function(key) return p[key] end, palette.ramp)
end

M.flavours = palette.order

--- Repo root, so the commands below can read the generated ghostty/slack files
--- regardless of where the plugin was installed.
local root = vim.fn.fnamemodify(
  debug.getinfo(1, "S").source:sub(2):gsub("/lua/thermal/init%.lua$", ""), ":p"):gsub("/$", "")

local targets = {
  slack = function(flav) return ("%s/slack/thermal-%s.txt"):format(root, flav) end,
  ghostty = function(flav) return ("%s/ghostty/thermal-%s"):format(root, flav) end,
}

--- :ThermalCopy slack void      -> Slack theme string on the clipboard
--- :ThermalCopy ghostty ash     -> whole ghostty theme on the clipboard
--- :ThermalCopy slack           -> default flavour
vim.api.nvim_create_user_command("ThermalCopy", function(inp)
  local target, flav = inp.fargs[1], inp.fargs[2] or palette.default

  if not targets[target] then
    return vim.notify("thermal: expected 'slack' or 'ghostty'", vim.log.levels.ERROR)
  end
  if not palette.flavours[flav] then
    return vim.notify(
      ("thermal: unknown flavour '%s' (have: %s)"):format(flav, table.concat(palette.order, ", ")),
      vim.log.levels.ERROR
    )
  end

  local path = targets[target](flav)
  local f = io.open(path)
  if not f then
    return vim.notify(
      ("thermal: %s missing -- run `nvim -l scripts/build.lua` in %s"):format(path, root),
      vim.log.levels.ERROR
    )
  end
  local body = vim.trim(f:read("*a"))
  f:close()

  vim.fn.setreg("+", body)
  vim.fn.setreg('"', body)

  if target == "slack" then
    vim.notify(("thermal-%s copied. Slack: Preferences > Appearance > Custom theme"):format(flav))
  else
    vim.notify(("thermal-%s copied. Save as ~/.config/ghostty/themes/thermal-%s"):format(flav, flav))
  end
end, {
  nargs = "+",
  desc = "Copy a thermal Slack string or Ghostty theme to the clipboard",
  complete = function(lead, line)
    local done = #vim.split(vim.trim(line), "%s+")
    local opts = (done > 2 or line:match("%s$") and done > 1)
      and palette.order
      or vim.tbl_keys(targets)
    return vim.tbl_filter(function(v) return vim.startswith(v, lead) end, opts)
  end,
})

vim.api.nvim_create_user_command("Thermal", function(inp)
  vim.cmd.colorscheme(inp.args == palette.default and "thermal" or ("thermal-" .. inp.args))
end, {
  nargs = 1,
  complete = function(line)
    return vim.tbl_filter(function(v) return vim.startswith(v, line) end, palette.order)
  end,
})

return M
