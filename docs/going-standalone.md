# Going standalone

Notes on removing the catppuccin engine and owning the highlights directly.
Written down so the decision can be made deliberately later rather than
re-derived. Nothing here is urgent; the current setup works.

## Where things stand

`lua/thermal/palette.lua` holds the colours under our own names. Only one file
knows catppuccin exists:

```
palette.lua      colours, semantic names        ← never changes
catppuccin.lua   slot translation + patches     ← the throwaway
init.lua         public API                     ← one line points at the engine
```

Ghostty, Slack and the previews all read `palette.lua` (plus `engine.ansi()`),
so **none of them are affected by this migration at all.** This is a Neovim-only
question.

## Why we'd bother

Catppuccin binds roles to palette slots rather than the reverse. `yellow` is
types *and* warnings. `blue` is functions *and* info *and* directories. Colour a
slot for its syntax role and the UI roles follow it, which is why
`catppuccin.patches()` exists — it puts back twelve groups that the recolouring
broke.

That patch list is the visible symptom. The structural version: we don't get to
say "types are steel and warnings are amber," only "whatever slot currently
means types shall be steel, and then repair the collateral." Every future
palette change risks a new collision, and the only way to find one is to notice
it on screen.

Owning the highlights means assigning roles directly and deleting the whole
category of problem.

## Why we haven't

Roughly 69 plugin integrations. That is the entire value of the adapter, and
it's not a small number to reproduce.

Worth being precise about the real cost, though: most of those 69 are plugins
we don't use. The number that matters is *our* plugin list, which is more like
ten to fifteen. Auditing that is the first task of this migration, not an
afterthought — see below.

## Head start

The standalone version substantially exists already. Earlier in this project a
complete from-scratch theme was built: 424 highlight groups covering core
editor, syntax, Treesitter, LSP, semantic tokens, diagnostics, terminal, and
about twenty plugin integrations, with a headless test asserting every group
resolves and every colour parses.

It was deliberately written against the same colour vocabulary this repo now
uses — `bg`, `bg_alt`, `bg_hl`, `bg_sel`, `border`, `gutter`, `dim`, `muted`,
`fg`, `fg_hi`, `cold`, `frost`, `violet`, `purple`, `magenta`, `ember`, `flare`,
`amber`, `glow`, `whitehot`, `sage`. So porting it is mostly mechanical: point
it at `palette.lua` and drop it in as `lua/thermal/highlights.lua`.

That converts this from "write a colourscheme" to "adapt one that exists and
extend its plugin coverage," which is a materially smaller job.

## Steps

1. **Audit plugin coverage.** List the plugins actually installed. For each,
   check whether it needs explicit groups or inherits from core ones (many link
   to `Normal`, `FloatBorder`, `Pmenu` and need nothing). This produces the real
   scope. Do this before anything else — it may show the job is a day, or it may
   show it's a fortnight.
2. **Port the highlights module.** Add `lua/thermal/highlights.lua` returning a
   group table built from a flavour. Keep `engine.ansi()` as-is; it already
   lives at the right layer.
3. **Run both side by side.** Wire it behind an option — `engine = "native"` vs
   `"catppuccin"` — and switch between them on real files in real languages.
   This is the only way to find gaps, and it costs almost nothing to keep both
   during the transition.
4. **Close the gaps** the audit and side-by-side surface.
5. **Delete** `catppuccin.lua`, the generated stubs, the stub generation in
   `build.lua`, and the dependency from the install snippet.

## What has to be reimplemented

Things catppuccin currently provides that would become ours:

- **Option surface.** `styles` (per-category italics/bold), `transparent_background`,
  `dim_inactive`, `term_colors`, `integrations`. Decide which of these we
  actually want rather than cloning the API — the earlier standalone build had
  `transparent`, `italic_comments`, `bold_keywords`, `dim_inactive`,
  `on_highlights`, and that was enough.
- **A `custom_highlights`/`on_highlights` escape hatch.** Users (us) need a way
  to override a group without editing the theme.
- **The lualine theme.** `lua/lualine/themes/thermal.lua` currently delegates to
  catppuccin's integration. It would need writing — the earlier build had one
  putting each mode at a different point on the heat ramp.
- **Compile caching, or a decision not to.** Catppuccin compiles to a cached Lua
  file. The earlier standalone build applied all 424 groups via `nvim_set_hl`
  with no caching and was not perceptibly slow. Start without a cache; add one
  only if measurement says to. Dropping it also removes the stale-cache trap
  documented in the README, which is a real simplification.

## Things that will bite

- **Group name churn.** Treesitter's `@` groups and the `@lsp.*` semantic token
  groups have been renamed across Neovim versions. Catppuccin tracks that for
  us. Owning it means pinning a minimum Neovim version and keeping up.
- **Ordering.** If a hybrid phase is used, whichever engine runs last wins. Our
  groups must be applied *after* catppuccin's, and `hi clear` must not run in
  between.
- **A light flavour.** Nothing here is light yet. If one is ever added,
  `background=light` handling, and the eleven places catppuccin special-cases
  `latte` via `vary_color`, become our problem. Worth deciding now whether a
  light flavour is ever wanted, because it affects how the highlights module is
  structured.
- **Testing has to come along.** The earlier build's headless test — assert
  every group resolves, every colour is a valid hex, every link points at
  something non-empty, across all option permutations — is what made that theme
  trustworthy. Port it alongside the highlights, not after. `scripts/contrast.lua`
  already covers the palette half of this.

## A middle path

Own the core and Treesitter groups; keep the adapter only for plugin
integrations. That kills the role-versus-slot problem where it actually hurts
(syntax and diagnostics) while keeping the 69 integrations for free.

The cost is a permanent dependency and two layers to reason about instead of
one. It's a reasonable place to stop, and it's reachable by doing steps 1–3 and
simply not doing step 5.

## The actual decision

The trigger isn't "the adapter is inelegant." It's one of:

- a palette change causes a collision that `patches()` can't cleanly fix
- we want a role assignment catppuccin's slot structure can't express
- we want to publish this, at which point owning the theme matters more
- the dependency itself becomes a problem (breaking change upstream, or
  catppuccin stops being maintained)

Absent one of those, the adapter is doing its job and the correct move is to
leave it alone.
