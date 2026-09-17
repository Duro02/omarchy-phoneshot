# Phoneshot

[简体中文](README.zh-CN.md) | **English**

An Omarchy plugin that turns crisp screenshots into convincing "phone photographing a screen" images.

![before / after](docs/demo.jpg)

### Features

- **Realistic Optical Artifacts**: Rainbow moiré patterns (sensor sampling model), LCD subpixel grille, scanlines, and chromatic aberration.
- **Physical Camera Effects**: Keystone perspective tilt, roll rotation, lens defocus blur, camera shake motion blur, and glare / rolling shutter bands.
- **Analog Texture**: Sensor noise grain and realistic JPEG recompression.
- **Seamless Output**: Saves the styled shot (`*-phoneshot.jpg`) alongside the original PNG, and copies the styled image to the clipboard as PNG.

## Requirements

All required dependencies (`grim`, `slurp`, `magick`, `wl-copy`) ship pre-installed with Omarchy.

## Installation

```bash
omarchy plugin add https://github.com/Duro02/omarchy-phoneshot --enable
```

To update to the latest version:

```bash
omarchy plugin update duro.phoneshot
```

## Usage

| Action / Command | Description |
|------------------|-------------|
| Bar icon → **Take a phoneshot** | Closes the panel, prompts for a screen region, and outputs the styled shot to disk and clipboard |
| `omarchy-phoneshot-screenshot` | Captures a phoneshot directly via CLI |
| `PHONESHOT_LEVEL=hard omarchy-phoneshot-screenshot` | Captures a phoneshot with a specific intensity level |
| `omarchy-phoneshot-apply in.png out.jpg [level]` | Standalone filter tool: applies the phoneshot styling to an existing image |

CLI scripts live in the plugin's `bin/` directory (`~/.config/omarchy/plugins/duro.phoneshot/bin/`). Run `install.sh` once from that directory to symlink them into `~/.local/bin` so they work as bare commands.

### Intensity Presets

Set the `PHONESHOT_LEVEL` environment variable (or configure `level` in the output config) to one of:
- `mild`: Subtle moiré and grain, minimal blur.
- `mid`: Balanced everyday screen photo look (default).
- `hard`: Heavy moiré, strong glare, higher blur and compression.

### Interactive Panel & Preview

Clicking the bar icon opens an adjustment panel with five sliders and a **Randomize parameters** button. Releasing any slider automatically updates the live preview (cached at `~/.cache/phoneshot/preview.jpg`), which uses the exact same rendering engine and parameters as real captures.

## Parameters

| Parameter | Key | Range | Description |
|-----------|-----|-------|-------------|
| Roll | `ROTATE` | −5° to +5° | In-plane rotation (− = clockwise, + = counter-clockwise) |
| Side view | `KEYSTONE` | −12° to +12° | Keystone perspective (+ = right side, − = left side) |
| Defocus | `DEFOCUS` | 0 to 2.0 | Lens out-of-focus blur (also softens moiré) |
| Motion blur | `MOTION` | 0 to 8 px | Camera shake blur distance |
| Blur angle | `MOTION_ANGLE` | 0° to 180° | Motion blur streak angle |

> **Note**: Perspective and rotation automatically crop to the largest inscribed rectangle of real pixels, ensuring clean edges without padding.

Parameters can also be set via the CLI:
```bash
omarchy-phoneshot-set <KEY> <VAL>
# Example:
omarchy-phoneshot-set ROTATE 2.5
```

## Configuration

Configuration files are located in `~/.config/omarchy/`:

- **`phoneshot-params`**: Holds the current values of the five parameters (`ROTATE`, `KEYSTONE`, `DEFOCUS`, `MOTION`, `MOTION_ANGLE`).
- **`phoneshot-output`**: Controls capture output and clipboard destinations (all fields optional):
  ```ini
  clipboard=phoneshot      # original | phoneshot | none
  save_original=true
  save_phoneshot=true
  output_dir=              # empty = default Omarchy screenshot directory
  level=mid                # mild | mid | hard
  notify=true
  ```
  *(Calling screenshots with `copy` skips disk writes; calling with `save` skips clipboard copying. If a styled image is neither saved nor copied, rendering is skipped.)*
- **`phoneshot-mode`**: Stores the current toggle mode (`on` or `off`).
- **`phoneshot-lang`**: Controls UI and notification language (`en` or `zh`).

## UI Language

The panel and notification language is controlled by `~/.config/omarchy/phoneshot-lang` (`zh` or `en`).

To switch languages:
```bash
echo "zh" > ~/.config/omarchy/phoneshot-lang
omarchy restart shell
```

## Optional: Keybinding Integration

You can integrate Phoneshot directly with your keyboard shortcuts to capture styled screenshots or toggle modes on the fly.

Append the snippet from `bindings-snippet.lua` to `~/.config/hypr/bindings.lua`:

```lua
hl.unbind("PRINT")
o.bind("PRINT", "Screenshot", "$HOME/.config/omarchy/plugins/duro.phoneshot/bin/omarchy-phoneshot-screenshot")
o.bind("SUPER + SHIFT + PRINT", "Toggle phoneshot", "$HOME/.config/omarchy/plugins/duro.phoneshot/bin/omarchy-phoneshot-toggle")
```

Then reload keybindings:
```bash
hyprctl reload
```

- **`PRINT`**: Captures a screenshot. When phoneshot mode is `on`, it produces a styled shot; when `off`, it takes a standard screenshot.
- **`SUPER + SHIFT + PRINT`**: Toggles phoneshot mode between `on` and `off` using `omarchy-phoneshot-toggle`.
- **`PHONESHOT_FORCE=1`**: Prefixing `omarchy-phoneshot-screenshot` with this environment variable captures a styled phoneshot regardless of the current toggle state.

## Uninstall

```bash
omarchy plugin remove duro.phoneshot
```

If you configured the optional keybindings, remove the added lines from `~/.config/hypr/bindings.lua`.

## License

[MIT](LICENSE) © [Duro02](https://github.com/Duro02/omarchy-phoneshot)
