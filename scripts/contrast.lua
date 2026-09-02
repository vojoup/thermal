-- thermal :: contrast check
--
--   nvim -l scripts/contrast.lua
--
-- "Low contrast" describes the keycaps' legends, not what you should have to
-- read for eight hours. This asserts every heat colour clears WCAG AA (4.5:1)
-- against its own flavour's background, and that the recessed greys still clear
-- the 3:1 floor. Run it after editing the palette; exits non-zero on failure so
-- it works as a pre-commit hook or CI step.

-- Absolutise first (source may be relative when invoked as `nvim -l scripts/...`),
-- then strip the script suffix to get the repo root.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
  :gsub("/scripts/contrast%.lua$", "")
local palette = dofile(root .. "/lua/thermal/palette.lua")

local function luminance(hex)
  local function channel(c)
    c = tonumber(c, 16) / 255
    return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
  end
  local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
  assert(r, "not a hex colour: " .. tostring(hex))
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end

local function ratio(a, b)
  local la, lb = luminance(a), luminance(b)
  if la < lb then la, lb = lb, la end
  return (la + 0.05) / (lb + 0.05)
end

-- key = minimum acceptable ratio against bg
local floors = {
  fg = 7.0, muted = 4.5, dim = 3.0, gutter = 2.0,
  cold = 4.5, frost = 4.5, violet = 4.5, purple = 4.5, magenta = 4.5,
  ember = 4.5, flare = 4.5, amber = 4.5, glow = 4.5, sage = 4.5,
}

local failures = 0
for _, name in ipairs(palette.order) do
  local p = palette.flavours[name]
  print(("\n%s  (bg %s)"):format(name, p.bg))
  local worst, worst_key = math.huge, nil
  for key, floor in pairs(floors) do
    local r = ratio(p.bg, p[key])
    if r < worst then worst, worst_key = r, key end
    if r < floor then
      failures = failures + 1
      print(("  FAIL %-9s %s  %.2f:1  (needs %.1f:1)"):format(key, p[key], r, floor))
    end
  end
  print(("  ok, worst is %s at %.2f:1"):format(worst_key, worst))
end

if failures > 0 then
  print(("\n%d contrast failure(s)"):format(failures))
  vim.cmd("cquit 1")
end
print("\nall flavours pass")
