import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Io
import Quickshell
import qs.services

Item {
  id: root
  width: ScalerService.s(320)
  height: ScalerService.s(400)

  // Catppuccin Mocha color scheme
  property color batteryHighColor: theme.normal.green       // "#a6da95"
  property color batteryMediumColor: theme.normal.yellow    // "#eed49f"
  property color batteryLowColor: theme.normal.red          // "#ed8796"
  property color batteryBackgroundColor: theme.normal.black // "#494d64"
  property color textColor: theme.primary.foreground        // "#cad3f5"
  property color dimTextColor: theme.primary.dim_foreground // "#8087a2"
  property color borderColor: theme.bright.black            // "#5b6078"
  property color separatorColor: theme.normal.black         // "#494d64"

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

  property int batteryPercent: 0
  property string batteryStatus: "Discharging"
  property int updateInterval: 2000

  // Thông tin chi tiết từ script
  property int capacity: 0
  property int energy_mWh: 0
  property int energy_full_mWh: 0
  property int power_mW: 0
  property int voltage_V: 0
  property int current_mA: 0

  // Biến cho animation
  property bool dataLoaded: false

  Timer {
    interval: updateInterval
    running: true
    repeat: true
    onTriggered: batteryFetcher.running = true
  }

  Process {
    id: batteryFetcher
    running: false
    stdout: StdioCollector {
      id: outputCollector
    }

    command: [Qt.resolvedUrl("../../../scripts/battery_monitor.sh")]

    onExited: {
      try {
        var txt = outputCollector.text ? outputCollector.text.trim() : "";
        if (txt !== "") {
          const data = JSON.parse(txt);
          root.batteryPercent = data.capacity;
          root.batteryStatus = data.status;

          // Lấy thông tin chi tiết
          root.capacity = data.capacity;
          root.energy_mWh = data.energy_mWh;
          root.energy_full_mWh = data.energy_full_mWh;
          root.power_mW = data.power_mW;
          root.voltage_V = data.voltage_V;
          root.current_mA = data.current_mA;

          root.dataLoaded = true;
        } else {}
      } catch (e) {}
    }
  }

  Rectangle {
    anchors.centerIn: parent
    implicitWidth: root.animationProgress > 0 ? parent.width : 0
    implicitHeight: root.animationProgress > 0 ? parent.height : 0
    Behavior on implicitHeight {
      NumberAnimation {
        duration: 500
        easing.type: Easing.OutCubic
      }
    }
    Behavior on implicitWidth {
      NumberAnimation {
        duration: 500
        easing.type: Easing.OutCubic
      }
    }
    color: theme.primary.background
    border.color: borderColor
    radius: ScalerService.s(Settings.appearance.radius1)
    border.width: Settings.appearance.enableBorder ? ScalerService.s(3) : 0

    // Background pattern nhẹ
    Rectangle {
      anchors.fill: parent
      color: "transparent"
      opacity: 0.1
      radius: ScalerService.s(12)

      Canvas {
        anchors.fill: parent
        onPaint: {
          var ctx = getContext("2d");
          ctx.strokeStyle = theme.primary.foreground;
          ctx.lineWidth = 0.5;

          // Vẽ grid pattern nhẹ
          for (var x = 0; x < width; x += ScalerService.s(15)) {
            ctx.beginPath();
            ctx.moveTo(x, 0);
            ctx.lineTo(x, height);
            ctx.stroke();
          }
          for (var y = 0; y < height; y += ScalerService.s(15)) {
            ctx.beginPath();
            ctx.moveTo(0, y);
            ctx.lineTo(width, y);
            ctx.stroke();
          }
        }
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: ScalerService.s(16)
    spacing: ScalerService.s(16)

    // Header với icon
    RowLayout {
      Layout.fillWidth: true

      Text {
        text: "🔋 Battery Monitor"
        font.family: "ComicShannsMono Nerd Font"
        color: textColor
        font.bold: true
        font.pointSize: ScalerService.s(14)
      }

      Item {
        Layout.fillWidth: true
      }

      // Status indicator
      Rectangle {
        width: ScalerService.s(8)
        height: ScalerService.s(8)
        radius: ScalerService.s(4)
        color: getBatteryStatusColor()
      }
    }

    // Battery Level Section
    ColumnLayout {
      Layout.fillWidth: true
      spacing: ScalerService.s(8)

      // Battery icon và phần trăm
      RowLayout {
        Layout.fillWidth: true
        spacing: ScalerService.s(12)

        // Battery icon
        Rectangle {
          Layout.preferredWidth: ScalerService.s(40)
          Layout.preferredHeight: ScalerService.s(20)
          radius: ScalerService.s(3)
          border.color: textColor
          border.width: ScalerService.s(2)
          color: "transparent"

          // Battery tip
          Rectangle {
            x: parent.width + ScalerService.s(1)
            y: parent.height / 2 - ScalerService.s(3)
            width: ScalerService.s(4)
            height: ScalerService.s(6)
            radius: ScalerService.s(1)
            color: textColor
          }

          // Battery level fill
          Rectangle {
            anchors {
              left: parent.left
              top: parent.top
              bottom: parent.bottom
              margins: ScalerService.s(2)
            }
            width: (parent.width - ScalerService.s(4)) * (batteryPercent / 100)
            radius: ScalerService.s(1)
            color: getBatteryColor()
            Behavior on width {
              NumberAnimation {
                duration: 800
                easing.type: Easing.OutCubic
              }
            }
          }

          // Charging bolt icon
          Text {
            anchors.centerIn: parent
            text: batteryStatus === "Charging" ? "⚡" : ""
            color: theme.primary.background
            font.pointSize: ScalerService.s(10)
            visible: batteryStatus === "Charging"
          }
        }

        // Percentage và status
        ColumnLayout {
          spacing: ScalerService.s(2)

          Text {
            text: batteryPercent + "%"
            color: getBatteryColor()
            font.bold: true
            font.pointSize: ScalerService.s(16)
          }

          Text {
            text: getStatusText()
            color: dimTextColor
            font.pointSize: ScalerService.s(10)
          }
        }

        Item {
          Layout.fillWidth: true
        }

        // Time estimate
        Text {
          text: getTimeEstimate()
          color: dimTextColor
          font.pointSize: ScalerService.s(10)
          Layout.alignment: Qt.AlignRight
        }
      }

      // Progress bar
      Rectangle {
        Layout.fillWidth: true
        height: ScalerService.s(12)
        radius: ScalerService.s(6)
        color: batteryBackgroundColor

        Rectangle {
          width: parent.width * (batteryPercent / 100)
          height: parent.height
          radius: ScalerService.s(6)
          gradient: Gradient {
            GradientStop {
              position: 0.0
              color: Qt.lighter(getBatteryColor(), 1.3)
            }
            GradientStop {
              position: 1.0
              color: getBatteryColor()
            }
          }
          Behavior on width {
            NumberAnimation {
              duration: 800
              easing.type: Easing.OutCubic
            }
          }
        }
      }
    }

    // Separator
    Rectangle {
      Layout.fillWidth: true
      height: ScalerService.s(1)
      color: "transparent"

      Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: ScalerService.s(1)
        gradient: Gradient {
          GradientStop {
            position: 0.0
            color: "transparent"
          }
          GradientStop {
            position: 0.2
            color: separatorColor
          }
          GradientStop {
            position: 0.8
            color: separatorColor
          }
          GradientStop {
            position: 1.0
            color: "transparent"
          }
        }
      }
    }

    // Battery Details Section
    GridLayout {
      Layout.fillWidth: true
      columns: 2
      rowSpacing: ScalerService.s(6)
      columnSpacing: ScalerService.s(12)

      // Energy
      Text {
        text: "Energy:"
        color: dimTextColor
        font.pointSize: ScalerService.s(9)
      }
      Text {
        text: (energy_mWh / 1000).toFixed(2) + " / " + (energy_full_mWh / 1000).toFixed(2) + " Wh"
        color: textColor
        font.pointSize: ScalerService.s(9)
        font.bold: true
      }

      // Power
      Text {
        text: "Power:"
        color: dimTextColor
        font.pointSize: ScalerService.s(9)
      }
      Text {
        text: (power_mW / 1000).toFixed(2) + " W"
        color: power_mW > 0 ? theme.normal.yellow : theme.normal.green
        font.pointSize: ScalerService.s(9)
        font.bold: true
      }

      // Voltage & Current
      Text {
        text: "Voltage:"
        color: dimTextColor
        font.pointSize: ScalerService.s(9)
      }
      Text {
        text: voltage_V + " V"
        color: textColor
        font.pointSize: ScalerService.s(9)
        font.bold: true
      }

      Text {
        text: "Current:"
        color: dimTextColor
        font.pointSize: ScalerService.s(9)
      }
      Text {
        text: Math.abs(current_mA) + " mA"
        color: textColor
        font.pointSize: ScalerService.s(9)
        font.bold: true
      }

      // Status
      Text {
        text: "Status:"
        color: dimTextColor
        font.pointSize: ScalerService.s(9)
      }
      Text {
        text: batteryStatus
        color: getBatteryStatusColor()
        font.pointSize: ScalerService.s(9)
        font.bold: true
      }
    }
  }

  // Loading animation
  Rectangle {
    anchors.fill: parent
    color: theme.primary.background
    radius: ScalerService.s(12)
    opacity: dataLoaded ? 0 : 1
    visible: opacity > 0

    Behavior on opacity {
      NumberAnimation {
        duration: 300
      }
    }

    Column {
      anchors.centerIn: parent
      spacing: ScalerService.s(12)

      Text {
        text: "🔋"
        font.pointSize: ScalerService.s(20)
        color: dimTextColor
        anchors.horizontalCenter: parent.horizontalCenter
      }

      Text {
        text: "Loading battery data..."
        color: dimTextColor
        font.pointSize: ScalerService.s(10)
        anchors.horizontalCenter: parent.horizontalCenter
      }
    }
  }

  // Helper functions
  function getBatteryColor() {
    if (batteryPercent > 60)
    return batteryHighColor;
    if (batteryPercent > 20)
    return batteryMediumColor;
    return batteryLowColor;
  }

  function getBatteryStatusColor() {
    switch (batteryStatus) {
      case "Charging":
      return theme.normal.green;
      case "Discharging":
      return getBatteryColor();
      case "Full":
      return theme.normal.cyan;
      default:
      return theme.normal.white;
    }
  }

  function getStatusText() {
    switch (batteryStatus) {
      case "Charging":
      return "Charging";
      case "Discharging":
      return "Discharging";
      case "Full":
      return "Full";
      default:
      return batteryStatus;
    }
  }

  function getTimeEstimate() {
    if (batteryStatus === "Charging" && power_mW > 0) {
      var remainingEnergy = (energy_full_mWh - energy_mWh) / 1000; // Wh
      var hours = remainingEnergy / (power_mW / 1000);
      return "~" + Math.ceil(hours) + "h to full";
    } else if (batteryStatus === "Discharging" && power_mW > 0) {
      var remainingHours = (energy_mWh / 1000) / (power_mW / 1000);
      return "~" + Math.ceil(remainingHours) + "h remaining";
    }
    return "";
  }

  Component.onCompleted: batteryFetcher.running = true
}
