-- 拍屏插件快捷键: PRINT 接管 + 一键开关
-- 由 install.sh 追加,已有则跳过
hl.unbind("PRINT")
o.bind("PRINT", "Screenshot", "omarchy-paiping-screenshot")
o.bind("SUPER + SHIFT + PRINT", "Toggle paiping", "omarchy-paiping-toggle")
