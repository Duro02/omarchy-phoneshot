#!/bin/bash
# Phoneshot install: symlink bin/ into ~/.local/bin + hijack the PRINT keybind.
# 安装: 软链 bin 到 ~/.local/bin + 接管 PRINT 快捷键。
#
# 两种用法:
#   omarchy plugin add <repo-url> --enable   # 插件进 ~/.config/omarchy/plugins/
#   ~/.config/omarchy/plugins/duro.phoneshot/install.sh   # 再跑本脚本接管按键
# 开发仓库里直接跑本脚本: 顺带把 manifest/QML 拷到插件目录。
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
# 开发仓库里跑则拷过去。改完 QML 需 omarchy restart shell 才生效。
PLUGIN_TARGET="$HOME/.config/omarchy/plugins/duro.phoneshot"
if [[ $(realpath "$PWD") == $(realpath -m "$PLUGIN_TARGET") ]]; then
  echo "in-place install at $PLUGIN_TARGET, plugin files already there"
else
  mkdir -p "$PLUGIN_TARGET"
  cp -f manifest.json BarWidget.qml "$PLUGIN_TARGET"/
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
