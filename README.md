# Phoneshot 📸

**中文**: [README.zh-CN.md](README.zh-CN.md)

Turn crisp region screenshots into convincing "phone photographing a screen" images — an Omarchy plugin.

- `PRINT` keeps the normal Omarchy flow (region select / grim); a toggle decides whether the result gets the phone-photo treatment
- **Off by default** — native screenshots are untouched; the takeover is opt-in and never pollutes default behavior
- Effects (v2, full camera look): rainbow moiré (sensor-sampling model) + LCD subpixel grille + scanlines + chromatic aberration + perspective/handshake + defocus + glare/rolling-shutter band + grain + JPEG recompression
- The moiré is a physical sampling model, not an overlay texture: R|G|B subpixel stripes are drawn on a 2× canvas and point-sampled back down — that's one sensor resample. Stripe pitch drifts along the keystone direction so wide beat bands only appear near a "resonance spot" (localized to one patch, random position per shot, can fall off-frame = almost no moiré). The color comes from whichever subpixel got sampled — bands follow the shooting angle, dark areas show no moiré (hardlight multiplicative modulation), and text picks up demosaic-style color fringing
- Credits: CRT shader community recipes (stefanlegg/crt-fx: scanlines / phosphor / chromatic / bloom / vignette), silentMoire's synthetic moiré idea (offset fine grids + resample)
- Outputs `*-phoneshot.jpg`; the crisp PNG is kept too, and the styled copy goes to the clipboard

## Files

```
bin/omarchy-phoneshot-apply       pure filter: crisp image in -> phoneshot out (ImageMagick)
bin/omarchy-phoneshot-screenshot  PRINT wrapper (passes straight through when toggled off)
bin/omarchy-phoneshot-toggle      on/off switch
bin/omarchy-phoneshot-set         panel backend: writes params + re-renders the preview
~/.config/omarchy/plugins/duro.phoneshot/   shell plugin: bar icon + parameter panel + live preview
~/.config/omarchy/phoneshot-params          param file (KEY=VALUE, shared by panel and PRINT)
install.sh                      installs to ~/.local/bin + writes the Hyprland keybinds
bindings-snippet.lua            keybind snippet (used by install.sh, can be pasted manually)
```

## Panel parameters

| Slider | Range | Default | Notes |
|--------|-------|---------|-------|
| Roll | −5–+5° | 0 | In-plane roll, −=clockwise/+=counter-clockwise, deterministic |
| Side view | −12–+12° | 0 | Keystone perspective shot from one side; +=from the right/−=from the left, near side stretched, far side compressed |
| Defocus | 0–2.0 | 0.8 | Uniform out-of-focus blur; moiré decays as blur grows (physically linked) |
| Motion blur | 0–8px | 0 | Directional ghosting from handshake during the exposure |
| Blur angle | 0–180° | 30 | Direction of the streak, 0=horizontal/90=vertical |

## Cropping after distortion: source pixels only (2026-09-13)

Perspective/rotation used to fill with black and crop back to the original size —
the black wedges at the corners were "content from outside the screen", a dead giveaway.
Now the image is cropped to the **largest inscribed rectangle containing only source
pixels** (closed-form solution, edges pulled in 1px to kill AA dark lines). The output
is slightly smaller than the input and varies with parameters — we'd rather lose
information than fabricate it. Texture layers are generated at the final size, so
their look is unchanged.

## Preview (renders on release, what you see is what you get)

The panel's right column shows a real magick render — same engine, same params as
PRINT. Dragging a slider only records the value; on release `omarchy-phoneshot-set`
writes the params and re-renders `~/.cache/phoneshot/preview.jpg` (~2s, status shows
"Rendering…"). No live tracking while dragging — the render IS final quality.

- Params (`phoneshot-params`) + render (`preview.jpg`) are both persisted: reopen the
  panel and the sliders show last values, the preview shows the last render. On a
  fresh install (neither file exists) it renders once with all-zero geometry.
- New sliders initialize to the mid-preset equivalents (R0/K0/M0, D0.8) so slider
  position always maps 1:1 to the effect; the first MOTION write also persists the
  MOTION_ANGLE default (30) so the engine's random direction can't disagree with
  what the panel shows.
- The panel writes all five keys at once (`set ALL`) — fast multi-slider drags can't
  drop keys (a single pending slot used to lose intermediate values).
- The "Randomize parameters" button rolls all five sliders (side view/defocus/motion
  use a triangular distribution biased small, like a real casual shot), writes via
  the same `set ALL` path, and re-renders once.

## Resolution normalization (2026-09-08)

