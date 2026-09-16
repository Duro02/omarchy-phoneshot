#!/bin/bash
# 安装 Phoneshot 插件: 软链 bin 到 ~/.local/bin + 接管 PRINT 快捷键
# Install: symlink bin/ into ~/.local/bin + hijack the PRINT keybind.
set -euo pipefail
cd "$(dirname "$0")"

chmod +x bin/*

mkdir -p ~/.local/bin
for f in bin/*; do
  ln -sf "$PWD/$f" "$HOME/.local/bin/$(basename "$f")"
done
echo "linked: $(ls ~/.local/bin/omarchy-phoneshot-*)"

# ---- 旧名迁移 (paiping -> phoneshot,2026-09 改名) ----
# 旧软链
for old in "$HOME"/.local/bin/omarchy-paiping-*; do
  [[ -L $old ]] && rm -f "$old" && echo "removed old link: $old"
done
# 旧配置:只在新文件不存在时搬,不覆盖
for k in mode params output; do
  old="$HOME/.config/omarchy/paiping-$k"; new="$HOME/.config/omarchy/phoneshot-$k"
  if [[ -f $old && ! -f $new ]]; then
    mv "$old" "$new" && echo "migrated: paiping-$k -> phoneshot-$k"
  fi
done
# 输出配置里的值名 clipboard=paiping 也改了
if [[ -f $HOME/.config/omarchy/phoneshot-output ]]; then
  sed -i 's/^\(clipboard[[:space:]]*=[[:space:]]*\)paiping/\1phoneshot/' \
    "$HOME/.config/omarchy/phoneshot-output"
fi
# 旧预览缓存
if [[ -d $HOME/.cache/paiping && ! -d $HOME/.cache/phoneshot ]]; then
  mv "$HOME/.cache/paiping" "$HOME/.cache/phoneshot" && echo "migrated: cache dir"
fi
# 旧插件目录:确认 manifest id 后删除(内容是本仓库旧拷贝,git 里可恢复;
# 留着会和新插件并存,栏上出两个图标)
if grep -q '"id": "duro.paiping"' \
    "$HOME/.config/omarchy/plugins/duro.paiping/manifest.json" 2>/dev/null; then
  rm -rf "$HOME/.config/omarchy/plugins/duro.paiping"
  echo "removed old plugin dir: duro.paiping"
fi
# bindings.lua 里的旧命令名
BINDINGS=~/.config/hypr/bindings.lua
if grep -q "omarchy-paiping-" "$BINDINGS" 2>/dev/null; then
  cp "$BINDINGS" "$BINDINGS.bak.$(date +%s)"
  sed -i 's/omarchy-paiping-/omarchy-phoneshot-/g; s/Toggle paiping/Toggle phoneshot/' "$BINDINGS"
  echo "bindings.lua: paiping -> phoneshot (backup saved)"
fi

# 插件部署(幂等):仓库源码 -> shell 插件目录。改完 QML 跑一遍 install.sh,
# 再 omarchy restart shell (注意:shell 的插件热重载不会刷新已显示的挂件,
# 必须重启 shell,已用图标字形变化实证)。sample.png 只在缺失时放。
mkdir -p ~/.config/omarchy/plugins/duro.phoneshot
cp -f plugins/duro.phoneshot/manifest.json plugins/duro.phoneshot/BarWidget.qml \
  ~/.config/omarchy/plugins/duro.phoneshot/
[[ -f ~/.config/omarchy/plugins/duro.phoneshot/sample.png ]] || \
  cp plugins/duro.phoneshot/sample.png ~/.config/omarchy/plugins/duro.phoneshot/
echo "plugin deployed: ~/.config/omarchy/plugins/duro.phoneshot/"

# 快捷键接管(幂等:已存在则跳过)
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
