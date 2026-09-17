# Phoneshot 拍屏

[English](README.md) | **简体中文**

将清晰的屏幕截图转换为逼真的「手机拍摄屏幕」效果 —— 专为 Omarchy 打造的扩展插件。

![before / after](docs/demo.jpg)

### 效果特性

- **逼真光学效果**：基于真实传感器采样模型的彩虹摩尔纹、LCD 亚像素栅格、扫描线及色散边缘。
- **真实摄影特征**：水平梯形侧视透视、面内微倾旋转、镜头失焦模糊、手抖拖影与反光 / 卷帘快门光带。
- **质感拟真**：画面噪点颗粒与二次 JPEG 压缩特征。
- **双轨输出**：自动保存做旧图片（`*-phoneshot.jpg`）与原图 PNG，并将做旧图转为 PNG 写入剪贴板。

## 依赖要求

Omarchy 已内置所需全部工具（`grim`、`slurp`、`magick`、`wl-copy`），无需安装额外依赖或后台服务。

## 安装

```bash
omarchy plugin add https://github.com/Duro02/omarchy-phoneshot --enable
```

更新插件：

```bash
omarchy plugin update duro.phoneshot
```

## 使用方法

| 方式 / 命令 | 说明 |
|-------------|------|
| 顶栏图标 → **拍屏截图** | 收起面板并框选区域，自动生成拍屏图并落盘及写入剪贴板 |
| `omarchy-phoneshot-screenshot` | 命令行直接触发拍屏截图 |
| `PHONESHOT_LEVEL=hard omarchy-phoneshot-screenshot` | 使用指定强度档位进行截图 |
| `omarchy-phoneshot-apply in.png out.jpg [level]` | 独立滤镜工具：将拍屏效果应用于现有图片 |

CLI 脚本位于插件的 `bin/` 目录（`~/.config/omarchy/plugins/duro.phoneshot/bin/`）。在该目录跑一次 `install.sh` 可将脚本软链进 `~/.local/bin`，之后即可直接按命令名调用。

### 强度档位

可通过环境变量 `PHONESHOT_LEVEL`（或在配置文件中设置 `level`）选择预设强度：
- `mild`：轻度摩尔纹与颗粒，微弱模糊。
- `mid`：标准拟真手机拍屏观感（默认）。
- `hard`：重度摩尔纹、明显光带与更强烈的模糊及压缩感。

### 交互面板与实时预览

点击顶栏相机图标可展开参数面板，提供 5 项微调滑杆与「随机一组参数」按钮。调节任意滑杆松手后，右侧预览图（缓存在 `~/.cache/phoneshot/preview.jpg`）将即时更新。预览图与最终截图采用相同的底层算法与参数。

## 调节参数

| 参数 | 键名 | 范围 | 说明 |
|------|------|------|------|
| 旋转 | `ROTATE` | −5° ～ +5° | 画面面内旋转（负数顺时针，正数逆时针） |
| 侧视 | `KEYSTONE` | −12° ～ +12° | 梯形透视角度（正数右侧拍摄，负数左侧拍摄） |
| 失焦 | `DEFOCUS` | 0 ～ 2.0 | 镜头脱焦均匀模糊（同时自然弱化摩尔纹） |
| 拖影 | `MOTION` | 0 ～ 8 px | 快门手抖产生的方向性重影长度 |
| 拖影方向 | `MOTION_ANGLE` | 0° ～ 180° | 拖影延伸方向角度 |

> **说明**：透视与旋转处理时会自动裁切为画面真实内容的最大内接矩形，确保边缘平整无多余填充。

也可通过命令行修改单独参数：
```bash
omarchy-phoneshot-set <KEY> <VAL>
# 示例：
omarchy-phoneshot-set ROTATE 2.5
```

## 配置文件

配置文件存放于 `~/.config/omarchy/` 目录：

- **`phoneshot-params`**：保存当前生效的 5 项参数（`ROTATE`、`KEYSTONE`、`DEFOCUS`、`MOTION`、`MOTION_ANGLE`）。
- **`phoneshot-output`**：控制图片保存与剪贴板行为（所有字段均为可选）：
  ```ini
  clipboard=phoneshot      # original（原图）| phoneshot（做旧图）| none（不写入）
  save_original=true       # 是否保存原清晰截图
  save_phoneshot=true      # 是否保存做旧图
  output_dir=              # 保存目录，留空使用 Omarchy 默认截图目录
  level=mid                # 强度预设：mild | mid | hard
  notify=true              # 是否发送桌面通知
  ```
  *（截图参数显式指定 `copy` 时跳过落盘，指定 `save` 时跳过剪贴板；若做旧图既不落盘也不进剪贴板，会自动跳过做旧渲染。）*
- **`phoneshot-mode`**：存储当前开关状态（`on` 或 `off`）。
- **`phoneshot-lang`**：控制界面与通知语言（`zh` 或 `en`）。

## 界面语言

面板与通知语言由 `~/.config/omarchy/phoneshot-lang`（`zh` 或 `en`）决定。

切换语言：
```bash
echo "en" > ~/.config/omarchy/phoneshot-lang
omarchy restart shell
```

## 可选功能：快捷键集成

可将 Phoneshot 与键盘快捷键深度集成，一键截图或在拍屏与标准截图模式间自由切换。

将 `bindings-snippet.lua` 的配置内容追加到 `~/.config/hypr/bindings.lua`：

```lua
hl.unbind("PRINT")
o.bind("PRINT", "Screenshot", "$HOME/.config/omarchy/plugins/duro.phoneshot/bin/omarchy-phoneshot-screenshot")
o.bind("SUPER + SHIFT + PRINT", "Toggle phoneshot", "$HOME/.config/omarchy/plugins/duro.phoneshot/bin/omarchy-phoneshot-toggle")
```

重新加载快捷键：
```bash
hyprctl reload
```

- **`PRINT`**：触发截图。拍屏模式开启时生成做旧图，关闭时执行原生截图。
- **`SUPER + SHIFT + PRINT`**：通过 `omarchy-phoneshot-toggle` 快捷切换拍屏模式的开启与关闭。
- **`PHONESHOT_FORCE=1`**：环境变量，附带该变量调用 `omarchy-phoneshot-screenshot` 可忽略当前模式直接执行拍屏截图。

## 卸载

```bash
omarchy plugin remove duro.phoneshot
```

若添加过上述可选快捷键，从 `~/.config/hypr/bindings.lua` 中删除对应内容即可。

## 许可证

[MIT License](LICENSE) © [Duro02](https://github.com/Duro02/omarchy-phoneshot)
