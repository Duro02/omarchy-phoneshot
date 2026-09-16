#!/bin/bash
# Phoneshot install: hijack the PRINT keybind (+ optional ~/.local/bin symlinks).
# 安装: 接管 PRINT 快捷键(+可选的 ~/.local/bin 软链,方便命令行调用)。
#
# 面板/预览不依赖软链:脚本一律走插件目录内绝对路径。
# plugin add 之后唯一要做的就是 bindings.lua 里的两行绑定(插件装的时候
# 不可能自动改 Hyprland 配置)——跑本脚本,或手动把 bindings-snippet.lua
# 两行贴进 ~/.config/hypr/bindings.lua。
set -euo pipefail
cd "$(dirname "$0")"

chmod +x bin/*

mkdir -p ~/.local/bin
for f in bin/*; do
  ln -sf "$PWD/$f" "$HOME/.local/bin/$(basename "$f")"
done
echo "linked: $(ls ~/.local/bin/omarchy-phoneshot-*)"

# 插件部署(幂等):manifest.json 在仓库根,仓库本身即插件。
# 已在插件目录里(plugin add clone 进来的)原地运行则跳过拷贝;
# 开发仓库里跑则拷过去——连 bin/ 一起拷,面板调脚本走插件目录路径,
# 不依赖 ~/.local/bin。改完 QML 需 omarchy restart shell 才生效。
PLUGIN_TARGET="$HOME/.config/omarchy/plugins/duro.phoneshot"
if [[ $(realpath "$PWD") == $(realpath -m "$PLUGIN_TARGET") ]]; then
  echo "in-place install at $PLUGIN_TARGET, plugin files already there"
else
  mkdir -p "$PLUGIN_TARGET"
  cp -f manifest.json BarWidget.qml "$PLUGIN_TARGET"/
  cp -rf bin "$PLUGIN_TARGET"/
  [[ -f $PLUGIN_TARGET/sample.png ]] || cp sample.png "$PLUGIN_TARGET"/
  echo "plugin deployed: $PLUGIN_TARGET/"
fi

# 快捷键接管(幂等:已存在则跳过)
BINDINGS=~/.config/hypr/bindings.lua
MARKER="omarchy-phoneshot-screenshot"
if grep -q "$MARKER" "$BINDINGS"; then
  echo "bindings.lua already patched, skipped"
else
  cp "$BINDINGS" "$BINDINGS.bak.$(date +%s)"
  cat bindings-snippet.lua >>"$BINDINGS"
  echo "bindings.lua appended (backup saved)"
fi

# 界面语言:按系统 locale 落一次默认,之后用户改 ~/.config/omarchy/phoneshot-lang
LANG_FILE=~/.config/omarchy/phoneshot-lang
if [[ ! -f $LANG_FILE ]]; then
  case "${LANG:-en}" in zh*) echo -n zh >"$LANG_FILE" ;; *) echo -n en >"$LANG_FILE" ;; esac
  echo "lang default: $(cat "$LANG_FILE") (edit $LANG_FILE to switch)"
fi

hyprctl reload
sleep 0.5
if hyprctl configerrors 2>&1 | grep -qi "error"; then
  echo "⚠️ hypr config errors:"; hyprctl configerrors
else
  echo "✅ hypr config clean"
fi

# 模式文件只在缺失时建 off,不覆盖现有开关状态
[[ -f ~/.config/omarchy/phoneshot-mode ]] || echo -n "off" > ~/.config/omarchy/phoneshot-mode
echo "mode: $(cat ~/.config/omarchy/phoneshot-mode) (off = native screenshots untouched)"
echo "SUPER+SHIFT+PRINT toggles phoneshot, PRINT screenshots"
