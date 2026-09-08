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
  moduleName: "duro.paiping"

  property bool popupOpen: false
  function close() { popupOpen = false }

  // 渲染预览放 ~/.cache(写插件目录会触发 shell 热重载,拖一次闪一次)。
  // preview.jpg 持久化:下次打开面板直接显示上次渲染好的,不重新渲染。
  readonly property string previewFile: Quickshell.env("HOME") + "/.cache/paiping/preview.jpg"

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



  readonly property string paipingBin: Quickshell.env("HOME") + "/.local/bin/"

  // 拖动中调这个:只记最新值+防抖;松手会再调 applyNow 立刻执行。
  function scheduleApply(key, val) {
    if (key === "ROTATE") rotateVal = val
    else if (key === "KEYSTONE") keystoneVal = val
    else if (key === "DEFOCUS") defocusVal = val
    else if (key === "MOTION") motionVal = val
    else if (key === "MOTION_ANGLE") motionAngleVal = val
    // 只记最新值;渲染由 setProc 跑完触发,拖动中不跟手
    pendingDirty = true
    applyDebounce.restart()
  }
  function applyNow() {
    applyDebounce.stop()
    if (setProc.running || !pendingDirty) return
    pendingDirty = false
    setProc.command = [paipingBin + "omarchy-paiping-set", "ALL",
      "ROTATE=" + rotateVal, "KEYSTONE=" + keystoneVal, "DEFOCUS=" + defocusVal,
      "MOTION=" + motionVal, "MOTION_ANGLE=" + motionAngleVal]
    setProc.running = true
  }

  Timer {
    id: applyDebounce
    interval: 400
    repeat: false
    onTriggered: root.applyNow()
  }

  // omarchy-paiping-set:写参数+重算预览图(~3秒);跑完刷新显示,有排队的再跑。
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
    command: ["cat", Quickshell.env("HOME") + "/.config/omarchy/paiping-params"]
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
        root.previewCheck.running = true
      }
    }
  }
  // 面板打开时:参数从文件恢复上次的值,预览图直接显示上次渲染好的。
  Process {
    id: previewCheck
    command: ["test", "-f", root.previewFile]
    onExited: {
      if (previewCheck.exitCode !== 0) root.scheduleApply("ROTATE", root.rotateVal)
    }
  }
  Component.onCompleted: loadProc.running = true

  // 一行参数:标签+数值+拖动条。dragged=拖动中(防抖),settled=松手(立刻)。
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
    tooltipText: "拍屏:截图做旧参数"

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
      Column {
        id: paramColumn
        width: Style.space(240)
        spacing: Style.space(10)

        PanelSectionHeader {
          text: "参数"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Column {
          id: paramRows
          width: parent.width
          spacing: Style.space(8)

          SliderRow {
            label: "旋转(−顺/+逆)"
            min: -5; max: 5; step: 0.5
            val: root.rotateVal
            onDragged: function(v) { root.scheduleApply("ROTATE", Math.round(v * 10) / 10) }
            onSettled: function(v) { root.scheduleApply("ROTATE", Math.round(v * 10) / 10); root.applyNow() }
          }
          SliderRow {
            label: "侧视(左−/右+)"
            min: -12; max: 12; step: 0.5
            val: root.keystoneVal
            onDragged: function(v) { root.scheduleApply("KEYSTONE", Math.round(v * 10) / 10) }
            onSettled: function(v) { root.scheduleApply("KEYSTONE", Math.round(v * 10) / 10); root.applyNow() }
          }
          SliderRow {
            label: "失焦"
            min: 0; max: 2; step: 0.1
            val: root.defocusVal
            onDragged: function(v) { root.scheduleApply("DEFOCUS", Math.round(v * 10) / 10) }
            onSettled: function(v) { root.scheduleApply("DEFOCUS", Math.round(v * 10) / 10); root.applyNow() }
          }
          SliderRow {
            label: "拖影"
            min: 0; max: 8; step: 0.5
            val: root.motionVal
            onDragged: function(v) { root.scheduleApply("MOTION", Math.round(v * 10) / 10) }
            onSettled: function(v) { root.scheduleApply("MOTION", Math.round(v * 10) / 10); root.applyNow() }
          }
          SliderRow {
            label: "拖影方向"
            min: 0; max: 180; step: 5; integer: true; decimals: 0
            val: root.motionAngleVal
            onDragged: function(v) { root.scheduleApply("MOTION_ANGLE", Math.round(v)) }
            onSettled: function(v) { root.scheduleApply("MOTION_ANGLE", Math.round(v)); root.applyNow() }
          }
        }
      }

      // ---------- 右:预览 ----------
      Column {
        width: parent.width - paramColumn.width - parent.spacing
        spacing: Style.space(8)

        PanelSectionHeader {
          text: "预览"
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
          width: parent.width
          wrapMode: Text.WordWrap
          text: (setProc.running ? "渲染中…" : "R" + root.rotateVal + " K" + root.keystoneVal + " D" + root.defocusVal + " M" + root.motionVal + "@" + root.motionAngleVal + " · 上次渲染效果,拖动更新")
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
