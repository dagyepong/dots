// components/Settings/ClockPanelToggle.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.commons

Item {
  implicitHeight: clockPanelToggle.implicitHeight
  RowLayout {
    id: clockPanelToggle

    spacing: ScalerService.s(10)

    Text {
      text: lang.appearance?.clock_panel_label || "Bảng đồng hồ:"
      color: theme.primary.foreground
      font.family: "ComicShannsMono Nerd Font"
      font.pixelSize: ScalerService.s(16)
      Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
    }

    Item {
      Layout.fillWidth: true
    }

    Switch {
      id: autoStartSwitch
      checked: Settings.clock.enableWidget || false
      onToggled: {
        Settings.clock.enableWidget = checked;
      }
      Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

      background: Rectangle {
        implicitWidth: ScalerService.s(48)
        implicitHeight: ScalerService.s(28)
        radius: ScalerService.s(14)
        color: autoStartSwitch.checked ? theme.button.text : theme.button.background
        border.color: autoStartSwitch.checked ? theme.button.text : theme.button.border
        border.width: ScalerService.s(2)
      }

      indicator: Rectangle {
        x: autoStartSwitch.checked ? parent.background.width - width - ScalerService.s(4) : ScalerService.s(4)
        y: (parent.background.height - height) / 2
        width: ScalerService.s(20)
        height: ScalerService.s(20)
        radius: ScalerService.s(10)
        color: theme.primary.background

        Behavior on x {
          NumberAnimation {
            duration: 150
          }
        }
      }
    }
  }
}
