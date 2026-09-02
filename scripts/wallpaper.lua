-- thermal :: wallpaper
--
--   nvim -l scripts/wallpaper.lua
--
-- Generates one wallpaper per flavour from lua/thermal/palette.lua, so the
-- desktop can't drift from the terminal and editor. The background IS the
-- flavour's bg, so the wallpaper pairs exactly with the matching theme.
--
-- Uses only Neovim -- no ImageMagick, no cargo. PNG is written by hand with
-- stored (uncompressed) zlib blocks, which makes a 4K file large (~25 MB) but
-- needs no compressor. The files are .gitignore'd and regenerated on demand.
--
-- Resolution defaults to 4K 16:9; override per run:
--   THERMAL_WP_WIDTH=5120 THERMAL_WP_HEIGHT=2880 nvim -l scripts/wallpaper.lua
--
-- MOTIFS are a table of builders keyed by name (see `motifs` below). Adding a
-- new look is one function that returns the raw RGB scanline payload; the PNG
-- encoder and the flavour loop don't change.

local bit = require("bit")

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
  :gsub("/scripts/wallpaper%.lua$", "")
local palette = dofile(root .. "/lua/thermal/palette.lua")

local W = tonumber(os.getenv("THERMAL_WP_WIDTH")) or 3840
local H = tonumber(os.getenv("THERMAL_WP_HEIGHT")) or 2160

-------------------------------------------------------------- PNG encoder ----
-- Truecolor 8-bit, filter 0 (None) on every scanline, one stored deflate
-- stream. Correct and dependency-free; not small.

local function u32be(n)
  return string.char(
    math.floor(n / 16777216) % 256,
    math.floor(n / 65536) % 256,
    math.floor(n / 256) % 256,
    n % 256)
end

local function u16le(n)
  return string.char(n % 256, math.floor(n / 256) % 256)
end

local crc_table = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do
    if bit.band(c, 1) ~= 0 then
      c = bit.bxor(0xEDB88320, bit.rshift(c, 1))
    else
      c = bit.rshift(c, 1)
    end
  end
  crc_table[i] = c
end

local function crc32(s)
  local crc = -1 -- 0xFFFFFFFF in 32-bit
  for i = 1, #s do
    crc = bit.bxor(bit.rshift(crc, 8),
      crc_table[bit.band(bit.bxor(crc, string.byte(s, i)), 0xff)])
  end
  crc = bit.bxor(crc, -1)
  return string.char(
    bit.band(bit.rshift(crc, 24), 0xff),
    bit.band(bit.rshift(crc, 16), 0xff),
    bit.band(bit.rshift(crc, 8), 0xff),
    bit.band(crc, 0xff))
end

local function adler32(s)
  local a, b, n, i = 1, 0, #s, 1
  while i <= n do
    local stop = math.min(i + 5551, n)
    for j = i, stop do
      a = a + string.byte(s, j)
      b = b + a
    end
    a = a % 65521
    b = b % 65521
    i = stop + 1
  end
  return u32be(b * 65536 + a)
end

