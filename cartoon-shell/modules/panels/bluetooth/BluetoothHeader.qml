// Header component for Bluetooth panel
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.commons

Rectangle {
  id: header
  required property var adapter
  required property bool isDiscovering

  signal scanClicked

  Layout.fillWidth: true
  height: ScalerService.s(100)
  radius: ScalerService.s(12)
  color: theme.primary.background

  RowLayout {
    anchors.fill: parent
    anchors.margins: ScalerService.s(12)
    spacing: ScalerService.s(12)

    // Bluetooth icon
    Rectangle {
      width: ScalerService.s(64)
      height: ScalerService.s(64)
      radius: ScalerService.s(20)
      color: theme.primary.background

      Image {
        source: Directories.assetsPath + "/settings/bluetooth.png"
        width: ScalerService.s(64)
        height: ScalerService.s(64)
        sourceSize: Qt.size(ScalerService.s(64), ScalerService.s(64))
        anchors.centerIn: parent
      }
    }

    // Title
    ColumnLayout {
      spacing: ScalerService.s(4)
      Layout.fillWidth: true

      Text {
        text: "Bluetooth"
        color: theme.primary.foreground
        font.pixelSize: ScalerService.s(40)
        font.family: "ComicShannsMono Nerd Font"
        font.weight: Font.Bold
      }
    }

    Item {
      Layout.fillWidth: true
    }

    // Scan button
    Rectangle {
      id: scanButton
      Layout.preferredWidth: ScalerService.s(55)
      Layout.preferredHeight: ScalerService.s(55)
      radius: ScalerService.s(28)
      visible: adapter?.enabled || false
      color: {
        if (isDiscovering)
        return theme.normal.red;
        if (scanButtonMouse.containsMouse)
        return theme.normal.blue;
        return theme.primary.dim_foreground;
      }

      scale: scanButtonMouse.containsPress ? 0.95 : (scanButtonMouse.containsMouse ? 1.1 : 1.0)
      Behavior on scale {
        NumberAnimation {
          duration: 200
          easing.type: Easing.OutCubic
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: 200
        }
      }

      Image {
        source: Directories.assetsPath + "/launcher/search.png"
        width: ScalerService.s(40)
        height: ScalerService.s(40)
        sourceSize: Qt.size(ScalerService.s(40), ScalerService.s(40))
        anchors.centerIn: parent
      }

      // Scanning animation
      Rectangle {
        anchors.fill: parent
        radius: ScalerService.s(28)
        color: "transparent"
        border.width: ScalerService.s(2)
        border.color: theme.normal.green
        visible: isDiscovering
        rotation: scanRotation

        RotationAnimator on rotation {
          id: scanRotation
          from: 0
          to: 360
          duration: 1000
          loops: Animation.Infinite
          running: isDiscovering
        }

        Rectangle {
          width: ScalerService.s(4)
          height: ScalerService.s(4)
          radius: ScalerService.s(2)
          color: theme.normal.green
          anchors.top: parent.top
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.topMargin: ScalerService.s(-2)
        }
      }

      MouseArea {
        id: scanButtonMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: header.scanClicked()
      }
    }
  }
}
