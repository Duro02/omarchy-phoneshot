# Phoneshot 📸

**中文**: [README.zh-CN.md](README.zh-CN.md)

Turn a crisp screenshot into a convincing "phone photographing a screen" image — an Omarchy plugin.

![before / after](docs/demo.jpg)

- `PRINT` keeps the normal Omarchy screenshot flow (region select / grim); a toggle decides whether the result gets styled
- **Off by default** — native screenshots are untouched
- Rainbow moiré from a real sensor-sampling model, LCD subpixel grille, scanlines, chromatic aberration, perspective, defocus, motion blur, glare / rolling-shutter band, grain, JPEG recompression
- Writes `*-phoneshot.jpg` next to the original PNG; the styled copy goes to the clipboard (as PNG, so Omarchy's clipboard history records it)

## Install

```bash
omarchy plugin add https://github.com/Duro02/omarchy-phoneshot --enable
~/.config/omarchy/plugins/duro.phoneshot/install.sh
```

`omarchy plugin add` clones this repo into `~/.config/omarchy/plugins/duro.phoneshot/`
(the repo root is a valid plugin: `manifest.json` + `BarWidget.qml`).
`install.sh` then symlinks the renderer scripts into `~/.local/bin/` and appends the
keybinds to `~/.config/hypr/bindings.lua`:

```lua
hl.unbind("PRINT")
o.bind("PRINT", "Screenshot", "omarchy-phoneshot-screenshot")
o.bind("SUPER + SHIFT + PRINT", "Toggle phoneshot", "omarchy-phoneshot-toggle")
```

Update later with `omarchy plugin update duro.phoneshot` (bin/ symlinks follow the checkout).

## Usage

| Key / command | Action |
|---------------|--------|
| `PRINT` | Screenshot (styled or not, per the toggle) |
| `SUPER + SHIFT + PRINT` | Toggle phoneshot mode (notification confirms) |
| `PHONESHOT_LEVEL=hard omarchy-phoneshot-screenshot` | One-off heavy styling |
| `omarchy-phoneshot-apply in.png out.jpg` | Run the filter standalone |

Toggle state lives in `~/.config/omarchy/phoneshot-mode` (`on`/`off`).
Intensity preset: `PHONESHOT_LEVEL` = `mild` / `mid` (default) / `hard`.

A bar icon opens the parameter panel: five sliders plus a "Randomize parameters"
button. Releasing a slider re-renders the preview — the preview uses the same
engine and the same parameters as a real PRINT shot.

| Slider | Range | Notes |
|--------|-------|-------|
| Roll | −5–+5° | In-plane rotation, −=cw/+=ccw |
| Side view | −12–+12° | Keystone perspective, + = shot from the right |
| Defocus | 0–2.0 | Out-of-focus blur (also suppresses moiré) |
| Motion blur | 0–8px | Directional handshake ghosting |
| Blur angle | 0–180° | Streak direction |

Perspective/rotation never fabricate pixels outside the source: the result is
cropped to the largest inscribed rectangle of real content, so the output is
slightly smaller than the input and varies with the parameters.

## Output config

`~/.config/omarchy/phoneshot-output` (all fields optional):

```
clipboard=phoneshot      # original | phoneshot | none
save_original=true
save_phoneshot=true
output_dir=              # empty = the native screenshot dir
level=mid                # mild | mid | hard
notify=true
```

`PRINT … copy` forces no disk write; `PRINT … save` forces no clipboard.
If the styled image is neither saved nor copied, rendering is skipped entirely.

## UI language

`~/.config/omarchy/phoneshot-lang` = `zh` or `en` — controls the panel and
notification text. install.sh seeds it once from the system locale; edit it and
run `omarchy restart shell` to apply.

## Uninstall

```bash
omarchy plugin remove duro.phoneshot
rm ~/.local/bin/omarchy-phoneshot-*
```

Then delete the two keybind lines from `~/.config/hypr/bindings.lua`.
Native screenshots are unaffected.

## Development

This repo is the source of truth. Edit here, run `./install.sh`, then
`omarchy restart shell`. Design decisions and bug history live in
[DEVLOG.md](DEVLOG.md).
