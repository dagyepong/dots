import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.bar
import qs.commons
import qs.services

PanelWindow {
  id: panel
  // Kích thước cố định cho mỗi hướng

  implicitWidth: (Settings.bar.position === "left" || Settings.bar.position === "right") ? ScalerService.s(40) : Screen.width
  implicitHeight: (Settings.bar.position === "top" || Settings.bar.position === "bottom") ? ScalerService.s(50) : Screen.height

  color: "transparent"

  anchors {
    left: (Settings.bar.position === "left" || Settings.bar.position === "top" || Settings.bar.position === "bottom") ? true : false
    right: (Settings.bar.position === "right" || Settings.bar.position === "top" || Settings.bar.position === "bottom") ? true : false
    top: (Settings.bar.position === "top" || Settings.bar.position === "left" || Settings.bar.position === "right") ? true : false
    bottom: (Settings.bar.position === "bottom" || Settings.bar.position === "left" || Settings.bar.position === "right") ? true : false
  }

  margins {
    top: (Settings.bar.position === "top" || Settings.bar.position === "left" || Settings.bar.position === "right") ? ScalerService.s(10) : 0
    left: (Settings.bar.position === "left" || Settings.bar.position === "top" || Settings.bar.position === "bottom") ? ScalerService.s(10) : 0
    right: (Settings.bar.position === "right" || Settings.bar.position === "top" || Settings.bar.position === "bottom") ? ScalerService.s(10) : 0
    bottom: (Settings.bar.position === "bottom" || Settings.bar.position === "left" || Settings.bar.position === "right") ? ScalerService.s(10) : 0
  }

  // Xác định layout dựa trên vị trí
  property bool isVertical: Settings.bar.position === "left" || Settings.bar.position === "right"

  Loader {
    anchors.fill: parent
    sourceComponent: isVertical ? verticalLayout : horizontalLayout
  }

  // Component cho layout ngang (top/bottom)
  Component {
    id: horizontalLayout

    RowLayout {
      id: horizontal
      property real animationProgress: 0
      SequentialAnimation on animationProgress {
        running: true
        NumberAnimation {
          from: 0
          to: 0.6
          duration: 100
          easing.type: Easing.Linear
        }
      }
      anchors.fill: parent
      Item {
        Layout.preferredWidth: ScalerService.s(60)
        Layout.fillHeight: true
        LauncherSection {
          animationProgress: horizontal.animationProgress
        }
      }

      Item {
        Layout.fillWidth: true
      }

      Item {
        Layout.preferredWidth: ScalerService.s(380)
        Layout.fillHeight: true
        WorkspaceSection {
          animationProgress: horizontal.animationProgress
        }
      }

      Item {
        Layout.fillWidth: true
      }
      Item {
        Layout.preferredWidth: ScalerService.s(340)
        Layout.fillHeight: true
        MediaSection {
          animationProgress: horizontal.animationProgress
        }
      }

      Item {
        Layout.fillWidth: true
      }

      Item {
        Layout.preferredWidth: ScalerService.s(400)
        Layout.fillHeight: true
        InfoSection {
          animationProgress: horizontal.animationProgress
        }
      }
      Item {
        Layout.fillWidth: true
      }
      Item {
        Layout.preferredWidth: ScalerService.s(200)
        Layout.fillHeight: true
        SystemStatsSection {
          animationProgress: horizontal.animationProgress
        }
      }

      Item {
        Layout.fillWidth: true
      }
      Item {
        Layout.preferredWidth: ScalerService.s(430)
        Layout.fillHeight: true
        StatusTraySection {
          animationProgress: horizontal.animationProgress
        }

      }

    }
  }

  // Component cho layout dọc (left/right)
  Component {
    id: verticalLayout

    ColumnLayout {
      id: vertical
      property real animationProgress: 0
      SequentialAnimation on animationProgress {
        running: true
        NumberAnimation {
          from: 0
          to: 0.6
          duration: 100
          easing.type: Easing.Linear
        }
      }
      anchors.fill: parent

      // Top spacer
      Item {
        Layout.fillHeight: true
      }

      // LauncherSection (top section)
      Item {
        Layout.preferredHeight: ScalerService.s(40)
        Layout.fillWidth: true
        LauncherSection {
          animationProgress: vertical.animationProgress
        }
      }

      // Spacer
      Item {
        Layout.fillHeight: true
      }

      // WorkspaceSection
      Item {
        Layout.preferredHeight: ScalerService.s(280)
        Layout.fillWidth: true
        WorkspaceSection {
          animationProgress: vertical.animationProgress
        }
      }

      // Spacer
      Item {
        Layout.fillHeight: true
      }

      // MediaSection
      Item {
        Layout.preferredHeight: ScalerService.s(180)
        Layout.fillWidth: true
        MediaSection {
          animationProgress: vertical.animationProgress
        }
      }

      // Spacer
      Item {
        Layout.fillHeight: true
      }

      // InfoSection
      Item {
        Layout.preferredHeight: ScalerService.s(180)
        Layout.fillWidth: true
        InfoSection {
          animationProgress: vertical.animationProgress
        }
      }

      // Spacer
      Item {
        Layout.fillHeight: true
      }

      // SystemStatsSection
      Item {
        Layout.preferredHeight: ScalerService.s(100)
        Layout.fillWidth: true
        SystemStatsSection {
          animationProgress: vertical.animationProgress
        }
      }

      // Spacer
      Item {
        Layout.fillHeight: true
      }

      // StatusTraySection (bottom section)
      Item {
        Layout.preferredHeight: ScalerService.s(230)
        Layout.fillWidth: true
        StatusTraySection {
          animationProgress: vertical.animationProgress
        }
      }

      // Bottom spacer
      Item {
        Layout.fillHeight: true
      }
    }
  }
}
