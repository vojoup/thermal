-- thermal :: preview
--
--   nvim -l scripts/preview.lua        (or: make preview)
--
-- Emits one SVG per flavour into preview/, plus an index. Generated from
-- palette.lua like everything else, so a preview can never show colours the
-- theme no longer has.
--
-- SVG rather than HTML or PNG for one reason: GitHub renders SVG inside
-- markdown image tags, so `![](preview/thermal-smoky.svg)` shows the theme on
-- the repo page. That constrains the output -- GitHub sanitises SVG and serves
-- it through a proxy, so this file uses presentation attributes only. No
-- <style> blocks, no external fonts, no scripts. All of those get stripped.

-- Absolutise first (source may be relative when invoked as `nvim -l scripts/...`),
-- then strip the script suffix to get the repo root.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
  :gsub("/scripts/preview%.lua$", "")
local palette = dofile(root .. "/lua/thermal/palette.lua")
local adapter = dofile(root .. "/lua/thermal/catppuccin.lua")

-- Palette keys, not hexes: the sample is written against roles so it stays
-- correct when the palette changes. Mirrors the real highlight assignments --
-- keywords magenta, functions amber, strings frost, types cold, numbers flare.
local SAMPLE = {
  { { "// thresholds are in celsius, not kelvin", "dim", true } },
  {
    { "import", "purple" }, { " { ", "muted" }, { "readFile", "amber" },
    { " } ", "muted" }, { "from", "purple" }, { " ", "fg" },
    { '"node:fs/promises"', "frost" },
  },
  {},
  {
    { "type", "purple" }, { " ", "fg" }, { "Reading", "cold" }, { " ", "fg" },
    { "=", "flare" }, { " {", "muted" },
  },
  { { "  ", "fg" }, { "sensor", "violet" }, { ": ", "muted" }, { "string", "cold" } },
  { { "  ", "fg" }, { "celsius", "violet" }, { ": ", "muted" }, { "number", "cold" } },
  { { "}", "muted" } },
  {},
  {
    { "const", "magenta" }, { " ", "fg" }, { "CEILING", "flare" }, { " ", "fg" },
    { "=", "flare" }, { " ", "fg" }, { "88.5", "flare" },
  },
  {},
  {
    { "export", "purple" }, { " ", "fg" }, { "async function", "magenta" },
    { " ", "fg" }, { "scan", "amber" }, { "(", "muted" }, { "path", "muted" },
    { ": ", "muted" }, { "string", "cold" }, { ") {", "muted" },
  },
  {
    { "  ", "fg" }, { "const", "magenta" }, { " ", "fg" }, { "raw", "fg" },
    { " ", "fg" }, { "=", "flare" }, { " ", "fg" }, { "await", "magenta" },
    { " ", "fg" }, { "readFile", "amber" }, { "(", "muted" }, { "path", "fg" },
    { ", ", "muted" }, { '"utf8"', "frost" }, { ")", "muted" },
    CURSOR = true,
  },
  {
    { "  ", "fg" }, { "if", "magenta" }, { " (", "muted" }, { "!", "flare" },
    { "raw", "fg" }, { ") ", "muted" }, { "throw", "ember" }, { " ", "fg" },
    { "new", "magenta" }, { " ", "fg" }, { "Error", "cold" }, { "(", "muted" },
    { '"empty log"', "frost" }, { ")", "muted" },
  },
  {
    { "  ", "fg" }, { "return", "magenta" }, { " ", "fg" }, { "raw", "fg" },
    { ".", "muted" }, { "split", "amber" }, { "(", "muted" },
    { '"', "frost" }, { "\\n", "ember" }, { '"', "frost" }, { ").", "muted" },
    { "map", "amber", false, "HIT" }, { "(", "muted" }, { "parse", "muted" },
    { ")", "muted" },
  },
  { { "}", "muted" } },
}

local FONT = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
local CH, LH = 8.0, 20 -- forced monospace advance at 13px, line height

