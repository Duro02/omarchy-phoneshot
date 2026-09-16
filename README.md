# Phoneshot 📸

**中文**: [README.zh-CN.md](README.zh-CN.md)

Turn a crisp screenshot into a convincing "phone photographing a screen" image — an Omarchy plugin.

![before / after](docs/demo.jpg)

- `PRINT` stays 100% native — nothing is hijacked. The styled shot is a button in the bar panel: click 📱, the panel closes, you pick a region, done
- Rainbow moiré from a real sensor-sampling model, LCD subpixel grille, scanlines, chromatic aberration, perspective, defocus, motion blur, glare / rolling-shutter band, grain, JPEG recompression
- Writes `*-phoneshot.jpg` next to the original PNG; the styled copy goes to the clipboard (as PNG, so Omarchy's clipboard history records it)

## Install

```bash
omarchy plugin add https://github.com/Duro02/omarchy-phoneshot --enable
```

Done — that's the whole install. The repo root is a valid plugin
(`manifest.json` + `BarWidget.qml`), so `plugin add` clones everything into
`~/.config/omarchy/plugins/duro.phoneshot/`; the panel calls the renderer
scripts inside the plugin dir, so no PATH or keybind setup is needed.

Update later with `omarchy plugin update duro.phoneshot`.

## Usage

| Action | What happens |
|--------|--------------|
| Bar icon → **Take a phoneshot** | Panel closes, pick a region, styled shot lands on disk + clipboard |
| `PRINT` | Native Omarchy screenshot, untouched |
| `PHONESHOT_LEVEL=hard omarchy-phoneshot-screenshot` | One-off heavy styling |
| `omarchy-phoneshot-apply in.png out.jpg` | Run the filter standalone (scripts live in the plugin dir's `bin/`; install.sh symlinks them into `~/.local/bin` for PATH use) |

Intensity preset: `PHONESHOT_LEVEL` = `mild` / `mid` (default) / `hard`.

The panel has five sliders plus a "Randomize parameters" button. Releasing a
slider re-renders the preview — the preview uses the same engine and the same
parameters as a real shot.

Want `PRINT` itself to produce phoneshots? Optional: paste
`bindings-snippet.lua` into `~/.config/hypr/bindings.lua` and `hyprctl reload`.
The wrapper then styles when `~/.config/omarchy/phoneshot-mode` says `on`
(`omarchy-phoneshot-toggle` flips it), and passes through to native when `off`.

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
rm ~/.local/bin/omarchy-phoneshot-*   # if you ran install.sh
```

If you added the optional keybind lines, delete them from
`~/.config/hypr/bindings.lua`. Native screenshots are unaffected.

## Development

This repo is the source of truth. Edit here, run `./install.sh`, then
`omarchy restart shell`. Design decisions and bug history live in
[DEVLOG.md](DEVLOG.md).
