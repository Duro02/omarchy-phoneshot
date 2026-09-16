# Phoneshot 开发记录 (Dev log)

设计决策、踩坑、排查结论的存档。给用户看的用法在 [README.md](README.md) /
[README.zh-CN.md](README.zh-CN.md),这里记的是"为什么这么做"。

## 摩尔纹:物理采样模型,不是贴纹理

摩尔纹 = 传感器对屏幕子像素结构的采样走样(aliasing)。实现上画 R|G|B 子像素
竖条在 2x 画布,point 抽回 = 一次传感器重采样。条距取采样周期的近整数比,
沿 keystone 方向带啁啾渐变 → 只在随机"共振位"附近拍出宽频带;再乘一个
低分辨率模糊斑包络,把纹局域成一块(位置每张随机,可落出画面=几乎无纹)。
彩虹色不用染——采到哪个子像素就是哪个色(等效 Bayer 相位差)。hardlight
乘性调制:暗区不出纹(物理),文字带 demosaic 彩边。

参考:imatest 的 Nyquist aliasing 材料、CRT shader 社区配方
(stefanlegg/crt-fx: scanlines/phosphor/chromatic/bloom/vignette)、
silentMoire 的"叠细网格再重采样"思路。

教训:迭代过两版错的做法——① 纯灰网格 dissolve 全屏均布,看着像蒙纱布;
② 灰网格+plasma 染色,彩虹斑方向/密度跟几何无关,假。间距全图都贴近共振比
就会满屏出带,真机只有局部一处。

## 畸变后只留原图内容 (2026-09-13)

透视/旋转曾用黑底补齐再裁回原尺寸,四角黑色楔形 = "屏幕外的内容",一眼假。
改为裁到只含原图像素的最大内接矩形(keystone 梯形和旋转矩形都有闭式解,
四边内缩 1px 消畸变边缘 AA 暗线)。输出尺寸随参数略缩,宁丢信息不造假。
纹理层按终图尺寸生成。坑:旋转内接矩形在 θ≈29° 附近闭式解退化成细条
(2188×5),fallback 只在 ≤0 时触发漏网,后加 <5% 原尺寸判定。

## 分辨率归一 (2026-09-08)

滑杆单位 = 768px 参考宽度下的 px;引擎按 S=W/768 自动换算失焦σ/拖影/
摩尔间距/光栅周期/扫描线周期/色散。之前 4K 终图相对预览几乎是"清水"——
绝对像素参数在 3840 宽下弱了 5 倍。ROTATE(度)/KEYSTONE(比例)无量纲。

## 性能 (两轮)

- 4K 全屏 60s → 一轮 ~15s:工作宽封顶 1920(`PHONESHOT_MAX_WIDTH`)、摩尔
  画布 960、横带 1/4 小画布、`MAGICK_THREAD_LIMIT=4`(blur 是内存带宽型,
  线程多反而慢)。
- 二轮 1080p ~3.8s:画像显示合成 7.9s 中 `-motion-blur` σ7.6 独占 6.9s、
  摩尔绘制 3.0s。手段:拖影 50% 分辨率做(σ 同步减半,~5x 提速)再按比例
  叠回清晰底;纹理四层+畸变链全并行;横带+反光合并单张 amap(screen 满足
  结合律,精确等价);摩尔 `+antialias`+末段 point 放大;畸变并单命令,
  PNG 中间件不落地。768 预览 ~2s。

## 预览架构决策

- 渲染只在松手时启动(拖中零渲染);`omarchy-phoneshot-set ALL` 一次写全五个
  键再渲一次——单槽 pending 曾丢中间键。
- 预览图必须放 `~/.cache/phoneshot/`:写进插件目录会触发 shell 文件监听
  热重载,拖一次滑杆面板闪一次。
- 参数文件+预览图双持久化,开面板即上次状态;拖影方向首次写 MOTION 时把
  MOTION_ANGLE 默认 30 一并落盘(否则引擎随机方向跟面板显示对不上)。
- GPU 实时代理已回退:Qt6 ShaderEffect 不收内联 GLSL(要预编译 .qsb),
  做过的代理与终图偏差明显(2026-09-07)。

## 剪贴板 / 锁 / 输出的坑

- wl-copy 会继承锁 fd 常驻 → 锁只保选区+grim,渲染/剪贴板/通知全在锁外
  (2026-09-08 血案:PRINT 再按静默无事)。
- 做旧版进剪贴板统一转投 `image/png`:Omarchy 剪贴板历史 watcher 只订阅
  `text`+`image/png`,jpeg 不触发记录(2026-09-13)。
- 显式 `copy` 强制不落盘、显式 `save` 强制不碰剪贴板;做旧版没人要就跳过渲染。

## 视觉层 bug 史

- 反光层 `-rotate` 露出虚拟像素黑三角 → 对角明暗分界线;改
  `-virtual-pixel edge -distort SRT` 解决。
- scanmask 曾把 `1×SCAN_P` 小图 `-scale` 拉伸到全屏 → 实际是"下半屏压暗 8%"
  的遮罩,纯白底下一条水平明暗线;改 `tile:` 真平铺,矩形端点修正回 50% 占空。
- 快门横带 10% 提亮太硬 → 随机 3–8%、允许落出画面、25% 概率整条没有。
- 拖影层曾整图替换 → 半分辨往返自带 ~24% 对比度柔化,弱拖影看着像失焦;
  改叠层法:清晰主像 + 方向性鬼影(α=55+m·s·4,上限 92%)。
- grille `-scale ${GRILLE_P}x1` 不带 `!` 保宽高比,间距缩放从未生效,补 `!`。

## 交互模型:面板按钮拍屏,不接管 PRINT (2026-09-16)

最初设计是接管 PRINT(wrapper 按 mode 透传/做旧),后来改成面板动作:
插件 add 完即用,零按键绑定、零 PATH 依赖——点 📱 → 收面板 →
`PHONESHOT_FORCE=1 omarchy-phoneshot-screenshot` 选区做旧。

原因:`omarchy plugin add` 只是 clone,不可能替用户改 Hyprland 绑定;
绑定还要清理卸载残留(删插件后 PRINT 指到已删脚本会彻底失灵)。
面板动作模型下 mode/开关行失去意义,从面板移除;`screenshot` 脚本保留
mode 检查,可选接管路径仍留给想绑键的人(bindings-snippet.lua)。

## 杂项

- 参数钳制:ROTATE±45 / KEYSTONE±30 / DEFOCUS 0–5 / MOTION 0–30,
  手改 params 写非法值只降级不崩。
- chroma `-roll` 会把几 px 颜色缠到对侧边缘(低优先,修要逐通道 distort)。
- 工作流:本仓库是唯一源码,改完 `./install.sh` + `omarchy restart shell`
  (热重载不刷新已显示挂件,实证过)。`bin/` 软链即时生效。