local function chunk(typ, data)
  local body = typ .. data
  return u32be(#data) .. body .. crc32(body)
end

--- Wrap raw filtered scanlines in a zlib stream of stored blocks.
local function zlib_stored(payload)
  local parts = { string.char(0x78, 0x01) } -- zlib header, FLEVEL=0
  local n, pos = #payload, 1
  repeat
    local len = math.min(65535, n - pos + 1)
    local last = (pos + len - 1) >= n
    parts[#parts + 1] = string.char(last and 1 or 0)
    parts[#parts + 1] = u16le(len)
    parts[#parts + 1] = u16le(bit.band(bit.bnot(len), 0xffff))
    parts[#parts + 1] = payload:sub(pos, pos + len - 1)
    pos = pos + len
  until pos > n
  parts[#parts + 1] = adler32(payload)
  return table.concat(parts)
end

--- payload: raw bytes, H rows of (1 filter byte + W*3 RGB). Returns a PNG.
local function encode_png(payload)
  return table.concat {
    string.char(137, 80, 78, 71, 13, 10, 26, 10),
    chunk("IHDR", u32be(W) .. u32be(H) .. string.char(8, 2, 0, 0, 0)),
    chunk("IDAT", zlib_stored(payload)),
    chunk("IEND", ""),
  }
end

------------------------------------------------------------------ colour -----
local function hex2rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16),
    tonumber(hex:sub(3, 4), 16),
    tonumber(hex:sub(5, 6), 16)
end

local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end
local function smooth(t) t = clamp01(t); return t * t * (3 - 2 * t) end

local function blend(bg, fg, a)
  local v = bg + (fg - bg) * a
  return math.floor((v < 0 and 0 or (v > 255 and 255 or v)) + 0.5)
end

------------------------------------------------------------------ motifs -----
-- Each motif is (flavour palette) -> raw scanline payload string.

--- Single heat line: the Thermal Accent Row. The whole field is smoke; one
--- thin horizontal band carries the heat ramp (cold -> whitehot), softly glowed
--- and faded at the ends so it never hits the screen edge.
local function motif_line(p)
  local br, bg, bb = hex2rgb(p.bg)

  -- heat ramp sampled per column, coldest at the left
  local stops = {}
  for _, key in ipairs(palette.ramp) do stops[#stops + 1] = { hex2rgb(p[key]) } end
  local m = #stops
  local heat = {} -- heat[x] = {r,g,b}
  for x = 1, W do
    local t = (x - 1) / (W - 1) * (m - 1) + 1
    local i = math.floor(t)
    local f = t - i
    local a, b = stops[i], stops[math.min(i + 1, m)]
    heat[x] = {
      a[1] + (b[1] - a[1]) * f,
      a[2] + (b[2] - a[2]) * f,
      a[3] + (b[3] - a[3]) * f,
    }
  end

  -- horizontal edge fade over the outer 12%
  local fade = W * 0.12
  local edge = {}
  for x = 1, W do
    edge[x] = smooth(math.min((x - 1) / fade, (W - x) / fade, 1))
  end

  -- vertical glow around the R3-ish line (~42% down)
  local line_y = math.floor(H * 0.42 + 0.5)
  local sigma = math.max(6, math.floor(H * 0.008 + 0.5))
  local half = 5 * sigma

  local flat = "\0" .. string.rep(string.char(br, bg, bb), W)
  local rows = {}
  for y = 1, H do
    local dy = y - line_y
    if dy >= -half and dy <= half then
      local av = math.exp(-(dy * dy) / (2 * sigma * sigma))
      local t = {}
      for x = 1, W do
        local a = av * edge[x]
        local h = heat[x]
        t[x] = string.char(
          blend(br, h[1], a), blend(bg, h[2], a), blend(bb, h[3], a))
      end
      rows[y] = "\0" .. table.concat(t)
    else
      rows[y] = flat
    end
  end
  return table.concat(rows)
end

local motifs = {
  line = motif_line,
}
-- Order also decides which motifs `make wallpaper` emits. Add names here.
local motif_order = { "line" }

-------------------------------------------------------------------- write ----
vim.fn.mkdir(root .. "/wallpaper", "p")
local written = {}
for _, flavour in ipairs(palette.order) do
  local p = palette.flavours[flavour]
  for _, motif in ipairs(motif_order) do
    local png = encode_png(motifs[motif](p))
    local rel = ("wallpaper/thermal-%s-%s.png"):format(flavour, motif)
    local f = assert(io.open(root .. "/" .. rel, "wb"))
    f:write(png)
    f:close()
    table.insert(written, rel)
    print(("  %s  (%dx%d, %.1f MB)"):format(rel, W, H, #png / 1048576))
  end
end

-- README: set-as-wallpaper instructions. Committed; the PNGs are not.
local list = {}
for _, flavour in ipairs(palette.order) do
  for _, motif in ipairs(motif_order) do
    list[#list + 1] = ("- `wallpaper/thermal-%s-%s.png`"):format(flavour, motif)
  end
end
local readme = table.concat({
  "# thermal — wallpaper",
  "",
  "<!-- GENERATED by scripts/wallpaper.lua -- do not edit -->",
  "",
  "One wallpaper per flavour, generated from `lua/thermal/palette.lua`, so the",
  "desktop pairs exactly with the terminal and editor. The background is the",
  "flavour's own `bg`; a single heat line carries the accent.",
  "",
  "The PNGs are large (4K, uncompressed) and **not committed**. Generate them:",
  "",
  "```",
  "make wallpaper",
  "```",
  "",
  "Different resolution:",
  "",
  "```",
  "THERMAL_WP_WIDTH=5120 THERMAL_WP_HEIGHT=2880 make wallpaper",
  "```",
  "",
  "Produces:",
  "",
  table.concat(list, "\n"),
  "",
  "Set one (macOS): System Settings → Wallpaper → Add Photo, or",
  "",
  "```",
  ("osascript -e 'tell application \"System Events\" to set picture of every desktop to \"'\"$PWD/wallpaper/thermal-%s-line.png\"'\"'"):format(palette.default),
  "```",
  "",
  "Pair `thermal-<flavour>` with the matching terminal/editor flavour.",
  "",
}, "\n")
local rf = assert(io.open(root .. "/wallpaper/README.md", "wb"))
rf:write(readme)
rf:close()
table.insert(written, "wallpaper/README.md")

print(("thermal: wrote %d wallpaper file(s)"):format(#written))
