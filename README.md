# thermal

A dark, low-contrast theme for Neovim, VS Code, Claude Code, Ghostty, tmux, Slack
and Chrome, based on the PBTfans **Thermal** keycap set designed by Matthew
Encina of
[Mod Musings](https://www.modmusings.com/thermal-keycaps).

The set is smoky black bases with dark gray translucent tops and gray legends —
nearly monochrome until directional light pulls the legends out of shadow. Its
one flash of colour is the Thermal Accent Row: a heat-signature gradient across
R3, sitting as a single heat line across the board.

The theme works the same way. Most of the screen is smoke; heat is spent only
where it carries meaning — keywords, literals, function names, the line you're
on, search hits.

Flavours: `smoky` (the set as photographed), `void` (darker), `ash` (lighter).

![thermal-smoky](preview/thermal-smoky.svg)

`void` and `ash` in [preview/](preview/README.md). Previews are generated from
the palette by `make preview`, so they can't drift from the theme.

## One palette, every target

`lua/thermal/palette.lua` is the only file you edit by hand. Everything else is
generated:

```
make build      # regenerate all derived files      (nvim -l scripts/build.lua)
make preview    # regenerate preview/*.svg          (nvim -l scripts/preview.lua)
make wallpaper  # generate wallpaper/*.png (4K)      (nvim -l scripts/wallpaper.lua)
make check      # assert readability, non-zero exit (nvim -l scripts/contrast.lua)
make install    # symlink every installable target  (nvim -l scripts/install.lua)
make all        # check, build, preview
```

There is no toolchain beyond Neovim, which you already have wherever you want
this theme.

```
lua/thermal/palette.lua          SOURCE OF TRUTH
lua/thermal/init.lua             public API
lua/thermal/catppuccin.lua       engine adapter (see "Dropping catppuccin")
lua/lualine/themes/thermal.lua

colors/thermal*.lua              (generated)
lua/catppuccin/palettes/*.lua    (generated stubs)
scripts/build.lua                regenerate everything below
scripts/preview.lua              regenerate the SVG previews
scripts/wallpaper.lua            regenerate the PNG wallpapers
scripts/install.lua              symlink ghostty/vscode/claude themes into place
scripts/contrast.lua             readability gate

docs/going-standalone.md         the plan for dropping catppuccin

ghostty/thermal-*                (generated) complete theme files
ghostty/README.md                (generated)
slack/thermal-*.txt              (generated) one string per file
slack/README.md                  (generated) copy-from-GitHub table
thermal.tmux                     (generated) self-contained tmux plugin
tmux/README.md                   (generated) tpm install instructions
chrome/thermal-*/manifest.json   (generated) unpacked browser themes
chrome/README.md                 (generated) load-unpacked instructions
vscode/package.json              (generated) one extension, all flavours
vscode/themes/*.json             (generated) colour themes
vscode/README.md                 (generated) symlink install
claude-code/thermal-*.json       (generated) CLI themes
claude-code/README.md            (generated) why the base is dark-ansi
preview/thermal-*.svg            (generated) renders on GitHub
preview/README.md                (generated)
wallpaper/thermal-*.png          (generated, gitignored) 4K wallpapers
wallpaper/README.md              (generated) how to set them
```

## Neovim

```lua
{
  "vojoup/thermal",
  dependencies = { "catppuccin/nvim" },
  lazy = false,
  priority = 1000,
  config = function()
    require("thermal").setup({})
    vim.cmd.colorscheme("thermal")
  end,
}
```

`:colorscheme thermal` uses the default flavour; `thermal-void` and
`thermal-ash` are also colorschemes. `:Thermal <flavour>` switches with
tab-completion.

Options go straight through to the engine, so anything catppuccin accepts works:

```lua
require("thermal").setup({
  transparent_background = true,
  integrations = { telescope = true, gitsigns = true },
  styles = { comments = { "italic" }, keywords = { "bold" } },
})
```

Useful API:

```lua
require("thermal").palette("void").amber   --> "#F6A83F"
require("thermal").ramp()                  --> 10 hexes, coldest to hottest
require("thermal").flavours                --> { "smoky", "void", "ash" }
```

Statusline: `require("lualine").setup({ options = { theme = "thermal" } })`.

## Grabbing a flavour

Four ways, depending on where you are.

**From Neovim, anywhere:**

```
:ThermalCopy slack void        theme string on the clipboard
:ThermalCopy ghostty ash       whole ghostty theme on the clipboard
:ThermalCopy slack             default flavour
```

Both arguments tab-complete.

**From the shell, in the repo:**

```
make install                   symlink every installable target into place
make slack FLAVOUR=void | pbcopy
make ghostty FLAVOUR=ash
make vscode FLAVOUR=void
make claude FLAVOUR=ash
cat slack/thermal-void.txt     the files hold only the string, nothing else
```

**From GitHub, on a machine that has never cloned this:** open
[`slack/README.md`](slack/README.md) for a table of theme strings, or
[`ghostty/README.md`](ghostty/README.md). Both are generated, so they can't drift
from the palette.

**By hand:** `ghostty/thermal-*` are complete theme files; `slack/thermal-*.txt`
are single lines.

## Ghostty

```
nvim -l scripts/install.lua          # or: make install
```

Symlinks every flavour into `$XDG_CONFIG_HOME/ghostty/themes` (falling back to
`~/.config`) — along with the Claude Code themes and the VS Code extension — so a
palette edit plus `make build` updates all three with no second step. Pass
`--copy` for real files instead of links. It's idempotent, and it refuses to
overwrite anything at one of those paths that it didn't create.

Then in `~/.config/ghostty/config`:

```
theme = thermal-smoky
```

Ghostty also accepts a pair: `theme = light:thermal-ash,dark:thermal-void`.

Neovim's `:terminal` colours and these theme files are both generated from
`engine.ansi()`, so all 16 ANSI slots match by construction — verified by test,
not by eye.

## Slack

`:ThermalCopy slack <flavour>`, then Preferences → Appearance → Custom theme,
paste, save. Or copy the line from [`slack/README.md`](slack/README.md).

Slack's custom theme only styles the **sidebar**. There is no way to reach the
message pane, so turn on Appearance → Dark as well or the two won't match. The
active channel gets a smoky selection background with amber text rather than an
amber fill, so the heat still marks where you are without shouting.

## VS Code

One extension carries all three flavours. `make install` symlinks `vscode/` into
every editor it finds — VS Code, Insiders, VSCodium, Cursor — then reload the
window and `Cmd+K Cmd+T` → **Thermal (smoky)**. Details in
[`vscode/README.md`](vscode/README.md).

Semantic highlighting is on, so a running language server's classifications win
and the TextMate scopes are the fallback. Both lists make the same assignments
the Neovim theme does, and the integrated terminal gets all sixteen ANSI slots
from the same `engine.ansi()` the Ghostty theme is built from — a shell inside
the editor matches a shell outside it.

## Claude Code

```
make install
```

then `/theme` and pick **Thermal**. Details in
[`claude-code/README.md`](claude-code/README.md).

Each flavour is a `~/.claude/themes/*.json` of `{ name, base, overrides }`, and
the base is **`dark-ansi`** — which is the whole trick. Claude Code doesn't read
a theme's overrides when it highlights code: on a `dark` base the syntax colours
in code blocks and diffs are hardcoded Monokai, on `light` hardcoded GitHub. Only
on an `*-ansi` base does every syntax scope resolve through the *terminal's* ANSI
slots — where thermal already lives. So paired with the Ghostty theme, the
snippets Claude prints and the diffs it shows are painted from this same palette
rather than sitting in the terminal as a foreign block of Monokai.

The cost is that those scopes are pinned to ANSI slots rather than to thermal's
own role assignments, so two land one seat over from the editor: strings take
slot 10's sage instead of frost, types take slot 14's teal instead of cold.

Diff *backgrounds* are override-driven and survive the ansi base, so they're set
explicitly — teal in, ember out, each washed over its own flavour's smoke.

## Chrome

Each flavour is an unpacked extension theme under `chrome/thermal-*`. Open
`chrome://extensions`, turn on Developer mode, hit **Load unpacked**, and point
it at one flavour's directory (e.g. `chrome/thermal-smoky`). Details and how to
pack a `.crx` are in [`chrome/README.md`](chrome/README.md).

The frame behind the tabs is the darkest smoke and the toolbar is a raised smoke
surface a step lighter — Chrome paints multi-selected tabs with the toolbar
colour and unselected tabs with the frame colour, so that gap is what makes a
multi-tab selection visible. Amber lands only on new-tab links. Chrome allows one
theme at a time; loading a
flavour replaces the last, and unpacked themes don't auto-update — after a
palette edit and `make build`, hit the reload arrow on the theme's card.

## Adding a flavour

Add a block to `M.flavours` in `lua/thermal/palette.lua`, add its name to
`M.order`, then:

```
make all
```

That emits the colorscheme entry point, the catppuccin stub, the Ghostty theme,
the Slack string, both copy-from-GitHub tables, the tmux flavour arm, the Chrome
theme, the VS Code theme and its `package.json` contribution, the Claude Code
theme and the SVG preview together. `make install` picks up the new flavour
everywhere it installs, and `:ThermalCopy` and `:Thermal` complete on it. Nothing
else to touch.

## Design notes

**Heat means importance.** Body text and variables stay gray, the way most
legends on the set stay gray. Colour marks what you scan for. If everything
glows, nothing does.

**No green, with one exception.** The set has none, so diffs run on the cold half
of the ramp: teal for additions, ember for deletions, amber for changes. Git
never competes with syntax colour. The single green — a heavily desaturated sage
— exists only for terminal ANSI slot 2, because `ls` and `git diff` are unusable
without one.

**Contrast is measured, not eyeballed.** "Low contrast" describes the keycaps'
legends, not what you should read for eight hours. Every heat colour clears WCAG
AA (4.5:1) against its own flavour's background; comments sit near 3.3:1,
recessed but above the 3:1 floor rather than the ~2.5:1 you'd get from matching
the real caps literally. `scripts/contrast.lua` enforces this.

## Notes on the catppuccin engine

Three things worth knowing, all found the hard way:

**Palettes must not live in palette files.** catppuccin's `setup()` hashes your
config to decide whether to recompile, and that hash covers `color_overrides`
but not files under `lua/catppuccin/palettes/`. A palette in a file goes stale
silently — you edit a hex, restart, and see the old colour with no error. So the
generated palette modules are empty stubs and the real colours travel through
`color_overrides`.

**The stubs still have to exist.** `get_palette` does
`local _, palette = pcall(require, ...)`, which on failure leaves `palette` as
the error *string*; that reaches `tbl_deep_extend` and crashes the compiler. An
empty module is enough.

**Patches must be per-flavour.** `custom_highlights` is internally assigned to
`highlight_overrides.all`, so a patch list there leaks onto real catppuccin
flavours if you have both installed. `lua/thermal/catppuccin.lua` keys
`highlight_overrides` per flavour instead.

## Dropping catppuccin

The layering is built for it: `palette.lua` holds colours under our own names and
`lua/thermal/catppuccin.lua` is the only file that knows what a `mauve` is.
Ghostty, Slack, VS Code, Claude Code and the previews are unaffected either way.

The full plan — why we'd bother, what has to be reimplemented, what will bite,
and what should actually trigger the decision — is in
[docs/going-standalone.md](docs/going-standalone.md).

## Credit

Keycap set design © Matthew Encina / Mod Musings, Inc. This is an unofficial
tribute, not affiliated with Mod Musings, PBTfans or KBDfans. No official hex
values are published for the set; the palette is matched to the documented
colorway and the thermal-imaging ramp it is named for.

Plugin integrations come from [catppuccin/nvim](https://github.com/catppuccin/nvim) (MIT).
