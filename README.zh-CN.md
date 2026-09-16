# Phoneshot 拍屏插件 📸

**English**: [README.md](README.md)

把清晰的区域截图，一键做旧成「手机拍屏幕」的模糊效果。

- 按 `PRINT` 走正常 Omarchy 截图流程（选区 / grim），再按开关决定是否做旧
- 默认**关闭**（原生长截图），随时可开 —— 可选接管，不污染默认行为
- 效果（v2，全套拍屏质感）：彩虹摩尔纹（传感器采样模型）+ LCD 亚像素光栅 + 扫描线 + 色散 + 透视手抖 + 失焦 + 反光/快门横带 + 颗粒 + JPEG 二次压缩
- 摩尔纹是物理采样模型不是贴纹理：画 R|G|B 子像素竖条再 point 抽回 = 一次传感器重采样；条距沿 keystone 方向渐变，只在"共振位"附近拍出宽带（局域到一处、位置每张随机、可能落出画面 = 几乎无纹），彩虹色由采到哪个子像素决定——拍带跟着拍摄角度走、暗区不出纹（hardlight 乘性调制）、文字带 demosaic 彩边
- 参考：CRT shader 社区配方（stefanlegg/crt-fx：scanlines / phosphor / chromatic / bloom / vignette）、silentMoire 的人工摩尔纹思路（叠加错位细网格再重采样）
- 输出 `*-phoneshot.jpg`，原清晰 PNG 也保留，剪贴板里放的是做旧版

## 文件

