#!/bin/bash
# Phoneshot setup (all optional): ~/.local/bin symlinks for CLI use,
# dev-checkout deploy to the plugin dir, phoneshot-lang default.
# 便利安装(全部可选): ~/.local/bin 软链 + 开发仓库部署到插件目录 +
# 界面语言默认值。不改任何按键绑定——PRINT 保持原生,拍屏走面板 📱 按钮。
#
# 面板/预览不依赖软链:脚本一律走插件目录内绝对路径。
# 想让 PRINT 也出拍屏图(可选): 把 bindings-snippet.lua 两行贴进
# ~/.config/hypr/bindings.lua 再 hyprctl reload。
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

# PRINT 默认不接管:面板里的 📱 按钮直接触发"选区+做旧",原生 PRINT 不动。
# 想把 PRINT 也接管成拍屏的,把 bindings-snippet.lua 两行贴进
# ~/.config/hypr/bindings.lua 再 hyprctl reload 即可(可选)。

# 界面语言:按系统 locale 落一次默认,之后用户改 ~/.config/omarchy/phoneshot-lang
LANG_FILE=~/.config/omarchy/phoneshot-lang
if [[ ! -f $LANG_FILE ]]; then
  case "${LANG:-en}" in zh*) echo -n zh >"$LANG_FILE" ;; *) echo -n en >"$LANG_FILE" ;; esac
  echo "lang default: $(cat "$LANG_FILE") (edit $LANG_FILE to switch)"
fi

# 模式文件只在缺失时建 off(仅当用户自己把 PRINT 绑到 wrapper 时才有意义)
[[ -f ~/.config/omarchy/phoneshot-mode ]] || echo -n "off" > ~/.config/omarchy/phoneshot-mode
echo "done. 面板 📱 按钮直接拍屏;要接管 PRINT 见 bindings-snippet.lua"
