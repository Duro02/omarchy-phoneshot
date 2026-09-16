# Phoneshot 拍屏插件 📸

**English**: [README.md](README.md)

把清晰的截图，一键做旧成「手机拍屏幕」的效果 —— Omarchy 插件。

![before / after](docs/demo.jpg)

- 按 `PRINT` 走正常 Omarchy 截图流程（选区 / grim），开关决定是否做旧
- 默认**关闭**，原生截图不受影响
- 效果：彩虹摩尔纹（传感器采样模型）+ LCD 亚像素光栅 + 扫描线 + 色散 +
  透视手抖 + 失焦 + 反光/快门横带 + 颗粒 + JPEG 二次压缩
- 输出 `*-phoneshot.jpg`，原清晰 PNG 也保留；做旧版进剪贴板
  （转投 PNG,Omarchy 剪贴板历史能记录）

## 安装

```bash
omarchy plugin add https://github.com/Duro02/omarchy-phoneshot --enable
~/.config/omarchy/plugins/duro.phoneshot/install.sh
```

`omarchy plugin add` 会把本仓库 clone 到 `~/.config/omarchy/plugins/duro.phoneshot/`
（仓库根就是合法插件：`manifest.json` + `BarWidget.qml`)。
`install.sh` 再把渲染脚本软链到 `~/.local/bin/`，并往
`~/.config/hypr/bindings.lua` 追加快捷键：

```lua
hl.unbind("PRINT")
o.bind("PRINT", "Screenshot", "omarchy-phoneshot-screenshot")
o.bind("SUPER + SHIFT + PRINT", "Toggle phoneshot", "omarchy-phoneshot-toggle")
```

以后更新用 `omarchy plugin update duro.phoneshot`(bin/ 软链跟着 checkout 走）。

## 用法

| 按键 / 命令 | 动作 |
|------|------|
| `PRINT` | 截图（做旧与否看开关） |
| `SUPER + SHIFT + PRINT` | 开 / 关拍屏模式（通知提示） |
| `PHONESHOT_LEVEL=hard omarchy-phoneshot-screenshot` | 单次重度做旧 |
| `omarchy-phoneshot-apply in.png out.jpg` | 只跑滤镜 |

开关状态存在 `~/.config/omarchy/phoneshot-mode`(`on`/`off`)。
强度档位 `PHONESHOT_LEVEL`:`mild` / `mid`（默认）/ `hard`。

顶栏相机图标打开参数面板：五个滑杆 + 「随机一组参数」按钮。松手即重渲染
预览——预览和 PRINT 真实截图同一引擎同一参数。

| 滑杆 | 范围 | 说明 |
|------|------|------|
| 旋转 | −5–+5° | 面内 roll，负=顺时针/正=逆时针 |
| 侧视 | −12–+12° | 梯形透视，正=右侧拍/负=左侧拍 |
| 失焦 | 0–2.0 | 对不上焦的均匀模糊（也会压掉摩尔纹） |
| 拖影 | 0–8px | 快门瞬间手抖的方向性重影 |
| 拖影方向 | 0–180° | 拖影朝向，0=横/90=竖 |

透视/旋转不会编造原图之外的像素：成品裁到只含原图内容的最大内接矩形，
输出尺寸略小于原图、随参数变化。

## 输出配置

`~/.config/omarchy/phoneshot-output`（全部字段可缺席）:

```
clipboard=phoneshot      # original | phoneshot | none
save_original=true
save_phoneshot=true
output_dir=              # 空 = 跟原生截图目录
level=mid                # mild | mid | hard
notify=true
```

显式 `copy` 强制不落盘、显式 `save` 强制不碰剪贴板；
做旧版既不存也不进剪贴板时直接跳过渲染。

## 界面语言

`~/.config/omarchy/phoneshot-lang` 写 `zh` 或 `en`，控制面板与通知文案。
install.sh 按系统 locale 落一次默认，改完 `omarchy restart shell` 生效。

## 卸载

```bash
omarchy plugin remove duro.phoneshot
rm ~/.local/bin/omarchy-phoneshot-*
```

再从 `~/.config/hypr/bindings.lua` 删掉两行快捷键。原生截图不受影响。

## 开发

本仓库是唯一源码：改完跑 `./install.sh`，再 `omarchy restart shell`。
设计决策与踩坑记录见 [DEVLOG.md](DEVLOG.md)。
