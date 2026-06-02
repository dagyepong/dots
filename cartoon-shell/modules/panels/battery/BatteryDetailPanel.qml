import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.services
import qs.commons
import "./" as Components

PanelWindow {
  id: batteryDetailPanel

  property var sizes: currentSizes.batteryDetailPanel || {}

  width: ScalerService.s(450)
  height: ScalerService.s(400)
  anchors {
    // Anchor theo vị trí của bar
    left: Settings.bar.position === "left"
    right: Settings.bar.position === "right" || Settings.bar.position === "top" || Settings.bar.position === "bottom"
    top: Settings.bar.position === "top"
    bottom: Settings.bar.position === "left" || Settings.bar.position === "right" || Settings.bar.position === "bottom"
  }

  margins {
    top: Settings.bar.position === "top" ? ScalerService.s(10) : 0
    bottom: (Settings.bar.position === "bottom" || Settings.bar.position === "left" || Settings.bar.position === "right") ? ScalerService.s(10) : 0
    left: Settings.bar.position === "left" ? ScalerService.s(10) : 0
    right: (Settings.bar.position === "right" || Settings.bar.position === "top" || Settings.bar.position === "bottom") ? ScalerService.s(10) : 0
  }
  color: "transparent"

  Rectangle {
    anchors.fill: parent
    color: theme.primary.background
    radius: ScalerService.s(8)
    border.color: theme.normal.black
    border.width: ScalerService.s(3)

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: ScalerService.s(16)
      spacing: ScalerService.s(16)

      // Header
      Text {
        text: "🔋 Battery Details"
        font.family: "ComicShannsMono Nerd Font"
        color: theme.primary.foreground
        font.bold: true
        font.pixelSize: ScalerService.s(16)
        Layout.alignment: Qt.AlignHCenter
      }

      // Battery Panel Component
      Components.BatteryPanel {
        Layout.fillWidth: true
        Layout.fillHeight: true
      }
    }
  }

  Timer {
    interval: 2000
    running: batteryDetailPanel.visible
    repeat: true
    onTriggered: {
      // Refresh data khi panel hiển thị
    }
  }

  Component.onCompleted: {
    // Khởi tạo dữ liệu
  }
}
