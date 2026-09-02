# thermal
FLAVOUR ?= smoky

.PHONY: build preview check install install-copy slack ghostty tmux wallpaper all

all: check build preview

build:   ## regenerate every derived file from lua/thermal/palette.lua
	nvim -l scripts/build.lua

preview: ## regenerate preview/*.svg from the palette
	nvim -l scripts/preview.lua

wallpaper: ## generate wallpaper/*.png (4K; not committed) from the palette
	nvim -l scripts/wallpaper.lua

check:   ## assert every flavour still clears WCAG AA
	nvim -l scripts/contrast.lua

install: ## symlink ghostty themes into ~/.config/ghostty/themes
	nvim -l scripts/install.lua

install-copy:
	nvim -l scripts/install.lua --copy

slack:   ## print a slack string:  make slack FLAVOUR=void | pbcopy
	@cat slack/thermal-$(FLAVOUR).txt

ghostty: ## print a ghostty theme: make ghostty FLAVOUR=ash
	@cat ghostty/thermal-$(FLAVOUR)

tmux:    ## print the generated tmux plugin
	@cat thermal.tmux
