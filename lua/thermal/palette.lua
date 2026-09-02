-- thermal :: palette
--
-- THE SOURCE OF TRUTH. Every other file in this repo is derived from this one.
-- Edit here, run `nvim -l scripts/build.lua`, commit.
--
-- Derived from the PBTfans "Thermal" keycap set by Matthew Encina (Mod Musings):
-- smoky black bases, dark gray translucent tops, gray legends, and one
-- heat-signature gradient across R3. No official hex values are published for
-- the set, so these are matched to the documented colorway and the
-- thermal-imaging ramp it is named for.
--
-- Names here are OURS, not any engine's. That is deliberate: the catppuccin
-- adapter is a translation layer, and when it goes away this file does not
-- change. See README "Dropping catppuccin".
--
-- Contrast: every heat colour clears WCAG AA (4.5:1) against its own flavour's
-- bg. `dim` sits at ~3.3:1 on purpose -- recessed, but above the 3:1 floor.
-- Re-check with `nvim -l scripts/contrast.lua` after editing.

local M = {}

--- Shared across all flavours: the heat ramp and the legend greys.
--- Flavours vary the smoke, not the heat.
local heat = {
  cold = "#6A8CAF", -- steel blue   : types, modules, info
  frost = "#74AAA6", -- teal         : strings, hints, diff add
  violet = "#8A79C8", -- fields, properties
  purple = "#AC6DBC", -- imports, modifiers, macros
  magenta = "#D0568E", -- keywords, control flow
  ember = "#E2564F", -- errors, escapes, diff delete
  flare = "#EF7F3C", -- numbers, constants, operators
  amber = "#F6A83F", -- functions, search, cursor line number
  glow = "#F2CE6E", -- regex, fuzzy-match characters
  whitehot = "#FBF3E8", -- jump labels, incremental search

  -- bright terminal counterparts (ANSI 9-14)
  cold_hi = "#85A6C8",
  frost_hi = "#92C6C2",
  magenta_hi = "#DE79A6",
  ember_hi = "#F06A5E",

  -- The set contains no green. This exists ONLY for terminal ANSI slot 2 --
  -- `ls` and `git diff` are unusable without one -- and is desaturated hard
  -- enough to sit inside the smoke. Never used for syntax; diffs use frost.
  sage = "#7FA88C",
  sage_hi = "#93BC9E",
}

local legends = {
  gutter = "#52525C", -- line numbers, listchars
  dim = "#666671", -- comments, folds
  muted = "#84848F", -- parameters, punctuation, unfocused text
  fg = "#C2C2CB", -- body text; the legend gray
  fg_hi = "#E7E7EE", -- cursor, active UI
  border = "#383842", -- splits, float borders
}

--- Build a flavour from its smoke levels.
local function flavour(smoke)
  return vim.tbl_extend("error", smoke, legends, heat)
end

M.flavours = {
  -- the set as photographed
  smoky = flavour {
    bg = "#101014",
    bg_dark = "#0A0A0C",
    bg_alt = "#16161B",
    bg_hl = "#1D1D23",
    bg_sel = "#2A2A32",
  },
  -- the same caps in a dark room
  void = flavour {
    bg = "#08080A",
    bg_dark = "#000000",
    bg_alt = "#0E0E12",
    bg_hl = "#16161B",
    bg_sel = "#24242B",
  },
  -- under a key light
  ash = flavour {
    bg = "#16161B",
    bg_dark = "#101014",
    bg_alt = "#1D1D23",
    bg_hl = "#24242B",
    bg_sel = "#33333D",
  },
}

--- Order matters for the ghostty/slack builds and for `:Thermal` completion.
M.order = { "smoky", "void", "ash" }

--- The flavour used by plain `:colorscheme thermal`.
M.default = "smoky"

--- The heat ramp coldest to hottest, for building your own gradient strip.
M.ramp = {
  "cold", "frost", "violet", "purple", "magenta",
  "ember", "flare", "amber", "glow", "whitehot",
}

return M
