// ~/.config/quickshell/modules/bar/Bar.qml
// ┌───────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░░░░░░█▀▄░█▀█░█▀▄░░░░░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░░░░░█▀▄░█▀█░█▀▄░░░░░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░░░░░▀▀░░▀░▀░▀░▀░░░░░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀───────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>      ├┤
// ││ Repo    : https://github.com/roosta/dotfiles││
// ││ Site    : https://www.roosta.sh             ││
// ├┤ License : GNU General Public License v3      ├┤
// ┆└─────────────────────────────────────────────┘┆

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.config
pragma ComponentBehavior: Bound

Item {
  id: root
  required property string monitorId

  z: 1
  implicitHeight: Appearance.bar.height

  anchors {
    bottom: parent.bottom
    left: parent.left
    right: parent.right
  }

  BorderRect {
    id: barContent
    color: Appearance.srcery.black
    borderColor: Appearance.srcery.gray3
    topBorder: 1
    anchors {
      right: parent.right
      left: parent.left
      top: parent.top
      bottom: parent.bottom
    }
    Rectangle {
      anchors.fill: parent
      color: "transparent"

      Loader {
        id: barLoader
        anchors.fill: parent
        sourceComponent: {
          if (root.monitorId === Config.displays?.left) {
            return leftBar
          } else if (root.monitorId === Config.displays?.right){
            return rightBar
          } else if (root.monitorId === Config.displays?.top){
            return topBar
          } else {
            return primaryBar
          }
        }
      }
    }
  }

  // --- PRIMARY DISPLAY BAR ---
  Component {
    id: primaryBar
    Rectangle {
      color: "transparent"
      anchors.fill: parent

      RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
          id: leftSection
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: "transparent"
          RowLayout {
            spacing: Appearance.spacing.p1
            anchors.left: parent.left
            anchors.leftMargin: Appearance.spacing.p1
            anchors.fill: parent
            AlertsIndicator { monitorId: root.monitorId }
            KeyboardButton { monitorId: root.monitorId }
            Loader {
              Layout.fillHeight: true
              Layout.fillWidth: true
              active: LauncherData.appsData.length > 0
              sourceComponent: Context { }
            }
          }
        }
        Rectangle {
          id: centerSection
          color: "transparent"
          Layout.fillHeight: true
          Layout.fillWidth: true
          RowLayout {
            spacing: Appearance.spacing.p1
            anchors.centerIn: parent
            LauncherButton { monitorId: root.monitorId }
            Workspaces { monitorId: root.monitorId }
            NotificationButton { monitorId: root.monitorId }
          }
        }
        Rectangle {
          id: rightSection
          Layout.fillHeight: true
          Layout.fillWidth: true
          color: "transparent"
          RowLayout {
            spacing: Appearance.spacing.p1
            anchors.right: parent.right
            anchors.rightMargin: Appearance.spacing.p1
            Clock { }
            TrayButton { monitorId: root.monitorId }
            AudioButton { monitorId: root.monitorId }
            Battery { monitorId: root.monitorId }
          }
        }
      }
    }
  }

  // --- RIGHT MONITOR DISPLAY BAR ---
  Component {
    id: rightBar
    Rectangle {
      color: "transparent"
      RowLayout {
        anchors.fill: parent
        
        RowLayout {
          id: leftSecRightBar
          spacing: Appearance.spacing.p1
          Layout.leftMargin: Appearance.spacing.p1
          LauncherButton { monitorId: root.monitorId }
          Workspaces { monitorId: root.monitorId }
        }
        
        Item { Layout.fillWidth: true } // Clean spacer pusher

        RowLayout {
          id: rightSecRightBar
          spacing: Appearance.spacing.p1
          Layout.rightMargin: Appearance.spacing.p1
          Layout.alignment: Qt.AlignVCenter
          Battery { monitorId: root.monitorId }
        }
      }
    }
  }

  // --- LEFT MONITOR DISPLAY BAR ---
  Component {
    id: leftBar
    Rectangle {
      color: "transparent"
      RowLayout {
        anchors.fill: parent
        
        RowLayout {
          id: leftSecLeftBar
          Layout.fillHeight: true
        }
        
        Item { Layout.fillWidth: true } // Clean spacer pusher

        RowLayout {
          id: rightSecLeftBar
          spacing: Appearance.spacing.p1
          Layout.rightMargin: Appearance.spacing.p1
          Layout.alignment: Qt.AlignVCenter
          Workspaces { monitorId: root.monitorId }
          LauncherButton { monitorId: root.monitorId }
          Battery { monitorId: root.monitorId }
        }
      }
    }
  }

  // --- TOP MONITOR DISPLAY BAR ---
  Component {
    id: topBar
    Rectangle {
      color: "transparent"
      anchors.fill: parent
      RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
          id: leftSecTopBar
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: "transparent"
        }
        Rectangle {
          id: centerSecTopBar
          color: "transparent"
          Layout.fillHeight: true
          Layout.fillWidth: true
          RowLayout {
            spacing: Appearance.spacing.p1
            anchors.centerIn: parent
            Workspaces { monitorId: root.monitorId }
            Battery { monitorId: root.monitorId }
          }
        }
        Rectangle {
          id: rightSecTopBar
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: "transparent"
        }
      }
    }
  }
}
