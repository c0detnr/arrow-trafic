# Arrow Traffic UI redesign

Kind: gaming; existing native Godot 4.7 UI.
Deal: soot-pale-lime (#0f0f0f / #1a1a1a / #ffffff / #dafa9c), Sora + Figtree. The neutral ground separates the game's six arrow colours; lime identifies the next queue item and actions. Fonts are bundled locally with OFL licences.

Based on the installed design-taste-frontend 2.5.1 and https://www.tasteskill.dev/docs#redesign. Applied the existing-stack, inventory, typography, palette, frame, state and before/after steps. Landing-page heroes, scroll moments, photographs, HTML/CSS assets and DOM measurements do not apply to this native game.

## Inventory and scope

Existing facts: Arrow Traffic; Turkish UI; ten prototype levels; 4x5 through 6x8 boards; six colour identities with distinct symbols; ordered colour queue; three or four pocket slots; blocked-move mistake counter; local saved level; win/loss and next/retry actions.

The screen answers which colour should leave next. The first queue item is larger and ringed, followed by five preview items and the remaining count. The board stays central. The temporary pocket has numbered empty slots and an explicit occupancy count. Instructions explain tapping and waiting colours. The result panel dims and blocks the board; the background retry is disabled while it is open.

Voice: short, direct Turkish using the existing game nouns (bölüm, ok, renk sırası, cep). No invented score, timer, ratings, prices or progress system. Existing exit, blocked-move and pocket landing animations retained. Button hover/press colours and keyboard focus ring added.

Changed: main.gd, project.godot, local fonts, UI checks and native screenshot helper. Game rules, level data, generator and save schema are unchanged.

## Verification

- Godot import and parsing passed.
- `tests/test_logic.gd`: passed.
- `tests/test_ui.gd`: passed; all ten levels at four logical viewport sizes; board clearance, modal bounds, win, loss, next, retry and modal background state.
- `python -m unittest discover -s tools -p 'test_*.py'`: 8 tests passed.
- `git diff --check`: passed.
- Native GPU renders at 320x568, 390x844, 720x1280, 768x1024, 1024x768 and 1440x900. Before and after files use level 10 and the same sizes. Read the phone, tablet and desktop renders for clipping, queue overflow and board/pocket separation; also checked the win panel. The native screenshot helper uses a SubViewport so the desktop window manager cannot change the requested capture size.
- Capture and UI test commands require an empty temporary XDG_DATA_HOME; the helper refuses to overwrite an existing save.

Browser gate: not completed. The skill's `gate.mjs main.gd` started its HTML/Chrome checker against GDScript; it was stopped (exit 2) because DOM checks cannot validate this native scene. No web gate pass, layout measurements or performance pass is claimed. No waivers or kit modifications.

No photographs, placeholder art, external runtime fonts or new dependencies. No mobile-device touch/performance test, Android/iOS export or manual keyboard playthrough. Portrait game remains centred in landscape.

## Run

From this worktree: `godot --path .`

UI verification: `XDG_DATA_HOME=$(mktemp -d) godot --headless --path . --script tests/test_ui.gd`

Screenshot: `XDG_DATA_HOME=$(mktemp -d) godot --path . --script tests/capture_ui.gd -- .taste-skill/after/390.png 390 844 9`

Before: `before/<width>.png`. After: `after/<width>.png`, `after/won.png`.
