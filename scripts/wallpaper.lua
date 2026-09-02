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

-- The `flow` motif is randomised. Its seed is printed and baked into the flow
-- filenames; set THERMAL_WP_SEED to reproduce a run. Kept to 6 digits so it
-- stays short in a filename.
local base_seed = tonumber(os.getenv("THERMAL_WP_SEED")) or (os.time() % 1000000)
local flow_calls = 0

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

local function mixf(a, b, t) return a + (b - a) * t end

-- Ordered (Bayer 8x8) dithering. The palette's dark ranges span only a handful
-- of 8-bit levels, so smooth gradients posterise into visible bands; a threshold
-- dither at quantise time scatters the rounding and the bands disappear, with no
-- visible noise. q() turns a float channel + pixel position into a byte.
local bayer = {
  0, 32, 8, 40, 2, 34, 10, 42,
  48, 16, 56, 24, 50, 18, 58, 26,
  12, 44, 4, 36, 14, 46, 6, 38,
  60, 28, 52, 20, 62, 30, 54, 22,
  3, 35, 11, 43, 1, 33, 9, 41,
  51, 19, 59, 27, 49, 17, 57, 25,
  15, 47, 7, 39, 13, 45, 5, 37,
  63, 31, 55, 23, 61, 29, 53, 21,
}
local function q(v, x, y)
  if v < 0 then v = 0 elseif v > 255 then v = 255 end
  local r = math.floor(v + (bayer[((y - 1) % 8) * 8 + ((x - 1) % 8) + 1] + 0.5) / 64)
  return r > 255 and 255 or r
end

-- Deterministic per-pixel film grain (xorshift hash of x,y), so the smoke field
-- and cap faces carry the visual noise of the real render. Same seed every run.
local NOISE = 3.4 -- +/- amplitude on the smoke background
local function grain(x, y)
  -- hash the pixel to pseudo-random [0,1). The x*y cross term breaks the
  -- diagonal structure a plain sin(ax+by) hash leaves, so it reads as grain,
  -- not a woven pattern.
  local s = math.sin(x * 12.9898 + y * 78.233 + x * y * 0.000131) * 43758.5453
  return (s - math.floor(s) - 0.5) * 2 * NOISE
end

------------------------------------------------------------------ motifs -----
-- Each motif is (flavour palette) -> raw scanline payload string.

--- Single heat line: the Thermal Accent Row. The whole field is smoke; one
--- thin horizontal band carries the heat ramp (cold -> whitehot), softly glowed
--- and faded at the ends so it never hits the screen edge.
local function motif_line(p, bg_rows)
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

  local rows = {}
  for y = 1, H do
    local dy = y - line_y
    if dy >= -half and dy <= half then
      local av = math.exp(-(dy * dy) / (2 * sigma * sigma))
      local t = {}
      for x = 1, W do
        local a = av * edge[x]
        local h = heat[x]
        local gz = grain(x, y)
        t[x] = string.char(
          q(mixf(br, h[1], a) + gz, x, y), q(mixf(bg, h[2], a) + gz, x, y), q(mixf(bb, h[3], a) + gz, x, y))
      end
      rows[y] = "\0" .. table.concat(t)
    else
      rows[y] = bg_rows[y]
    end
  end
  return table.concat(rows)
end

-- signed distance to a rounded rectangle centred at (cx,cy), half-extents hx,hy
local function rrsdf(px, py, cx, cy, hx, hy, r)
  local qx = math.abs(px - cx) - (hx - r)
  local qy = math.abs(py - cy) - (hy - r)
  local mx = qx > 0 and qx or 0
  local my = qy > 0 and qy or 0
  return math.sqrt(mx * mx + my * my) + math.min(math.max(qx, qy), 0) - r
end

