-- thermal :: install
--
--   nvim -l scripts/install.lua           symlink every target into place
--   nvim -l scripts/install.lua --copy    copy instead of symlink
--
-- Installs the three targets that live in a fixed directory: Ghostty themes,
-- Claude Code themes, and the VS Code extension. Slack, tmux and Chrome are
-- paste/load-unpacked/tpm and have nothing to symlink.
--
-- Symlinks by default so that editing the palette and re-running
-- `nvim -l scripts/build.lua` updates everything with no second step. Use
-- --copy if you'd rather the installed themes not track the repo (or if one of
-- these config directories lives on a filesystem that doesn't do symlinks).
--
-- Idempotent: re-running replaces links it owns and leaves anything else alone.

-- Absolutise first (source may be relative when invoked as `nvim -l scripts/...`),
-- then strip the script suffix to get the repo root.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")
  :gsub("/scripts/install%.lua$", "")
local palette = dofile(root .. "/lua/thermal/palette.lua")

local copy = vim.tbl_contains(vim.v.argv, "--copy")

local config_home = vim.env.XDG_CONFIG_HOME
  or (assert(vim.env.HOME, "no $HOME") .. "/.config")
local home = assert(vim.env.HOME, "no $HOME")

local skipped = {}

--- Link (or copy) one path into place, refusing to destroy anything we did not
--- put there ourselves. Returns true if it landed.
--- @param src string absolute path inside the repo
--- @param dst string absolute path in the config directory
--- @param label string what to call it in the report
--- @param dir boolean true when src is a directory (the VS Code extension)
local function place(src, dst, label, dir)
  local readable = (dir and vim.fn.isdirectory(src) or vim.fn.filereadable(src)) == 1
  if not readable then
    error("missing " .. src .. " -- run `nvim -l scripts/build.lua` first")
  end

  -- Only clobber a symlink we own, or -- with --copy -- a plain file.
  local existing_link = vim.uv.fs_readlink(dst)
  local exists = existing_link ~= nil
    or vim.fn.filereadable(dst) == 1
    or vim.fn.isdirectory(dst) == 1
  if exists and existing_link == nil and not copy then
    table.insert(skipped, ("%s (something that isn't ours is already there)"):format(label))
    return false
  end

  if exists then vim.fn.delete(dst, dir and "rf" or "") end

  if copy then
    if dir then
      -- No recursive copy in vim.uv; the extension is small and cp is everywhere.
      assert(vim.fn.system({ "cp", "-R", src, dst }) ~= nil)
      if vim.v.shell_error ~= 0 then error("cp -R failed for " .. src) end
    else
      assert(vim.uv.fs_copyfile(src, dst))
    end
  else
    assert(vim.uv.fs_symlink(src, dst, dir and { dir = true } or nil))
  end
  return true
end

local report = {}

--------------------------------------------------------------- ghostty ------
-- Ghostty reads XDG on Linux and macOS alike.
local ghostty = config_home .. "/ghostty/themes"
vim.fn.mkdir(ghostty, "p")

local ghostty_n = 0
for _, name in ipairs(palette.order) do
  if place(("%s/ghostty/thermal-%s"):format(root, name),
           ("%s/thermal-%s"):format(ghostty, name),
           ("ghostty/thermal-%s"):format(name), false) then
    ghostty_n = ghostty_n + 1
  end
end
table.insert(report, ("%d ghostty theme(s) -> %s"):format(ghostty_n, ghostty))

----------------------------------------------------------- claude code ------
-- Claude Code watches this directory, so a relink lands in a running session.
local claude = home .. "/.claude/themes"
vim.fn.mkdir(claude, "p")

local claude_n = 0
for _, name in ipairs(palette.order) do
  if place(("%s/claude-code/thermal-%s.json"):format(root, name),
           ("%s/thermal-%s.json"):format(claude, name),
           ("claude-code/thermal-%s"):format(name), false) then
    claude_n = claude_n + 1
  end
end
table.insert(report, ("%d claude code theme(s) -> %s"):format(claude_n, claude))

---------------------------------------------------------------- vscode ------
-- One extension carrying all flavours, so one link per editor. Every VS Code
-- fork that is present gets it; absent ones are simply not ours to create.
local editors = {
  { "VS Code", home .. "/.vscode/extensions" },
  { "VS Code Insiders", home .. "/.vscode-insiders/extensions" },
  { "VSCodium", home .. "/.vscode-oss/extensions" },
  { "Cursor", home .. "/.cursor/extensions" },
}

local vscode_n = 0
for _, ed in ipairs(editors) do
  if vim.fn.isdirectory(ed[2]) == 1 then
    if place(root .. "/vscode", ed[2] .. "/thermal", ("vscode (%s)"):format(ed[1]), true) then
      vscode_n = vscode_n + 1
      table.insert(report, ("vscode extension -> %s/thermal (%s)"):format(ed[2], ed[1]))
    end
  end
end
if vscode_n == 0 then
  table.insert(report, "vscode extension -> nowhere (no editor extensions dir found)")
end

------------------------------------------------------------------ done ------
print(("thermal: %s"):format(copy and "copied" or "linked"))
for _, line in ipairs(report) do print("  " .. line) end

if #skipped > 0 then
  print("\nskipped (remove them yourself if you want these replaced):")
  for _, n in ipairs(skipped) do print("  " .. n) end
end

print(("\nGhostty     %s/ghostty/config:  theme = thermal-%s"):format(config_home, palette.default))
print(         "Claude Code /theme, then pick Thermal")
if vscode_n > 0 then
  print(("VS Code     reload the window, then Cmd+K Cmd+T -> Thermal (%s)"):format(palette.default))
end
print("Slack       slack/thermal-<flavour>.txt, or :ThermalCopy slack <flavour>")
