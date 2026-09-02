-- thermal :: install
--
--   nvim -l scripts/install.lua           symlink ghostty themes into place
--   nvim -l scripts/install.lua --copy    copy instead of symlink
--
-- Symlinks by default so that editing the palette and re-running
-- `nvim -l scripts/build.lua` updates your terminal with no second step.
-- Use --copy if you'd rather the installed themes not track the repo (or if
-- your Ghostty config lives on a filesystem that doesn't do symlinks).
--
-- Idempotent: re-running replaces links it owns and leaves anything else alone.

-- Absolutise first (source may be relative when invoked as `nvim -l scripts/...`),
-- then strip the script suffix to get the repo root.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
  :gsub("/scripts/install%.lua$", "")
local palette = dofile(root .. "/lua/thermal/palette.lua")

local copy = vim.tbl_contains(vim.v.argv, "--copy")

-- Ghostty reads XDG on Linux and macOS alike.
local config_home = vim.env.XDG_CONFIG_HOME
  or (assert(vim.env.HOME, "no $HOME") .. "/.config")
local themes = config_home .. "/ghostty/themes"

vim.fn.mkdir(themes, "p")

local installed, skipped = {}, {}

for _, name in ipairs(palette.order) do
  local src = ("%s/ghostty/thermal-%s"):format(root, name)
  local dst = ("%s/thermal-%s"):format(themes, name)

  if vim.fn.filereadable(src) == 0 then
    error("missing " .. src .. " -- run `nvim -l scripts/build.lua` first")
  end

  -- Only clobber a plain file we'd have written, or a symlink we own.
  local existing_link = vim.uv.fs_readlink(dst)
  local exists = vim.fn.filereadable(dst) == 1 or existing_link ~= nil
  if exists and existing_link == nil and not copy then
    -- a real file that isn't ours; don't silently destroy it
    table.insert(skipped, ("thermal-%s (a real file is already there)"):format(name))
    goto continue
  end

  if exists then vim.fn.delete(dst) end

  if copy then
    assert(vim.uv.fs_copyfile(src, dst))
  else
    assert(vim.uv.fs_symlink(src, dst))
  end
  table.insert(installed, ("thermal-%s"):format(name))

  ::continue::
end

print(("thermal: %s %d ghostty theme(s) into %s"):format(
  copy and "copied" or "linked", #installed, themes))
for _, n in ipairs(installed) do print("  " .. n) end

if #skipped > 0 then
  print("\nskipped (remove them yourself if you want these replaced):")
  for _, n in ipairs(skipped) do print("  " .. n) end
end

print(("\nAdd to %s/ghostty/config:\n  theme = thermal-%s"):format(config_home, palette.default))
print("\nSlack strings: slack/thermal-<flavour>.txt, or :ThermalCopy slack <flavour>")