Slider units are px at a 768px reference width; the engine scales defocus σ /
motion / moiré pitch / grille period / scanline period / chroma by S=W/768.
Previously a 4K render looked almost clean compared to the preview — absolute-px
params were 5× weaker at 3840 wide. Now a 768 preview and a 4K render look the
same (verified side by side). ROTATE (degrees) and KEYSTONE (ratio) are
dimensionless and unaffected.

## Performance (round two, 2026-09-13)

4K fullscreen used to take 60s → round one got ~15s (width capped at 1920, moiré
canvas 960, band at 1/4 canvas, 4 threads) → round two: **~3.8s** for 1080p
(profile: 7.9s composite of which motion-blur alone was 6.9s; moiré drawing 3.0s).
Round-two tricks: motion blur at 50% resolution (σ halved too — blur survives
downsampling, ~5× faster), then blended over the sharp base so weak motion keeps
a crisp primary image plus directional ghosting; all four texture layers and the
distortion chain run in parallel; band+glare merged into a single alpha map
(screen is associative — exactly equivalent); moiré drawn with `+antialias` and a
point upscale at the end; distortion collapsed to one command with no intermediate
PNG. A 768 preview takes ~2s. `PHONESHOT_MAX_WIDTH` (default 1920, 0=unlimited) and
`MAGICK_THREAD_LIMIT` (4) remain overridable.

## Output config (`phoneshot-output`)

Separate from the parameter file. Fields: `clipboard=original|phoneshot|none`
(default phoneshot), `save_original`/`save_phoneshot` (default true),
`output_dir` (empty = native screenshot dir), `level=mild|mid|hard` (default mid,
env var wins), `notify` (default true). Rules: an explicit `copy` forces no disk
write, an explicit `save` forces no clipboard; invalid values fall back to
defaults and get mentioned in the notification; if nobody wants the styled image
(not saved, not copied) the ~seconds of rendering are skipped; the lock only
covers region-select+grim — rendering/clipboard/notification run outside it
(a resident wl-copy inheriting the lock fd used to silently block every later
screenshot, the 2026-09-08 incident). The styled image is always fed to the
clipboard as `image/png`: the shell's clipboard history only watches
`text`+`image/png`, so a jpeg never showed up in history (the clipboard itself
was fine — history just didn't record it, 2026-09-13).

## Development

This repo is the single source of truth. To change code: edit the repo, run
`./install.sh` to deploy, then `omarchy restart shell` (the hot-reload log lies:
it doesn't refresh already-shown widgets — a restart is required).
`bin/` takes effect immediately via symlinks; `plugins/duro.phoneshot/` is
copied by install.sh. Anything edited directly under `~/.config` must be synced
back here and committed.
- Note: Qt6 ShaderEffect no longer accepts inline GLSL (needs a precompiled
  .qsb) — a GPU live-preview proxy was built on 2026-09-07 and reverted because
  it diverged visibly from the final render.
- The project was originally named *paiping*; install.sh migrates old
  `paiping-*` configs, cache, symlinks, plugin dir, and keybinds automatically.

## Install

```bash
cd ~/Projects/screenshot   # wherever you cloned it
./install.sh
```

It does three things:

1. Symlinks `bin/*` into `~/.local/bin/` (already on PATH)
2. Appends to `~/.config/hypr/bindings.lua`:
   ```lua
   hl.unbind("PRINT")
   o.bind("PRINT", "Screenshot", "omarchy-phoneshot-screenshot")
   o.bind("SUPER + SHIFT + PRINT", "Toggle phoneshot", "omarchy-phoneshot-toggle")
   ```
3. Runs `hyprctl reload` and reports config errors

Uninstall: remove those two lines and the symlinks — native screenshots are
untouched.

## Usage

| Key / command | Action |
|---------------|--------|
| `PRINT` | Screenshot (styled or not, per the toggle) |
| `SUPER + SHIFT + PRINT` | Toggle phoneshot mode (notification confirms) |
| `PHONESHOT_LEVEL=hard omarchy-phoneshot-screenshot` | One-off heavy styling |
| `omarchy-phoneshot-apply in.png out.jpg` | Just run the filter |

The toggle state lives in `~/.config/omarchy/phoneshot-mode` (`on` / `off`).
Intensity is controlled by `PHONESHOT_LEVEL`: `mild` / `mid` (default) / `hard`.

## UI language

`~/.config/omarchy/phoneshot-lang` switches panel and notification text:
`zh` / `en`. install.sh seeds it once from the system locale; after editing,
run `omarchy restart shell`.

## Tuning the effect

Everything is at the top of `bin/omarchy-phoneshot-apply`: `MOIRE` / `GRILLE` /
`SCAN` / `CHROMA` / `BLUR` / `NOISE` / `SAT` / `QUALITY`, in three presets
(mild/mid/hard). Re-run `omarchy-phoneshot-apply in out` to preview — nothing
needs a restart.
