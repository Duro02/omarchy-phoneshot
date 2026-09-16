import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// 拍屏插件:顶栏相机图标,点击弹出左右布局面板。
// 左列 = 参数拖动条;右列 = magick 渲染预览(拖完防抖渲染,结果落盘持久化)。
// 预览与 PRINT 真实截图同一引擎同一参数,所见即所得。
BarWidget {
  id: root
  moduleName: "duro.phoneshot"

  property bool popupOpen: false
  function close() { popupOpen = false }

  // 界面语言: ~/.config/omarchy/phoneshot-lang (zh|en,缺省 en)
  property string lang: "en"
  function tr(zh, en) { return lang.indexOf("zh") === 0 ? zh : en }
  Process {
    id: langProc
    command: ["cat", Quickshell.env("HOME") + "/.config/omarchy/phoneshot-lang"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { var l = String(text).trim(); if (l) root.lang = l }
    }
  }

  // 渲染预览放 ~/.cache(写插件目录会触发 shell 热重载,拖一次闪一次)。
  // preview.jpg 持久化:下次打开面板直接显示上次渲染好的,不重新渲染。
  readonly property string previewFile: Quickshell.env("HOME") + "/.cache/phoneshot/preview.jpg"

  // 强制 Image 重载磁盘文件(同一 URL 不会自动刷新)。
  function refreshPreview() {
    previewImage.source = ""
    previewImage.source = "file://" + previewFile
  }

  // ---- 可调参数(初值=mid预设等价值,启动时从参数文件恢复上次的值) ----
  // R0/K0/M0 零几何零拖影;D0.8 是 mid 预设的底糊,跟引擎 fallback 一致,
  // 保证刚安装第一次渲染时滑杆与效果严格对应。
  property real rotateVal: 0
  property real keystoneVal: 0
  property real defocusVal: 0.8
  property real motionVal: 0
  property real motionAngleVal: 30
  // 脏标记:值已进属性,applyNow 一次写全五个键,不丢键
  property bool pendingDirty: false

  // 拍屏开关状态(~/.config/omarchy/phoneshot-mode)。FileView 监听文件:
  // 快捷键在外面切了模式,这里马上跟着变,不只在面板打开时对齐。
  property bool enabledState: false
  FileView {
    id: modeFile
    path: Quickshell.env("HOME") + "/.config/omarchy/phoneshot-mode"
    watchChanges: true
    printErrors: false
    onFileChanged: modeFile.reload()
    onLoaded: root.enabledState = (modeFile.text().trim() === "on")
    onLoadFailed: root.enabledState = false
  }
  Process {
    id: toggleProc
    command: [Quickshell.env("HOME") + "/.local/bin/omarchy-phoneshot-toggle"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.enabledState = (String(text).trim() === "on") }
    }
  }



  readonly property string phoneshotBin: Quickshell.env("HOME") + "/.local/bin/"

  // 拖动中调这个:只更新属性+脏标记,不启动任何渲染,拖动中图纹丝不动。
  // 渲染只在松手时启动( settled → applyNow 立刻执行)。
  function scheduleApply(key, val) {
    if (key === "ROTATE") rotateVal = val
    else if (key === "KEYSTONE") keystoneVal = val
    else if (key === "DEFOCUS") defocusVal = val
    else if (key === "MOTION") motionVal = val
    else if (key === "MOTION_ANGLE") motionAngleVal = val
    // 只记脏;松手前绝不渲染
    pendingDirty = true
  }
  function applyNow() {
    if (setProc.running || !pendingDirty) return
    pendingDirty = false
    setProc.command = [phoneshotBin + "omarchy-phoneshot-set", "ALL",
      "ROTATE=" + rotateVal, "KEYSTONE=" + keystoneVal, "DEFOCUS=" + defocusVal,
      "MOTION=" + motionVal, "MOTION_ANGLE=" + motionAngleVal]
    setProc.running = true
  }

  // omarchy-phoneshot-set:写参数+重算预览图(~3秒);跑完刷新显示,有排队的再跑。
  Process {
    id: setProc
    onExited: {
      root.refreshPreview()
      root.applyNow()
    }
  }

  // 启动时读回上次调的参数,滑杆跟文件对齐(文件不存在就用 mid 初值)。
  Process {
    id: loadProc
    command: ["cat", Quickshell.env("HOME") + "/.config/omarchy/phoneshot-params"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text).split("\n")
        for (var i = 0; i < lines.length; i++) {
          var kv = lines[i].split("=")
          if (kv.length !== 2) continue
          var v = parseFloat(kv[1])
          if (isNaN(v)) continue
          if (kv[0] === "ROTATE") root.rotateVal = v
          else if (kv[0] === "KEYSTONE") root.keystoneVal = v
          else if (kv[0] === "DEFOCUS") root.defocusVal = v
          else if (kv[0] === "MOTION") root.motionVal = v
          else if (kv[0] === "MOTION_ANGLE") root.motionAngleVal = v
        }
        // 参数恢复完再看预览图在不在,缺失(刚安装/清过缓存)才补渲染一次
        // TEMP:直连引用曾报 undefined,改走属性中转
        root.needPreviewCheck = true
      }
    }
  }
  // 面板打开时:参数从文件恢复上次的值,预览图直接显示上次渲染好的。
  // 缺失才补渲染一次(走 stdout 文本,不依赖 exitCode 注入)。
  // running 绑属性 flag:StdioCollector 回调里直引兄弟 id 会报 undefined,绕开。
  property bool needPreviewCheck: false
  Process {
    id: previewCheck
    running: root.needPreviewCheck
    command: ["sh", "-c", "if test -f \"$1\"; then echo PRESENT; else echo MISSING; fi", "sh", root.previewFile]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (String(text).indexOf("MISSING") >= 0) root.scheduleApply("ROTATE", root.rotateVal)
      }
    }
  }
  Component.onCompleted: { loadProc.running = true; langProc.running = true }

  // 一行参数:标签+数值+拖动条。dragged=拖动中(只记值不渲染),settled=松手(启动渲染)。
  component SliderRow: Column {
    required property string label
    required property real min
    required property real max
    required property real step
    property bool integer: false
    required property real val
    property int decimals: 1
    signal dragged(real v)
    signal settled(real v)

    width: parent.width
    spacing: Style.space(2)

    Row {
      width: parent.width

      Text {
        width: parent.width - valueLabel.width
        text: label
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        id: valueLabel
        text: integer ? String(Math.round(val)) : Number(val).toFixed(decimals)
        color: Qt.darker(root.bar.foreground, 1.3)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    PanelSlider {
      width: parent.width
      bar: root.bar
      minimum: min
      maximum: max
      step: step
      integer: integer
      value: val
      onMoved: function(v) { dragged(v) }
      onReleased: function(v) { settled(v) }
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // 和蓝牙/wifi 同款:小手光标 + tooltip 都是 BarIconButton 自带的
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰄀"
    tooltipText: root.tr("拍屏:截图做旧参数", "Phoneshot: screen-photo styling")

    onPressed: function(b) {
      if (b === Qt.LeftButton) root.popupOpen = !root.popupOpen
    }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(780))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    Row {
      id: content
      anchors.fill: parent
      spacing: Style.space(16)

      // ---------- 左:参数 ----------
      Item {
        id: paramColumn
        width: Style.space(240)
        height: parent.height

        Column {
          id: topCol
          width: parent.width
          spacing: Style.space(10)

          // 拍屏总开关:左文字右裸开关,只有开关可点(Toggle 组件整行吃点击,不用它)。
          // busy 吞掉重复点击,状态以 phoneshot-mode 文件为准(FileView 监听)。
          Row {
            width: parent.width
            height: modeSwitch.implicitHeight

            Column {
              width: parent.width - modeSwitch.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.spacing.xs
              Text {
                text: root.tr("拍屏模式", "Phoneshot")
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.subtitle
              }
              Text {
                text: root.tr("PRINT 截图做旧", "Style PRINT screenshots")
                color: Qt.darker(root.bar.foreground, 1.3)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
            ToggleSwitch {
              id: modeSwitch
              anchors.verticalCenter: parent.verticalCenter
              checked: root.enabledState
              busy: toggleProc.running
              foreground: root.bar.foreground
              onToggled: { if (!toggleProc.running) toggleProc.running = true }
            }
          }

          PanelSectionHeader {
            text: root.tr("参数", "Parameters")
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Column {
            id: paramRows
            width: parent.width
            spacing: Style.space(8)

          SliderRow {
            label: root.tr("旋转(−顺/+逆)", "Roll (−cw/+ccw)")
            min: -5; max: 5; step: 0.5
            val: root.rotateVal
            onDragged: function(v) { root.scheduleApply("ROTATE", Math.round(v * 10) / 10) }
            onSettled: function(v) { root.scheduleApply("ROTATE", Math.round(v * 10) / 10); root.applyNow() }
          }
          SliderRow {
            label: root.tr("侧视(左−/右+)", "Side view (−left/+right)")
            min: -12; max: 12; step: 0.5
            val: root.keystoneVal
            onDragged: function(v) { root.scheduleApply("KEYSTONE", Math.round(v * 10) / 10) }
            onSettled: function(v) { root.scheduleApply("KEYSTONE", Math.round(v * 10) / 10); root.applyNow() }
          }
          SliderRow {
            label: root.tr("失焦", "Defocus")
            min: 0; max: 2; step: 0.1
            val: root.defocusVal
            onDragged: function(v) { root.scheduleApply("DEFOCUS", Math.round(v * 10) / 10) }
            onSettled: function(v) { root.scheduleApply("DEFOCUS", Math.round(v * 10) / 10); root.applyNow() }
          }
          SliderRow {
            label: root.tr("拖影", "Motion blur")
            min: 0; max: 8; step: 0.5
            val: root.motionVal
            onDragged: function(v) { root.scheduleApply("MOTION", Math.round(v * 10) / 10) }
            onSettled: function(v) { root.scheduleApply("MOTION", Math.round(v * 10) / 10); root.applyNow() }
          }
          SliderRow {
            label: root.tr("拖影方向", "Blur angle")
            min: 0; max: 180; step: 5; integer: true; decimals: 0
            val: root.motionAngleVal
            onDragged: function(v) { root.scheduleApply("MOTION_ANGLE", Math.round(v)) }
            onSettled: function(v) { root.scheduleApply("MOTION_ANGLE", Math.round(v)); root.applyNow() }
          }
          }
        }

        // 随机一组拍摄参数:侧视/失焦/拖影用三角分布偏小幅值,更像真拍;
        // 写参数文件+重渲染,预览所见即 PRINT 所得。
        // 在滑块下方剩余空间里居中:上间距 = 下间距。
        Item {
          anchors.top: topCol.bottom
          anchors.bottom: parent.bottom
          width: parent.width

          Button {
            width: parent.width
            anchors.centerIn: parent
            bordered: true
            text: root.tr("随机一组参数", "Randomize parameters")
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: {
              root.rotateVal = Math.round((Math.random() * 2 - 1) * 5 * 2) / 2
              var k = Math.random() + Math.random() - 1            // 三角分布 [-1,1]
              root.keystoneVal = Math.round(k * 12 * 2) / 2
              root.defocusVal = Math.round(Math.random() * Math.random() * 2 * 10) / 10
              root.motionVal = Math.round(Math.random() * Math.random() * 8 * 2) / 2
              root.motionAngleVal = Math.round(Math.random() * 36) * 5
              root.pendingDirty = true
              root.applyNow()
            }
          }
        }
      }

      // ---------- 右:预览 ----------
      Column {
        id: previewCol
        width: parent.width - paramColumn.width - parent.spacing
        spacing: Style.space(8)

        PanelSectionHeader {
          text: root.tr("预览", "Preview")
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        BorderSurface {
          width: parent.width
          height: Style.space(320)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)
          clip: true

          Rectangle {
            anchors.fill: parent
            color: "black"
          }

          // 预览图:magick 渲染结果,落盘持久化,打开即上次效果。
          Image {
            id: previewImage
            anchors.fill: parent
            anchors.margins: Style.space(2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            source: "file://" + root.previewFile
          }
        }

        Text {
          id: statusText
          width: parent.width
          wrapMode: Text.WordWrap
          text: (setProc.running ? root.tr("渲染中…", "Rendering…") : "R" + root.rotateVal + " K" + root.keystoneVal + " D" + root.defocusVal + " M" + root.motionVal + "@" + root.motionAngleVal + " · " + root.tr("上次渲染效果,拖动更新", "last render, drag to update"))
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
