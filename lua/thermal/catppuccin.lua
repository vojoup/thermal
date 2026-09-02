-- thermal :: catppuccin adapter
--
-- THIS IS THE THROWAWAY FILE. It exists so we inherit catppuccin's ~69 plugin
-- integrations instead of writing 400+ highlight groups by hand. Nothing else
-- in the repo knows catppuccin exists.
--
-- Two jobs:
--   1. translate our semantic palette into catppuccin's 26 named slots
--   2. undo the places where catppuccin reuses a syntax hue for a UI role
--
-- When you drop catppuccin, delete this file and point thermal.init at a
-- highlights module instead. palette.lua does not change.

local M = {}

--- Catppuccin assigns roles to slots, not the other way round: `blue` IS
--- functions, `mauve` IS keywords, `green` IS strings. So we work backwards and
--- put each of our colours in whichever slot already plays that role.
---
--- Slots that Thermal has no distinct colour for are doubled up rather than
--- left to catppuccin's defaults, so nothing renders off-palette.
--- @param p table a flavour from palette.lua
--- @return table catppuccin palette
function M.to_slots(p)
  return {
    -- smoke
    base = p.bg,
    mantle = p.bg_alt,
    crust = p.bg_dark,
    surface0 = p.bg_hl,
    surface1 = p.bg_sel,
    surface2 = p.border,
    overlay0 = p.gutter,
    overlay1 = p.dim,
    overlay2 = p.muted,
    subtext0 = p.muted,
    subtext1 = p.fg_hi,
    text = p.fg,

    -- heat, placed by the role each slot already owns
    blue = p.amber, -- functions
    mauve = p.magenta, -- keywords
    green = p.frost, -- strings, diff add
    peach = p.flare, -- numbers, constants
    yellow = p.cold, -- types
    red = p.ember, -- errors, diff delete
    lavender = p.violet, -- members
    flamingo = p.glow,
    rosewater = p.fg_hi,
    pink = p.magenta,
    maroon = p.flare,
    teal = p.frost,
    sky = p.cold,
    sapphire = p.cold,
  }
end

--- The cost of slot-recolouring: some slots do double duty. `yellow` is both
--- types and warnings; `blue` is both functions and info/directories. Recolour
--- them for syntax and the UI roles come along wrongly. These put them back.
---
--- Returned as a per-flavour `highlight_overrides` function, NOT as
--- `custom_highlights` -- catppuccin assigns custom_highlights to
--- highlight_overrides.all, which would leak these onto real catppuccin
--- flavours if the user has both installed.
--- @param p table a flavour from palette.lua
--- @return function
function M.patches(p)
  return function()
    return {
      -- yellow was spent on types, so warnings lost their colour
      WarningMsg = { fg = p.amber },
      DiagnosticWarn = { fg = p.amber },
      DiagnosticSignWarn = { fg = p.amber },
      DiagnosticFloatingWarn = { fg = p.amber },
      DiagnosticVirtualTextWarn = { fg = p.amber },
      DiagnosticUnderlineWarn = { sp = p.amber, undercurl = true },

      -- blue was spent on functions, so info and directories followed it
      Directory = { fg = p.cold },
      DiagnosticInfo = { fg = p.cold },
      DiagnosticSignInfo = { fg = p.cold },
      DiagnosticFloatingInfo = { fg = p.cold },
      DiagnosticVirtualTextInfo = { fg = p.cold },
      DiagnosticUnderlineInfo = { sp = p.cold, undercurl = true },

      -- the set's own signature: search is the heat line landing on a key
      Search = { fg = p.bg_dark, bg = p.amber },
      IncSearch = { fg = p.bg_dark, bg = p.whitehot, bold = true },
      CurSearch = { fg = p.bg_dark, bg = p.whitehot, bold = true },
      CursorLineNr = { fg = p.amber, bold = true },
    }
  end
end

--- Terminal ANSI 0-15. Consumed by both the Neovim theme and the ghostty build,
--- so the terminal matches the editor by construction.
--- @param p table
--- @return string[] 16 hex values, index 1 = ANSI 0
function M.ansi(p)
  return {
    p.bg_sel, p.ember, p.sage, p.amber, p.cold, p.magenta, p.frost, p.fg,
    p.dim, p.ember_hi, p.sage_hi, p.glow, p.cold_hi, p.magenta_hi, p.frost_hi, p.whitehot,
  }
end

--- Hand everything to catppuccin and load a flavour.
--- @param name string flavour name from palette.lua
--- @param opts table user options (styles, integrations, ...)
function M.setup(name, opts)
  local palette = require("thermal.palette")
  local ctp = require("catppuccin")

  local overrides, patches = {}, {}
  for flav, p in pairs(palette.flavours) do
    local key = "thermal_" .. flav
    -- Registering here rather than shipping a real palette file matters:
    -- catppuccin's setup() hashes user_conf to decide whether to recompile, and
    -- that hash covers color_overrides but NOT our palette files. Palettes in
    -- files would go stale silently. See README "The cache trap".
    ctp.flavours[key] = true
    overrides[key] = M.to_slots(p)
    patches[key] = M.patches(p)
  end

  ctp.setup(vim.tbl_deep_extend("force", {
    color_overrides = overrides,
    highlight_overrides = patches,
    term_colors = true,
    styles = {
      comments = { "italic" },
      conditionals = {},
    },
  }, opts or {}))
end

return M
