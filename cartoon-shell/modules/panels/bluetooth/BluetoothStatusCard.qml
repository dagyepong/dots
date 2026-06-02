// Status card component for Bluetooth panel
import QtQuick
import QtQuick.Layouts
import qs.services

Rectangle {
  id: statusCard
  required property var adapter
  required property int connectedCount

  Layout.fillWidth: true
  height: ScalerService.s(82)
  radius: ScalerService.s(12)
  color: theme.primary.dim_background
  border.width: ScalerService.s(3)
  border.color: theme.normal.black

  RowLayout {
    anchors.fill: parent
    anchors.margins: ScalerService.s(14)
    spacing: ScalerService.s(12)

    // Left column: status and device count
    ColumnLayout {
      Layout.fillWidth: true
      spacing: ScalerService.s(4)

      Text {
        text: adapter?.enabled ? (lang?.bluetooth?.enabled || "Bluetooth đang bật") : (lang?.bluetooth?.disabled || "Bluetooth đang tắt")
        color: adapter?.enabled ? theme.button.text : theme.primary.dim_foreground
        font.pixelSize: ScalerService.s(20)
        font.family: "ComicShannsMono Nerd Font"
        font.bold: true

        Behavior on color {
          ColorAnimation {
            duration: 200
          }
        }
      }

      Text {
        text: `${connectedCount} ` + (lang?.bluetooth?.devices_connected || "thiết bị đã kết nối")
        color: theme.primary.dim_foreground
        font.pixelSize: ScalerService.s(16)
        font.family: "ComicShannsMono Nerd Font"
        visible: adapter?.enabled || false
      }
    }

    Item {
      Layout.fillWidth: true
    }

    // Toggle button
    Rectangle {
      width: ScalerService.s(56)
      height: ScalerService.s(32)
      radius: ScalerService.s(16)
      color: adapter?.enabled ? theme.button.text : theme.button.background
      opacity: adapter ? 1 : 0.5

      scale: toggleMouseArea.containsPress ? 0.95 : (toggleMouseArea.containsMouse ? 1.05 : 1.0)
      Behavior on scale {
        NumberAnimation {
          duration: 150
          easing.type: Easing.OutBack
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: 300
        }
      }

      Rectangle {
        x: adapter?.enabled ? parent.width - width - ScalerService.s(4) : ScalerService.s(4)
        y: ScalerService.s(4)
        width: ScalerService.s(24)
        height: ScalerService.s(24)
        radius: ScalerService.s(12)
        color: theme.primary.dim_background

        Behavior on x {
          NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
          }
        }
      }

      MouseArea {
        id: toggleMouseArea
        anchors.fill: parent
        enabled: !!adapter
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (adapter) {
            adapter.enabled = !adapter.enabled;
            if (adapter.enabled) {
              // When enabling Bluetooth, set necessary modes
              adapter.pairable = true;
              adapter.discoverable = true;
            }
          }
        }
      }
    }
  }
}
