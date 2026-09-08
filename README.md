# 拍屏插件 (paiping) 📸

把清晰的区域截图，一键做旧成「手机拍屏幕」的模糊效果。

- 按 `PRINT` 走正常 Omarchy 截图流程（选区 / grim），再按开关决定是否做旧
- 默认**关闭**（原生长截图），随时可开 —— 可选接管，不污染默认行为
- 效果（v2，全套拍屏质感）：摩尔干涉波纹 + LCD 亚像素光栅 + 扫描线 + 色散 + 透视手抖 + 失焦 + 反光/快门横带 + 颗粒 + JPEG 二次压缩
- 参考：CRT shader 社区配方（stefanlegg/crt-fx：scanlines / phosphor / chromatic / bloom / vignette）、silentMoire 的人工摩尔纹思路（叠加错位细网格再重采样）
- 输出 `*-paiping.jpg`，原清晰 PNG 也保留，剪贴板里放的是做旧版

## 文件

```
bin/omarchy-paiping-apply       纯滤镜: 输入清晰图 -> 输出拍屏图 (ImageMagick)
bin/omarchy-paiping-screenshot  接管 PRINT 的 wrapper (开关关时直接透传原生截图)
bin/omarchy-paiping-toggle      开关切换
bin/omarchy-paiping-set         面板后端: 写参数文件 + 重算预览图
~/.config/omarchy/plugins/duro.paiping/   shell插件: 顶栏图标+参数面板+实时预览
~/.config/omarchy/paiping-params           参数文件(KEY=VALUE,面板与PRINT截图共用)
install.sh                      安装到 ~/.local/bin + 写 Hyprland 快捷键
bindings-snippet.lua            快捷键片段(给 install.sh 用, 也可手贴)
```

## 面板参数(第一批)

| 滑杆 | 范围 | 默认 | 说明 |
|------|------|------|------|
| 旋转 | −5–+5° | 0 | 整图面内 roll,负=顺时针/正=逆时针,确定性 |
| 侧视 | −12–+12° | 0 | 从一侧拍的梯形透视,正=右侧拍/负=左侧拍,近侧拉高远侧压缩 |
| 失焦 | 0–2.0 | 0.8 | 对不上焦的均匀模糊;糊上去后摩尔纹自动衰减(物理联动) |
| 拖影 | 0–8px | 0 | 快门瞬间手抖的方向性重影 |
| 拖影方向 | 0–180° | 30 | 拖影朝向,0=横/90=竖 |

## 预览(拖完渲染,所见即所得)

面板右列直接显示 magick 渲染图,跟 PRINT 真实截图同一引擎同一参数:
拖动滑杆只记值不渲染,松手才 `omarchy-paiping-set` 写参数+重算
`~/.cache/paiping/preview.jpg` (~3秒,状态条显示"渲染中…") -> 面板刷新。
拖动过程中不跟手,停手等渲染——渲染即终图质量,无需二次确认。
- 参数(`paiping-params`)+渲染图(`preview.jpg`)双持久化:下次打开面板,
  滑杆是上次的值,预览是上次渲染好的;刚安装(两文件皆无)则全零效果+补渲染一次。
- 新滑杆初值统一跟 mid 预设等价值对齐(R0/K0/M0,D0.8),保证第一次渲染
  滑杆与效果严格对应;拖影方向首次写 MOTION 时把默认值(30)一并落盘,
  避免引擎随机方向跟面板显示对不上。
- 面板一次写全五个键(`set ALL`),快拖多滑杆不丢键(单槽 pending 曾丢中间键)。

## 分辨率归一(2026-09-08)

滑杆单位 = 768px 参考宽度下的 px;引擎按 S=W/768 自动换算失焦σ/拖影/
摩尔间距/光栅周期/扫描线周期/色散。之前 4K 终图相对预览几乎是"清水"——
绝对像素参数在 3840 宽下弱了 5 倍。现在 768 预览与 4K 输出观感一致
(已验证同参数两版并排)。ROTATE(度)/KEYSTONE(比例)无量纲,不受影响。

## 性能(2026-09-08)

4K 全屏曾要 60 秒:摩尔 2x 画布、σ90 横带大模糊、11 线程抢内存带宽。
现 4K 约 15 秒:工作宽封顶 1920(`PAIPING_MAX_WIDTH`,0=不限)、摩尔画布压到 960
输出(768 预览路径数值完全一致)、横带 1/4 小画布、`MAGICK_THREAD_LIMIT=4`。
768 预览仍 3 秒左右。瓶颈在 motion-blur 与全帧混合,机器内存吃紧时方差大。

## 输出配置(`paiping-output`)

跟调参文件分开。字段:`clipboard=original|paiping|none`(默认 paiping)、
`save_original`/`save_paiping`(默认 true)、`output_dir`(空=跟原生目录)、
`level=mild|mid|hard`(默认 mid,环境变量优先)、`notify`(默认 true)。
规则:显式 `copy` 强制不落盘、显式 `save` 强制不碰剪贴板;非法值用默认并在通知里说;
做旧版没人要(不存+不进剪贴板)就跳过十几秒渲染;锁只保选区+grim,渲染/剪贴板/通知不占锁
(wl-copy 常驻继承锁 fd 会把后面的截图全静默挡掉,2026-09-08 血案)。

## 版本管理

本仓库是唯一源码。以后改代码先改仓库,再跑 `./install.sh` 部署,
最后 `omarchy restart shell`(热重载日志不可信:它不刷新已显示挂件,必须重启)。
`bin/` 通过软链实时生效;`plugins/duro.paiping/` 靠 install.sh 拷贝部署。
直接改 `~/.config` 下的文件必须同步回仓库再提交。
- 注意:Qt6 的 ShaderEffect 不再接受内联 GLSL(必须预编译 .qsb)——
  2026-09-07 曾据此做过 GPU 实时代理,效果与终图偏差明显,已整体回退到渲染图。

## 安装

```bash
cd ~/Projects/screenshot
./install.sh
```

它会做三件事:

1. 把 `bin/*` 软链到 `~/.local/bin/` (已在 PATH)
2. 在 `~/.config/hypr/bindings.lua` 追加:
   ```lua
   hl.unbind("PRINT")
   o.bind("PRINT", "Screenshot", "omarchy-paiping-screenshot")
   o.bind("SUPER + SHIFT + PRINT", "Toggle paiping", "omarchy-paiping-toggle")
   ```
3. `hyprctl reload` 验证无报错

卸载：删掉这两行、删软链即可，原生截图不受影响。

## 用法

| 按键 | 动作 |
|------|------|
| `PRINT` | 截图（做旧与否看开关） |
| `SUPER + SHIFT + PRINT` | 开 / 关拍屏模式（右上通知提示） |
| `PAIPING_LEVEL=hard omarchy-paiping-screenshot` | 单次重度做旧 |
| `omarchy-paiping-apply in.png out.jpg` | 只跑滤镜 |

开关状态存在 `~/.config/omarchy/paiping-mode`，内容 `on` / `off`。
强度由 `PAIPING_LEVEL` 控制：`mild` / `mid`(默认) / `hard`。

## 效果调参

都在 `bin/omarchy-paiping-apply` 顶部：`BLUR` / `NOISE` / `TILT` / `QUALITY`。
改完直接重跑 `omarchy-paiping-apply 原图 输出` 预览，不用重启任何东西。
