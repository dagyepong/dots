import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick.Controls
import Quickshell.Services.SystemTray
import qs.services
import qs.commons
import qs.components
import "./widget/" as Com

Rectangle {
  id: root
  border.color: theme.button.border
  border.width: Settings.appearance.enableBorder ? ScalerService.s(3) : 0
  radius: ScalerService.s(Settings.appearance.radius2)
  color: theme.primary.background
  anchors.centerIn: parent
  property real animationProgress: 0
  SequentialAnimation on animationProgress {
    running: true
    NumberAnimation {
      from: 0
      to: 1
      duration: 1000
      easing.type: Easing.Linear
    }
  }
  implicitWidth: root.animationProgress > 0.5 ? parent.width : 0
  implicitHeight: root.animationProgress > 0.5 ? parent.height : 0
  Behavior on implicitHeight {
    NumberAnimation {
      id: heightAnim
      duration: 500
      easing.type: Easing.OutCubic
    }
  }
  Behavior on implicitWidth {
    NumberAnimation {
      id: widthAnim
      duration: 500
      easing.type: Easing.OutCubic
    }
  }

  property string bluetooth_icon: Directories.assetsPath + "/settings/bluetooth.png"
  property real currentVolume: Pipewire.defaultAudioSink?.audio.volume ?? 0
  property bool isMuted: Pipewire.defaultAudioSink?.audio.mute ?? false
  property bool isVertical: Settings.bar.position === "left" || Settings.bar.position === "right"
  property bool shouldShowOsd: false

  // UPower battery display – using displayDevice (always available)
  property string batteryPercent: "…"
  property bool batteryCharging: false
  property string batteryIconSource: Directories.assetsPath + '/battery/full.png'
  property string batteryIconVerticalSource: Directories.assetsPath + '/battery/full.png'

  function refreshBatteryDisplay() {
    var dev = UPower.displayDevice;
    if (!dev || !dev.ready) return;
    root.batteryPercent = Math.round(dev.percentage * 100) + "%";
    root.batteryCharging = (dev.state === UPowerDeviceState.Charging);
    var icon = getBatteryIcon(Math.round(dev.percentage * 100));
    root.batteryIconSource = icon;
    root.batteryIconVerticalSource = icon;
  }

  function getBatteryIcon(percent) {
    if (root.batteryCharging) return Directories.assetsPath + '/battery/battery-1.png';
    if (percent <= 20) return Directories.assetsPath + '/battery/battery-2.png';
    if (percent <= 50) return Directories.assetsPath + '/battery/battery-3.png';
    if (percent <= 80) return Directories.assetsPath + '/battery/battery-3.png';
    return Directories.assetsPath + '/battery/full.png';
  }

  // Wait for displayDevice to become ready, then start listening
  Timer {
    id: initTimer
    interval: 500
    running: true
    repeat: true
    onTriggered: {
      if (UPower.displayDevice && UPower.displayDevice.ready) {
        stop();
        refreshBatteryDisplay();
      }
    }
  }

  Connections {
    target: UPower.displayDevice
    enabled: UPower.displayDevice && UPower.displayDevice.ready
    function onPercentageChanged() { refreshBatteryDisplay(); }
    function onStateChanged() { refreshBatteryDisplay(); }
  }

  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink]
  }

  Connections {
    target: Pipewire.defaultAudioSink?.audio ?? null
  }

  // UI Layout
  Loader {
    anchors.fill: parent
    anchors.margins: isVertical ? ScalerService.s(6) : ScalerService.s(5)
    sourceComponent: isVertical ? verticalLayout : horizontalLayout
  }

  Component {
    id: horizontalLayout

    RowLayout {
      anchors.fill: parent
      spacing: ScalerService.s(5)

      // System Tray Icons
      Repeater {
        id: trayRepeater
        model: SystemTray.items

        Rectangle {
          id: trayItemContainer
          Layout.preferredWidth: ScalerService.s(35)
          Layout.fillHeight: true
          color: "transparent"
          radius: ScalerService.s(6)
          transformOrigin: Item.Center

          visible: modelData.icon !== ""
          property var trayItem: modelData

          Image {
            id: trayIcon
            anchors.centerIn: parent
            width: ScalerService.s(25)
            height: ScalerService.s(25)
            source: trayItemContainer.trayItem?.icon || ""

            ToolTip {
              id: trayTooltip
              visible: trayTooltipArea.containsMouse && trayItemContainer.trayItem?.tooltipTitle
              text: trayItemContainer.trayItem?.tooltipTitle || ""
              delay: 1000
            }
          }

          MouseArea {
            id: trayTooltipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onEntered: trayItemContainer.scale = 1.1
            onExited: trayItemContainer.scale = 1.0
            onPressed: trayItemContainer.scale = 0.95
            onReleased: trayItemContainer.scale = containsMouse ? 1.1 : 1.0

            onClicked: function (mouse) {
              if (!trayItemContainer.trayItem)
              return;
              if (mouse.button === Qt.LeftButton) {
                trayItemContainer.trayItem.activate();
              } else if (mouse.button === Qt.RightButton) {
                if (trayItemContainer.trayItem.hasMenu && trayItemContainer.trayItem.menu) {
                  trayItemContainer.trayItem.display(root, mouse.x, mouse.y);
                }
              } else if (mouse.button === Qt.MiddleButton) {
                trayItemContainer.trayItem.secondaryActivate();
              }
            }

            onWheel: function (wheel) {
              if (!trayItemContainer.trayItem)
              return;
              trayItemContainer.trayItem.scroll(wheel.angleDelta.y, wheel.angleDelta.x !== 0);
            }
          }

          Behavior on scale {
            NumberAnimation {
              duration: 100
              easing.type: Easing.OutCubic
            }
          }
        }
      }

      Item {
        Layout.preferredWidth: trayRepeater.count > 0 ? ScalerService.s(5) : 0
      }

      // Bluetooth
      Com.StatContainer {
        Layout.fillWidth: true
        Layout.fillHeight: true
        panelName: "bluetooth"

        Com.BluetoothStat {
          anchors.centerIn: parent
        }
      }

      Item {
        Layout.fillWidth: true
      }

      Com.StatContainer {
        Layout.fillWidth: true
        Layout.fillHeight: true
        panelName: "wifi"

        Com.WifiStat {
          anchors.centerIn: parent
        }
      }

      Item {
        Layout.fillWidth: true
      }

      // Volume
      Com.StatContainer {
        Layout.fillWidth: true
        Layout.fillHeight: true
        panelName: "mixer"

        Com.VolumeStat {
          anchors.centerIn: parent
        }
      }

      Item {
        Layout.fillWidth: true
      }

      // Battery (UPower displayDevice)
      Rectangle {
        id: batteryContainer
        Layout.preferredWidth: batteryContent.width
        Layout.fillHeight: true
        color: "transparent"
        radius: ScalerService.s(6)
        transformOrigin: Item.Center

        RowLayout {
          id: batteryContent
          anchors.centerIn: parent
          spacing: ScalerService.s(8)

          Image {
            id: batteryIcon
            source: root.batteryIconSource
            width: ScalerService.s(30)
            height: ScalerService.s(30)
            sourceSize: Qt.size(ScalerService.s(30), ScalerService.s(30))
          }

          // Battery percentage text (bold)
          Text {
            text: root.batteryPercent
            color: theme.primary.foreground
            font.pixelSize: ScalerService.s(13)
            font.bold: true
            verticalAlignment: Text.AlignVCenter
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: batteryContainer.scale = 1.1
          onExited: batteryContainer.scale = 1.0
          onPressed: batteryContainer.scale = 0.95
          onReleased: batteryContainer.scale = 1.1
          onClicked: VisibleService.togglePanel("battery")
        }

        Behavior on scale {
          NumberAnimation {
            duration: 100
          }
        }
      }

      Item {
        Layout.fillWidth: true
      }

      // Power Off
      Rectangle {
        id: powerContainer
        Layout.preferredWidth: powerIcon.width
        Layout.fillHeight: true
        color: "transparent"
        radius: ScalerService.s(6)
        transformOrigin: Item.Center

        Image {
          id: powerIcon
          source: Directories.assetsPath + '/system/poweroff.png'
          width: ScalerService.s(30)
          height: ScalerService.s(30)
          sourceSize: Qt.size(ScalerService.s(30), ScalerService.s(30))
          anchors.centerIn: parent
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onEntered: powerContainer.scale = 1.2
          onExited: powerContainer.scale = 1.0
          onPressed: powerContainer.scale = 0.9
          onReleased: powerContainer.scale = 1.2

          onClicked: VisibleService.togglePanel("dashboard")
        }

        Behavior on scale {
          NumberAnimation {
            duration: 100
          }
        }
      }
    }
  }

  Component {
    id: verticalLayout

    ColumnLayout {
      anchors.fill: parent
      spacing: ScalerService.s(8)

      // System Tray Icons (vertical)
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: contentVerticalTray.height

        Item {
          anchors.centerIn: parent
          width: parent.height
          height: parent.width
          transformOrigin: Item.Center

          ColumnLayout {
            id: contentVerticalTray
            anchors.centerIn: parent
            spacing: ScalerService.s(4)

            Repeater {
              model: SystemTray.items

              Rectangle {
                id: trayItemContainerVertical
                Layout.preferredWidth: ScalerService.s(25)
                Layout.preferredHeight: ScalerService.s(25)
                color: "transparent"
                radius: ScalerService.s(4)

                visible: modelData.icon !== ""
                property var trayItem: modelData

                Image {
                  anchors.centerIn: parent
                  width: ScalerService.s(20)
                  height: ScalerService.s(20)
                  source: trayItemContainerVertical.trayItem?.icon || ""
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor

                  onEntered: trayItemContainerVertical.scale = 1.1
                  onExited: trayItemContainerVertical.scale = 1.0
                  onClicked: function (mouse) {
                    if (!trayItemContainerVertical.trayItem)
                    return;
                    if (mouse.button === Qt.LeftButton) {
                      trayItemContainerVertical.trayItem.activate();
                    }
                  }
                }

                Behavior on scale {
                  NumberAnimation {
                    duration: 100
                  }
                }
              }
            }
          }
        }
      }

      // Bluetooth (vertical)
      Com.StatContainer {
        Layout.fillWidth: true
        Layout.fillHeight: true
        panelName: "bluetooth"

        Com.BluetoothStat {
          anchors.centerIn: parent
        }
      }

      Item {
        Layout.fillWidth: true
      }

      Com.StatContainer {
        Layout.fillWidth: true
        Layout.fillHeight: true
        panelName: "wifi"

        Com.WifiStat {
          anchors.centerIn: parent
        }
      }

      Item {
        Layout.fillWidth: true
      }

      // Volume (vertical)
      Com.StatContainer {
        Layout.fillWidth: true
        Layout.fillHeight: true
        panelName: "mixer"

        Com.VolumeStat {
          anchors.centerIn: parent
        }
      }

      // Battery (vertical, UPower displayDevice)
      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: ScalerService.s(50)

        Item {
          anchors.centerIn: parent
          width: parent.height
          height: parent.width
          transformOrigin: Item.Center

          ColumnLayout {
            anchors.centerIn: parent
            spacing: ScalerService.s(2)

            Image {
              id: batteryIconVertical
              source: root.batteryIconVerticalSource
              width: ScalerService.s(25)
              height: ScalerService.s(25)
              sourceSize: Qt.size(ScalerService.s(25), ScalerService.s(25))
              Layout.alignment: Qt.AlignHCenter
            }

            // Battery percentage text (bold)
            Text {
              text: root.batteryPercent
              color: theme.primary.foreground
              font.pixelSize: ScalerService.s(10)
              font.bold: true
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: VisibleService.togglePanel("battery")
          onEntered: parent.opacity = 0.8
          onExited: parent.opacity = 1.0
        }

        Behavior on opacity {
          NumberAnimation {
            duration: 100
          }
        }
      }

      // Power (vertical)
      Item {
        width: ScalerService.s(25)
        height: ScalerService.s(25)

        Item {
          anchors.centerIn: parent
          width: parent.height
          height: parent.width
          transformOrigin: Item.Center

          Image {
            id: powerIconVertical
            anchors.centerIn: parent
            source: Directories.assetsPath + '/system/poweroff.png'
            width: ScalerService.s(25)
            height: ScalerService.s(25)
            sourceSize: Qt.size(ScalerService.s(25), ScalerService.s(25))
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: VisibleService.togglePanel("dashboard")
          onEntered: parent.opacity = 0.8
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
}