local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function swatch_row(out, x, y, w, h, colours, p)
  local cw = w / #colours
  for i, key in ipairs(colours) do
    out[#out + 1] = ('  <rect x="%.1f" y="%d" width="%.1f" height="%d" fill="%s"/>')
      :format(x + (i - 1) * cw, y, cw + 0.6, h, p[key] or key)
  end
end

local function label(out, x, y, text, fill)
  out[#out + 1] = ('  <text x="%d" y="%d" font-family="%s" font-size="11" fill="%s">%s</text>')
    :format(x, y, FONT, fill, esc(text))
end

local function render(name, p)
  local W, PAD = 780, 18
  local ed_y = 44
  local ed_h = 10 + #SAMPLE * LH + 8 + 26
  local ramp_y = ed_y + ed_h + 34
  local ansi_y = ramp_y + 58
  local slack_y = ansi_y + 58
  local H = slack_y + 40

  local out = {
    ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" role="img">')
      :format(W, H, W, H),
    ('  <title>thermal-%s</title>'):format(name),
    ('  <desc>Preview of the thermal-%s Neovim colourscheme: a TypeScript sample on a smoky black background with gray body text and heat-gradient accents, followed by the heat ramp, terminal ANSI palette and Slack sidebar colours.</desc>')
      :format(name),
    ('  <rect width="%d" height="%d" fill="%s"/>'):format(W, H, p.bg_dark),
  }

  label(out, PAD, 26, "thermal-" .. name, p.fg_hi)

  -- editor
  out[#out + 1] = ('  <rect x="%d" y="%d" width="%d" height="%d" rx="6" fill="%s"/>')
    :format(PAD, ed_y, W - PAD * 2, ed_h, p.bg)

  for i, line in ipairs(SAMPLE) do
    local y = ed_y + 10 + i * LH - 6
    if line.CURSOR then
      out[#out + 1] = ('  <rect x="%d" y="%.1f" width="%d" height="%d" fill="%s"/>')
        :format(PAD, y - 14, W - PAD * 2, LH, p.bg_hl)
    end
    out[#out + 1] = ('  <text x="%d" y="%.1f" font-family="%s" font-size="13" fill="%s" text-anchor="end">%d</text>')
      :format(PAD + 34, y, FONT, line.CURSOR and p.amber or p.gutter, i)

    if #line > 0 then
      -- One <text> per span at an explicit x, with textLength forcing the
      -- advance. Letting tspans flow instead means the layout depends on
      -- whatever monospace font the viewer resolves, which drifts -- and
      -- anything positioned by character count (the search-hit rect) drifts
      -- with it. This way the geometry is identical everywhere.
      local col = 0
      for _, sp in ipairs(line) do
        local text, key, italic, hit = sp[1], sp[2], sp[3], sp[4]
        local x, w = PAD + 48 + col * CH, #text * CH
        local fill = p[key]

        if hit == "HIT" then -- search match: the heat line landing on one key
          out[#out + 1] = ('  <rect x="%.1f" y="%.1f" width="%.1f" height="17" fill="%s"/>')
            :format(x, y - 13, w, p.amber)
          fill = p.bg_dark
        end

        if text:match("%S") then
          out[#out + 1] = ('  <text x="%.1f" y="%.1f" font-family="%s" font-size="13" fill="%s"%s textLength="%.1f" lengthAdjust="spacingAndGlyphs" xml:space="preserve">%s</text>')
            :format(x, y, FONT, fill, italic and ' font-style="italic"' or "", w, esc(text))
        end
        col = col + #text
      end
    end
  end

  -- statusline
  local sl_y = ed_y + ed_h - 26
  out[#out + 1] = ('  <rect x="%d" y="%d" width="%d" height="26" fill="%s"/>')
    :format(PAD, sl_y, W - PAD * 2, p.bg_alt)
  out[#out + 1] = ('  <rect x="%d" y="%d" width="72" height="26" fill="%s"/>')
    :format(PAD, sl_y, p.amber)
  out[#out + 1] = ('  <text x="%d" y="%d" font-family="%s" font-size="11" fill="%s">INSERT</text>')
    :format(PAD + 16, sl_y + 17, FONT, p.bg_dark)
  out[#out + 1] = ('  <text x="%d" y="%d" font-family="%s" font-size="11" fill="%s">scan.ts</text>')
    :format(PAD + 88, sl_y + 17, FONT, p.muted)

  -- strips
  label(out, PAD, ramp_y - 8, "heat ramp — cold to white hot", p.muted)
  swatch_row(out, PAD, ramp_y, W - PAD * 2, 28, palette.ramp, p)

  label(out, PAD, ansi_y - 8, "terminal — ANSI 0 to 15, shared with the ghostty theme", p.muted)
  local ansi = adapter.ansi(p)
  swatch_row(out, PAD, ansi_y, W - PAD * 2, 28, ansi, p)

  label(out, PAD, slack_y - 8, "slack sidebar — column, hover menu, active, active text, hover, text, presence, badge", p.muted)
  swatch_row(out, PAD, slack_y, W - PAD * 2, 28,
    { p.bg, p.bg_alt, p.bg_sel, p.amber, p.bg_hl, p.fg, p.frost, p.ember }, p)

  out[#out + 1] = "</svg>"
  return table.concat(out, "\n") .. "\n"
end

local written = {}
local function write(rel, body)
  local path = root .. "/" .. rel
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local f = assert(io.open(path, "wb"))
  f:write(body)
  f:close()
  written[#written + 1] = rel
end

for _, name in ipairs(palette.order) do
  write(("preview/thermal-%s.svg"):format(name), render(name, palette.flavours[name]))
end

local index = {
  "# thermal — previews",
  "",
  "<!-- GENERATED by scripts/preview.lua -- do not edit -->",
  "",
  "Rendered from `lua/thermal/palette.lua`, so these cannot drift from the theme.",
  "Regenerate with `make preview`.",
  "",
}
for _, name in ipairs(palette.order) do
  local p = palette.flavours[name]
  vim.list_extend(index, {
    ("## thermal-%s"):format(name),
    "",
    ("Background `%s` · body `%s` · comments `%s`"):format(p.bg, p.fg, p.dim),
    "",
    ("![thermal-%s](thermal-%s.svg)"):format(name, name),
    "",
  })
end
write("preview/README.md", table.concat(index, "\n"))

print(("thermal: wrote %d preview file(s)"):format(#written))
for _, r in ipairs(written) do print("  " .. r) end