--- Keycaps: one keycap per ramp step, a single centred row on smoke, echoing a
--- line of caps from the Thermal set. Each cap is a sculpted 3D form -- a glossy
--- lit TOP face with a soft specular reflection, and a darker FRONT face below
--- it whose bottom edge catches the light. Nearly black; the hue only emerges
--- from shadow, more of it the hotter the step. Fine grain on every face.
local function motif_cubes(p, bg_rows)
  local br, bg_, bb = hex2rgb(p.bg)
  local whi = { hex2rgb(p.whitehot) }

  -- per-cap tones: caps read almost black, so diffuse spans a DARK slice of the
  -- hue (shadow -> lite); the specular reflection is a lighter, whiter tint.
  local stops = {}
  for _, key in ipairs(palette.ramp) do stops[#stops + 1] = { hex2rgb(p[key]) } end
  local n = #stops
  local shadow, lite, spec = {}, {}, {}
  for i = 1, n do
    local c = stops[i]
    shadow[i] = { c[1] * 0.09, c[2] * 0.09, c[3] * 0.09 }
    lite[i] = { c[1] * 0.34, c[2] * 0.34, c[3] * 0.34 }
    spec[i] = { c[1] + (whi[1] - c[1]) * 0.40, c[2] + (whi[2] - c[2]) * 0.40, c[3] + (whi[3] - c[3]) * 0.40 }
  end

  -- layout: a centred row of n cells with gaps, 9% side margins
  local budget = W - 2 * (W * 0.09)
  local cell = math.floor(budget / (n + 0.4 * (n - 1)))
  local gap = math.floor(0.4 * cell)
  local period = cell + gap
  local start_x = math.floor((W - (n * cell + (n - 1) * gap)) / 2)
  local cy0 = math.floor((H - cell) / 2)

  -- keycap footprint (slightly taller than wide), centred in the cell
  local pad = math.floor(cell * 0.05)
  local fh = cell - 2 * pad
  local fw = math.floor(fh * 0.9)
  local foot_left = math.floor((cell - fw) / 2)
  local rro = fw * 0.16 -- outer corner radius

  -- the top face is inset and shifted up; the strip below it is the front face
  local sx = fw * 0.09         -- side inset of the top face
  local ty = fh * 0.05         -- top inset
  local frh = fh * 0.24        -- front-face height
  local seam = fh - frh        -- boundary between top and front
  local top_cx = fw / 2
  local top_cy = (ty + seam) / 2
  local top_hx = (fw - 2 * sx) / 2
  local top_hy = (seam - ty) / 2
  local rrt = top_hx * 0.28

  -- per-column: which cap (0 = none) and x within the footprint
  local capidx, lpx = {}, {}
  for x = 1, W do
    local xx = (x - 1) - start_x
    capidx[x] = 0
    if xx >= 0 then
      local w = xx % period
      local idx = math.floor(xx / period) + 1
      if idx <= n and w < cell then
        capidx[x] = idx
        lpx[x] = w - foot_left
      end
    end
  end

  local rows = {}
  for y = 1, H do
    local yy = (y - 1) - cy0
    if yy >= pad - 1 and yy <= pad + fh + 1 then
      local py = yy - pad
      local t = {}
      for x = 1, W do
        local gz = grain(x, y)
        local sr, sg, sb = br + gz, bg_ + gz, bb + gz -- noisy smoke
        local c = capidx[x]
        local px = c ~= 0 and lpx[x] or -1
        local cov = c ~= 0 and (0.5 - rrsdf(px, py, fw / 2, fh / 2, fw / 2, fh / 2, rro)) or 0
        if cov <= 0 then
          t[x] = string.char(q(sr, x, y), q(sg, x, y), q(sb, x, y))
        else
          if cov > 1 then cov = 1 end
          local sh, li, g
          sh, li = shadow[c], lite[c]
          local cr, cg, cb
          if rrsdf(px, py, top_cx, top_cy, top_hx, top_hy, rrt) < 0 then
            -- TOP face: lit from above, soft specular reflection
            local u = (px - sx) / (fw - 2 * sx)
            local v = (py - ty) / (seam - ty)
            if v < 0 then v = 0 elseif v > 1 then v = 1 end
            g = 0.28 + 0.44 * (1 - v)
            g = g + 0.10 * math.exp(-(v / 0.05) ^ 2)     -- lit top bevel
            g = g * (1 - 0.26 * (2 * u - 1) ^ 2)          -- side falloff
            if g < 0 then g = 0 elseif g > 1 then g = 1 end
            cr = sh[1] + (li[1] - sh[1]) * g
            cg = sh[2] + (li[2] - sh[2]) * g
            cb = sh[3] + (li[3] - sh[3]) * g
            local du, dv = (u - 0.5) / 0.36, (v - 0.30) / 0.18
            local s = 0.40 * math.exp(-(du * du + dv * dv) / 2)
            local sp = spec[c]
            cr = cr + (sp[1] - cr) * s
            cg = cg + (sp[2] - cg) * s
            cb = cb + (sp[3] - cb) * s
          elseif py >= seam then
            -- FRONT face: in shadow, but the bottom edge catches the light
            local u = px / fw
            local vf = (py - seam) / frh
            g = 0.12 + 0.05 * (1 - vf)
            g = g + 0.34 * math.exp(-((vf - 0.85) ^ 2) / (2 * 0.06 * 0.06)) -- front lip
            g = g * (1 - 0.22 * (2 * u - 1) ^ 2)
            if vf < 0.05 then g = g * 0.4 end             -- dark seam under the top
            if g < 0 then g = 0 elseif g > 1 then g = 1 end
            cr = sh[1] + (li[1] - sh[1]) * g
            cg = sh[2] + (li[2] - sh[2]) * g
            cb = sh[3] + (li[3] - sh[3]) * g
          else
            -- top/side bevel: a dark rim that frames the top face
            g = 0.10
            cr = sh[1] + (li[1] - sh[1]) * g
            cg = sh[2] + (li[2] - sh[2]) * g
            cb = sh[3] + (li[3] - sh[3]) * g
          end
          cr = cr + gz; cg = cg + gz; cb = cb + gz         -- grain on the face
          cr = sr + (cr - sr) * cov                        -- AA over noisy smoke
          cg = sg + (cg - sg) * cov
          cb = sb + (cb - sb) * cov
          t[x] = string.char(q(cr, x, y), q(cg, x, y), q(cb, x, y))
        end
      end
      rows[y] = "\0" .. table.concat(t)
    else
      rows[y] = bg_rows[y]
    end
  end
  return table.concat(rows)
end

--- Horizon glow: the heat ramp as a broad, soft band low on the screen, like a
--- thermal horizon rising into smoke. Same per-column heat as the line, but a
--- wide vertical falloff and no hard core.
local function motif_glow(p, bg_rows)
  local br, bg_, bb = hex2rgb(p.bg)

  local stops = {}
  for _, key in ipairs(palette.ramp) do stops[#stops + 1] = { hex2rgb(p[key]) } end
  local m = #stops
  local heat = {}
  for x = 1, W do
    local t = (x - 1) / (W - 1) * (m - 1) + 1
    local i = math.floor(t)
    local f = t - i
    local a, b = stops[i], stops[math.min(i + 1, m)]
    heat[x] = { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f }
  end

  local fade = W * 0.08
  local edge = {}
  for x = 1, W do edge[x] = smooth(math.min((x - 1) / fade, (W - x) / fade, 1)) end

  local horizon = math.floor(H * 0.75 + 0.5)
  local sigma = math.max(10, math.floor(H * 0.11 + 0.5))
  local half = 3 * sigma
  local peak = 0.92

  local rows = {}
  for y = 1, H do
    local dy = y - horizon
    if dy >= -half and dy <= half then
      local av = peak * math.exp(-(dy * dy) / (2 * sigma * sigma))
      local t = {}
      for x = 1, W do
        local a = av * edge[x]
        local h = heat[x]
        local gz = grain(x, y)
        t[x] = string.char(q(mixf(br, h[1], a) + gz, x, y), q(mixf(bg_, h[2], a) + gz, x, y), q(mixf(bb, h[3], a) + gz, x, y))
      end
      rows[y] = "\0" .. table.concat(t)
    else
      rows[y] = bg_rows[y]
    end
  end
  return table.concat(rows)
end

--- Flat smoke + vignette: near-solid flavour bg, darkening gently toward the
--- corners. The quietest motif -- pure colour pairing, no heat.
local function motif_vignette(p, _)
  local br, bg_, bb = hex2rgb(p.bg)
  local dk = { br * 0.42, bg_ * 0.42, bb * 0.42 } -- corner target: ~60% to black
  local inner = 0.30 -- inner radius fraction that stays pure bg

  local cx, cy = (W - 1) / 2, (H - 1) / 2
  local norm = math.sqrt(cx * cx + cy * cy)
  local nx2 = {}
  for x = 1, W do local dx = (x - 1) - cx; nx2[x] = dx * dx end

  local rows = {}
  for y = 1, H do
    local dy = (y - 1) - cy
    local dy2 = dy * dy
    local t = {}
    for x = 1, W do
      local r = math.sqrt(nx2[x] + dy2) / norm
      local v = smooth((r - inner) / (1 - inner))
      local gz = grain(x, y)
      t[x] = string.char(q(mixf(br, dk[1], v) + gz, x, y), q(mixf(bg_, dk[2], v) + gz, x, y), q(mixf(bb, dk[3], v) + gz, x, y))
    end
    rows[y] = "\0" .. table.concat(t)
  end
  return table.concat(rows)
end

--- Flow: a grainy mesh gradient. Random colour anchors are scattered over the
--- frame and blended smoothly (inverse-distance weighting), full-bleed, with
--- heavy grain -- soft heat blobs bleeding into one another. The layout is
--- RANDOM each run; set THERMAL_WP_SEED to reproduce one. The heat ramp maps
--- straight onto the blue -> purple -> magenta -> ember -> amber -> white flow;
--- a few smoke anchors give the darker pools their depth.
local function motif_flow(p, _)
  flow_calls = flow_calls + 1
  math.randomseed(base_seed * 8 + flow_calls)

  -- colour pool: the saturated ramp only (smoke would only mud the blend); a
  -- dark, IN-HUE version of an anchor gives depth without turning grey.
  local ramp = {}
  for _, k in ipairs(palette.ramp) do ramp[#ramp + 1] = { hex2rgb(p[k]) } end
  local nr = #ramp

  -- anchors on a jittered grid so the frame stays evenly covered
  local cols, rowsN = 4, 3
  local ax, ay, ac, ainv = {}, {}, {}, {}
  local k = 0
  for gy = 0, rowsN - 1 do
    for gx = 0, cols - 1 do
      k = k + 1
      ax[k] = (gx + 0.12 + 0.76 * math.random()) / cols * W
      ay[k] = (gy + 0.12 + 0.76 * math.random()) / rowsN * H
      local s = (0.18 + 0.16 * math.random()) * math.min(W, H)
      ainv[k] = 1 / (s * s)
    end
  end
  local K = k

  -- Colour the anchors in RAMP ORDER along a random axis, so neighbouring pools
  -- are always ramp-adjacent hues. That is what keeps the blend saturated:
  -- blue -> purple -> magenta stays clean, where blue + amber would mud to grey.
  -- The axis, jitter and direction are random, so the flow still differs each run.
  local ang = math.random() * 2 * math.pi
  local dx, dy = math.cos(ang), math.sin(ang)
  local order = {}
  for i = 1, K do order[i] = i end
  table.sort(order, function(a, b)
    return ax[a] * dx + ay[a] * dy < ax[b] * dx + ay[b] * dy
  end)
  local rev = math.random() < 0.5
  for rank = 1, K do
    local i = order[rank]
    local tt = (rank - 1) / (K - 1)
    if rev then tt = 1 - tt end
    local pos = 1 + tt * (nr - 1)
    local i0 = math.floor(pos)
    local f = pos - i0
    local a, b = ramp[i0], ramp[math.min(i0 + 1, nr)]
    local c = { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f }
    if math.random() < 0.30 then -- some pools sink into shadow, darkened in-hue
      local d = 0.40 + 0.35 * math.random() -- multiplicative: keeps the hue, no grey
      c = { c[1] * d, c[2] * d, c[3] * d }
    end
    ac[i] = c
  end

  local rows = {}
  for y = 1, H do
    local t = {}
    for x = 1, W do
      local sw, cr, cg, cb = 0, 0, 0, 0
      for i = 1, K do
        local dx = x - ax[i]
        local dy = y - ay[i]
        local w = 1 / (1 + (dx * dx + dy * dy) * ainv[i])
        w = w * w -- sharpen: local anchors dominate, colours stay saturated
        local c = ac[i]
        sw = sw + w
        cr = cr + w * c[1]; cg = cg + w * c[2]; cb = cb + w * c[3]
      end
      local gz = grain(x, y) * 3 -- heavier grain than the smoke field
      t[x] = string.char(q(cr / sw + gz, x, y), q(cg / sw + gz, x, y), q(cb / sw + gz, x, y))
    end
    rows[y] = "\0" .. table.concat(t)
  end
  return table.concat(rows)
end

local motifs = {
  line = motif_line,
  cubes = motif_cubes,
  glow = motif_glow,
  vignette = motif_vignette,
  flow = motif_flow,
}
-- Order also decides which motifs `make wallpaper` emits. Add names here.
local motif_order = { "line", "cubes", "glow", "vignette", "flow" }

-- flow carries its seed in the filename so a run you like is reproducible.
local function rel_name(flavour, motif)
  if motif == "flow" then
    return ("wallpaper/thermal-%s-flow-%d.png"):format(flavour, base_seed)
  end
  return ("wallpaper/thermal-%s-%s.png"):format(flavour, motif)
end

-------------------------------------------------------------------- write ----
vim.fn.mkdir(root .. "/wallpaper", "p")
local written = {}
for _, flavour in ipairs(palette.order) do
  local p = palette.flavours[flavour]

  -- the smoke field with grain, built once per flavour and shared by the motifs
  -- that sit on it (line, glow, cubes) for their untouched rows
  local br, bg_, bb = hex2rgb(p.bg)
  local bg_rows = {}
  for y = 1, H do
    local tt = {}
    for x = 1, W do
      local gz = grain(x, y)
      tt[x] = string.char(q(br + gz, x, y), q(bg_ + gz, x, y), q(bb + gz, x, y))
    end
    bg_rows[y] = "\0" .. table.concat(tt)
  end

  for _, motif in ipairs(motif_order) do
    local png = encode_png(motifs[motif](p, bg_rows))
    local rel = rel_name(flavour, motif)
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
    local nm = motif == "flow"
      and ("wallpaper/thermal-%s-flow-<seed>.png"):format(flavour)
      or ("wallpaper/thermal-%s-%s.png"):format(flavour, motif)
    list[#list + 1] = ("- `%s`"):format(nm)
  end
end
local readme = table.concat({
  "# thermal — wallpaper",
  "",
  "<!-- GENERATED by scripts/wallpaper.lua -- do not edit -->",
  "",
  "One set per flavour, generated from `lua/thermal/palette.lua`, so the desktop",
  "pairs exactly with the terminal and editor. All sit on the flavour's own",
  "smoke (grained), and carry the heat where it means something. Motifs:",
  "",
  "- `line` — a single heat line, the Thermal Accent Row",
  "- `cubes` — a row of sculpted 3D keycaps, one per ramp step",
  "- `glow` — a broad horizon glow low on the screen",
  "- `vignette` — near-solid smoke, darkening to the corners",
  "- `flow` — a grainy mesh gradient of heat colours (**randomised each run**)",
  "",
  "The PNGs are large (4K, uncompressed) and **not committed**. Generate them:",
  "",
  "```",
  "make wallpaper",
  "```",
  "",
  "Different resolution, or a reproducible `flow`:",
  "",
  "```",
  "THERMAL_WP_WIDTH=5120 THERMAL_WP_HEIGHT=2880 make wallpaper",
  "THERMAL_WP_SEED=42 make wallpaper   # same flow every time",
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
print(("thermal: flow seed = %d  (THERMAL_WP_SEED=%d to reproduce)"):format(base_seed, base_seed))
