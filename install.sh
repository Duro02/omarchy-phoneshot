#!/bin/bash
# 安装拍屏插件: 软链 bin 到 ~/.local/bin + 接管 PRINT 快捷键
set -euo pipefail
cd "$(dirname "$0")"

chmod +x bin/*

mkdir -p ~/.local/bin
for f in bin/*; do
  ln -sf "$PWD/$f" "$HOME/.local/bin/$(basename "$f")"
done
echo "linked: $(ls ~/.local/bin/omarchy-paiping-*)"

# 插件部署(幂等):仓库源码 -> shell 插件目录。改完 QML 跑一遍 install.sh,
# 再 omarchy restart shell (注意:shell 的插件热重载不会刷新已显示的挂件,
# 必须重启 shell,已用图标字形变化实证)。sample.png 只在缺失时放。
mkdir -p ~/.config/omarchy/plugins/duro.paiping
cp -f plugins/duro.paiping/manifest.json plugins/duro.paiping/BarWidget.qml \
  ~/.config/omarchy/plugins/duro.paiping/
[[ -f ~/.config/omarchy/plugins/duro.paiping/sample.png ]] || \
  cp plugins/duro.paiping/sample.png ~/.config/omarchy/plugins/duro.paiping/
echo "plugin deployed: ~/.config/omarchy/plugins/duro.paiping/"

# 快捷键接管(幂等:已存在则跳过)
BINDINGS=~/.config/hypr/bindings.lua
MARKER="omarchy-paiping-screenshot"
if grep -q "$MARKER" "$BINDINGS"; then
  echo "bindings.lua 已接管,跳过"
else
  cp "$BINDINGS" "$BINDINGS.bak.$(date +%s)"
  cat bindings-snippet.lua >>"$BINDINGS"
  echo "bindings.lua 已追加接管(原文件已备份)"
fi

hyprctl reload
sleep 0.5
if hyprctl configerrors 2>&1 | grep -qi "error"; then
  echo "⚠️ hypr 有报错,看看:"; hyprctl configerrors
else
  echo "✅ hypr 配置无报错"
fi

echo -n "off" > ~/.config/omarchy/paiping-mode
 echo "当前模式: off (默认关闭,原生截图不受影响)"
echo "按 SUPER+SHIFT+PRINT 开/关拍屏,PRINT 截图"
