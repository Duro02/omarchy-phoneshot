-- Phoneshot 快捷键: PRINT 接管 + 一键开关
-- Phoneshot keybinds: hijack PRINT + toggle. Appended by install.sh (skipped if present).
hl.unbind("PRINT")
o.bind("PRINT", "Screenshot", "omarchy-phoneshot-screenshot")
o.bind("SUPER + SHIFT + PRINT", "Toggle phoneshot", "omarchy-phoneshot-toggle")