```
bin/omarchy-phoneshot-apply       纯滤镜: 输入清晰图 -> 输出拍屏图 (ImageMagick)
bin/omarchy-phoneshot-screenshot  接管 PRINT 的 wrapper (开关关时直接透传原生截图)
bin/omarchy-phoneshot-toggle      开关切换
bin/omarchy-phoneshot-set         面板后端: 写参数文件 + 重算预览图
~/.config/omarchy/plugins/duro.phoneshot/   shell插件: 顶栏图标+参数面板+实时预览
~/.config/omarchy/phoneshot-params           参数文件(KEY=VALUE,面板与PRINT截图共用)
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

## 畸变后只留原图内容(2026-09-13)

透视/旋转曾用黑底补齐再裁回原尺寸,四角黑色楔形是"屏幕外的内容",一眼假。
现在畸变后裁到**只含原图像素的最大内接矩形**(解析解,各边内缩 1px 消 AA 暗线),
输出尺寸略小于原图、随参数变,宁丢信息不造假。纹理层按终图尺寸生成,观感不变。

## 预览(拖完渲染,所见即所得)

面板右列直接显示 magick 渲染图,跟 PRINT 真实截图同一引擎同一参数:
拖动滑杆只记值不渲染,松手才 `omarchy-phoneshot-set` 写参数+重算
`~/.cache/phoneshot/preview.jpg` (~3秒,状态条显示"渲染中…") -> 面板刷新。
拖动过程中不跟手,停手等渲染——渲染即终图质量,无需二次确认。
- 参数(`phoneshot-params`)+渲染图(`preview.jpg`)双持久化:下次打开面板,
  滑杆是上次的值,预览是上次渲染好的;刚安装(两文件皆无)则全零效果+补渲染一次。
- 新滑杆初值统一跟 mid 预设等价值对齐(R0/K0/M0,D0.8),保证第一次渲染
  滑杆与效果严格对应;拖影方向首次写 MOTION 时把默认值(30)一并落盘,
  避免引擎随机方向跟面板显示对不上。
- 面板一次写全五个键(`set ALL`),快拖多滑杆不丢键(单槽 pending 曾丢中间键)。
- 底部「随机一组参数」按钮:随机五个滑杆(侧视/失焦/拖影用三角分布
  偏小幅值,更像真拍),走同一 `set ALL` 落盘+渲染,预览所见即所得。

## 分辨率归一(2026-09-08)

滑杆单位 = 768px 参考宽度下的 px;引擎按 S=W/768 自动换算失焦σ/拖影/
摩尔间距/光栅周期/扫描线周期/色散。之前 4K 终图相对预览几乎是"清水"——
绝对像素参数在 3840 宽下弱了 5 倍。现在 768 预览与 4K 输出观感一致
(已验证同参数两版并排)。ROTATE(度)/KEYSTONE(比例)无量纲,不受影响。

## 性能(2026-09-13 二轮)

4K 全屏曾要 60 秒 → 一轮压到 ~15s(宽封顶 1920、摩尔画布 960、横带 1/4 画布、线程 4)
→ 二轮 1080p 约 **3.8s**(画像:合成 7.9s 中 motion-blur 独占 6.9s,摩尔绘制 3.0s)。
二轮手段:拖影降到 50% 分辨率做(σ 同步减半,模糊类视觉无损,~5x 提速);
纹理四层与畸变链全并行;横带+反光合并成单张 amap(screen 结合律,精确等价);
摩尔绘制 `+antialias`+末段 point 放大;畸变合为单条命令,PNG 中间件不落地。
768 预览约 2 秒。`PHONESHOT_MAX_WIDTH`(默认 1920,0=不限)/`MAGICK_THREAD_LIMIT`(4)仍可覆盖。

## 输出配置(`phoneshot-output`)

跟调参文件分开。字段:`clipboard=original|phoneshot|none`(默认 phoneshot)、
`save_original`/`save_phoneshot`(默认 true)、`output_dir`(空=跟原生目录)、
`level=mild|mid|hard`(默认 mid,环境变量优先)、`notify`(默认 true)。
规则:显式 `copy` 强制不落盘、显式 `save` 强制不碰剪贴板;非法值用默认并在通知里说;
做旧版没人要(不存+不进剪贴板)就跳过十几秒渲染;锁只保选区+grim,渲染/剪贴板/通知不占锁
(wl-copy 常驻继承锁 fd 会把后面的截图全静默挡掉,2026-09-08 血案)。
做旧版进剪贴板统一转投 `image/png`:shell 剪贴板历史只 watch `text`+`image/png`,
直接喂 jpeg 时历史里查无此图(剪贴板本体是好的,只是历史不记,2026-09-13)。

## 版本管理

本仓库是唯一源码。以后改代码先改仓库,再跑 `./install.sh` 部署,
最后 `omarchy restart shell`(热重载日志不可信:它不刷新已显示挂件,必须重启)。
`bin/` 通过软链实时生效;`plugins/duro.phoneshot/` 靠 install.sh 拷贝部署。
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
   o.bind("PRINT", "Screenshot", "omarchy-phoneshot-screenshot")
   o.bind("SUPER + SHIFT + PRINT", "Toggle phoneshot", "omarchy-phoneshot-toggle")
   ```
3. `hyprctl reload` 验证无报错

卸载：删掉这两行、删软链即可，原生截图不受影响。

## 用法

| 按键 | 动作 |
|------|------|
| `PRINT` | 截图（做旧与否看开关） |
| `SUPER + SHIFT + PRINT` | 开 / 关拍屏模式（右上通知提示） |
| `PHONESHOT_LEVEL=hard omarchy-phoneshot-screenshot` | 单次重度做旧 |
| `omarchy-phoneshot-apply in.png out.jpg` | 只跑滤镜 |

开关状态存在 `~/.config/omarchy/phoneshot-mode`，内容 `on` / `off`。
强度由 `PHONESHOT_LEVEL` 控制：`mild` / `mid`(默认) / `hard`。

## 界面语言

`~/.config/omarchy/phoneshot-lang` 控制面板与通知文案：`zh` / `en`。
install.sh 按系统 locale 落一次默认值，改完 `omarchy restart shell` 生效。

## 效果调参

都在 `bin/omarchy-phoneshot-apply` 顶部：`MOIRE` / `GRILLE` / `SCAN` /
`CHROMA` / `BLUR` / `NOISE` / `SAT` / `QUALITY`，按 mild/mid/hard 三档预设。
改完直接重跑 `omarchy-phoneshot-apply 原图 输出` 预览，不用重启任何东西。
