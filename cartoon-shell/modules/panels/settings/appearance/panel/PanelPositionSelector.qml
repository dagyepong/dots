// components/Settings/PanelPositionSelector.qml
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components
import qs.commons

ColumnLayout {
  spacing: ScalerService.s(20)
  Layout.fillWidth: true
  CustomText {
    name: root.lang?.appearance?.panel_position || "Panel Position"
    isBold: true
  }
  GridLayout {
    columns: 2
    rowSpacing: ScalerService.s(15)
    columnSpacing: ScalerService.s(15)
    Layout.fillWidth: true

    // Top position
    Rectangle {
      id: topOption
      Layout.fillWidth: true
      Layout.preferredHeight: ScalerService.s(80)
      radius: ScalerService.s(10)
      color: theme.primary.dim_background
      border.color: Settings.bar.position === "top" ? theme.button.text : "transparent"
      border.width: ScalerService.s(2)

      ColumnLayout {
        anchors.centerIn: parent
        spacing: ScalerService.s(5)

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          width: ScalerService.s(60)
          height: ScalerService.s(10)
          radius: ScalerService.s(3)
          color: Settings.bar.position === "top" ? theme.button.text : theme.primary.dim_foreground
        }

        Text {
          text: root.lang?.appearance?.top || "Top"
          color: Settings.bar.position === "top" ? theme.button.text : theme.primary.foreground
          font {
            family: "ComicShannsMono Nerd Font"
            pixelSize: ScalerService.s(14)
          }
          Layout.alignment: Qt.AlignHCenter
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          Settings.bar.position = "top";
        }
        onEntered: parent.opacity = 0.9
        onExited: parent.opacity = 1.0
      }

      Behavior on opacity {
        NumberAnimation {
          duration: 100
        }
      }
    }

    // Bottom position
    Rectangle {
      id: bottomOption
      Layout.fillWidth: true
      Layout.preferredHeight: ScalerService.s(80)
      radius: ScalerService.s(10)
      color: theme.primary.dim_background
      border.color: Settings.bar.position === "bottom" ? theme.button.text : "transparent"
      border.width: ScalerService.s(2)

      ColumnLayout {
        anchors.centerIn: parent
        spacing: ScalerService.s(5)

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          width: ScalerService.s(60)
          height: ScalerService.s(10)
          radius: ScalerService.s(3)
          color: Settings.bar.position === "bottom" ? theme.button.text : theme.primary.dim_foreground
        }

        Text {
          text: root.lang?.appearance?.bottom || "Bottom"
          color: Settings.bar.position === "bottom" ? theme.button.text : theme.primary.foreground
          font {
            family: "ComicShannsMono Nerd Font"
            pixelSize: ScalerService.s(14)
          }
          Layout.alignment: Qt.AlignHCenter
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          Settings.bar.position = "bottom";
        }
        onEntered: parent.opacity = 0.9
        onExited: parent.opacity = 1.0
      }

      Behavior on opacity {
        NumberAnimation {
          duration: 100
        }
      }
    }

    // Left position
    Rectangle {
      id: leftOption
      Layout.fillWidth: true
      Layout.preferredHeight: ScalerService.s(80)
      radius: ScalerService.s(10)
      color: theme.primary.dim_background
      border.color: Settings.bar.position === "left" ? theme.button.text : "transparent"
      border.width: ScalerService.s(2)

      RowLayout {
        anchors.centerIn: parent
        spacing: ScalerService.s(10)

        Rectangle {
          Layout.alignment: Qt.AlignVCenter
          width: ScalerService.s(10)
          height: ScalerService.s(40)
          radius: ScalerService.s(3)
          color: Settings.bar.position === "left" ? theme.button.text : theme.primary.dim_foreground
        }

        Text {
          text: root.lang?.appearance?.left || "Left"
          color: Settings.bar.position === "left" ? theme.button.text : theme.primary.foreground
          font {
            family: "ComicShannsMono Nerd Font"
            pixelSize: ScalerService.s(14)
          }
          Layout.alignment: Qt.AlignVCenter
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          Settings.bar.position = "left";
        }
        onEntered: parent.opacity = 0.9
        onExited: parent.opacity = 1.0
      }

      Behavior on opacity {
        NumberAnimation {
          duration: 100
        }
      }
    }

    // Right position
    Rectangle {
      id: rightOption
      Layout.fillWidth: true
      Layout.preferredHeight: ScalerService.s(80)
      radius: ScalerService.s(10)
      color: theme.primary.dim_background
      border.color: Settings.bar.position === "right" ? theme.button.text : "transparent"
      border.width: ScalerService.s(2)

      RowLayout {
        anchors.centerIn: parent
        spacing: ScalerService.s(10)

        Text {
          text: root.lang?.appearance?.right || "Right"
          color: Settings.bar.position === "right" ? theme.button.text : theme.primary.foreground
          font {
            family: "ComicShannsMono Nerd Font"
            pixelSize: ScalerService.s(14)
          }
          Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
          Layout.alignment: Qt.AlignVCenter
          width: ScalerService.s(10)
          height: ScalerService.s(40)
          radius: ScalerService.s(3)
          color: Settings.bar.position === "right" ? theme.button.text : theme.primary.dim_foreground
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          Settings.bar.position = "right";
        }
        onEntered: parent.opacity = 0.9
        onExited: parent.opacity = 1.0
      }

      Behavior on opacity {
        NumberAnimation {
          duration: 100
        }
      }
    }
  }
}
