import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.commons
import qs.services

ColumnLayout {
  id: root
  width: parent.width
  spacing: ScalerService.s(15)
  property real animationProgress: 0

  SequentialAnimation on animationProgress {
    running: true

    NumberAnimation {
      from: 0
      to: 1
      duration: 500
      easing.type: Easing.Linear
    }
  }

  Text {
    text: "Preset Themes"
    color: theme.primary ? theme.primary.foreground : "#d8dee9"
    opacity: root.animationProgress > 0.1 ? 1 : 0
    Behavior on opacity {
      NumberAnimation {
        duration: 200
      }
    }
    font {
      family: "ComicShannsMono Nerd Font"
      pixelSize: ScalerService.s(18)
      bold: true
    }
    Layout.alignment: Qt.AlignLeft
  }

  GridLayout {
    Layout.fillWidth: true
    columns: 3  // Đã sửa từ: panelManager.fullsetting ? 5 : 3
    columnSpacing: ScalerService.s(10)  // Đã sửa từ: panelManager.fullsetting ? 15 : 10
    rowSpacing: ScalerService.s(10)  // Đã sửa từ: panelManager.fullsetting ? 15 : 10

    Repeater {
      model: [
      {
        name: "Auto",
        type: "matugen",
        accent: "black"
      },
      {
        name: "Macchiato",
        type: "macchiato",
        accent: "#24273a"
      },
      {
        name: "Gruvbox",
        type: "gruvbox",
        accent: "#f5eee6"
      },
      {
        name: "Tokyonight Storm",
        type: "tokyonightStorm",
        accent: "#7aa2f7"
      },
      {
        name: "Nord",
        type: "nord",
        accent: "#88c0d0"
      }
      ]

      delegate: Rectangle {
        id: themeDelegate
        Layout.fillWidth: true
        Layout.preferredHeight: ScalerService.s(60)
        radius: ScalerService.s(8)
        opacity: 0

        SequentialAnimation on opacity {
          running: root.animationProgress > 0.6

          PauseAnimation {
            duration: index * 50
          }

          NumberAnimation {
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
          }
        }
        color: theme.button ? theme.button.background : "#434c5e"
        border {
          color: theme.button ? theme.button.border : "#4c566a"
          width: ScalerService.s(2)
        }

        property var modal: ({
            name: modelData.name,
            type: modelData.type,
            accent: modelData.accent
        })

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            // Chỉ đổi theme nếu khác theme hiện tại
            if (Settings.appearance.theme !== modal.type) {
              Settings.appearance.theme = modal.type;

              // Nếu theme là "matugen", bật dynamic, ngược lại tắt dynamic
              if (modal.type === "matugen") {
                Settings.appearance.dynamic = true;
              } else {
                Settings.appearance.dynamic = false;
              }

              // Không cần gọi reloadTimer vì ThemeService sẽ tự động load
              console.log("Theme changed to:", modal.type, "dynamic:", Settings.appearance.dynamic);
            }
          }
        }

        // ✔ checkmark theme đang active
        Rectangle {
          visible: Settings.appearance.theme === modal.type
          width: ScalerService.s(20)
          height: ScalerService.s(20)
          radius: ScalerService.s(10)
          color: theme.normal ? theme.normal.blue : "#81a1c1"
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: ScalerService.s(5)

          Text {
            text: "✓"
            color: theme.primary ? theme.primary.background : "#2e3440"
            font.pixelSize: ScalerService.s(12)
            font.bold: true
            anchors.centerIn: parent
          }
        }

        RowLayout {
          anchors.fill: parent
          anchors.margins: ScalerService.s(10)
          spacing: ScalerService.s(10)

          Rectangle {
            Layout.preferredWidth: ScalerService.s(40)
            Layout.preferredHeight: ScalerService.s(40)
            radius: ScalerService.s(6)
            color: modal.accent
          }

          Text {
            text: modal.name
            color: theme.primary ? theme.primary.foreground : "#d8dee9"
            wrapMode: Text.WordWrap
            width: ScalerService.s(40)
            horizontalAlignment: Text.AlignLeft
            font {
              family: "ComicShannsMono Nerd Font"
              pixelSize: ScalerService.s(12)  // Đã sửa từ: panelManager.fullsetting ? 16 : 12
              bold: true
            }
          }
        }
      }
    }
  }
}
