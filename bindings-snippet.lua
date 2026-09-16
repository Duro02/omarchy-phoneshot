-- Phoneshot 快捷键: PRINT 接管 + 一键开关
-- Phoneshot keybinds: hijack PRINT + toggle. Appended by install.sh (skipped if present).
-- 用插件目录绝对路径,不依赖 ~/.local/bin 软链;exec 走 sh -c,$HOME 可展开。
hl.unbind("PRINT")
o.bind("PRINT", "Screenshot", "$HOME/.config/omarchy/plugins/duro.phoneshot/bin/omarchy-phoneshot-screenshot")
o.bind("SUPER + SHIFT + PRINT", "Toggle phoneshot", "$HOME/.config/omarchy/plugins/duro.phoneshot/bin/omarchy-phoneshot-toggle")
