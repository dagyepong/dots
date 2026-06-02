import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components
import "./appearance" as Com
import "./" as Bar

Item {
  id: root

  property int currentTab: 0
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

  ColumnLayout {
    anchors.fill: parent
    spacing: ScalerService.s(10)
    Bar.TopNavigationBar{
      animationProgress: root.animationProgress
      indexCategoegory: 1
      onCurrentTab: function(index) {
        root.currentTab = index
      }
    }

    StackLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      currentIndex: root.currentTab

      Loader {
        active: root.currentTab === 0
        source: "./appearance/Theme.qml"
        onLoaded: {
          item.visible = Qt.binding(function () {
              return root.currentTab === 0;
          });
        }
      }
      Loader {
        active: root.currentTab === 1
        source: "./appearance/Panel.qml"
        onLoaded: {
          item.visible = Qt.binding(function () {
              return root.currentTab === 1;
          });
        }
      }

      Loader {
        active: root.currentTab === 2
        source: "./appearance/ClockTime.qml"
        onLoaded: {
          item.visible = Qt.binding(function () {
              return root.currentTab === 2;
          });
        }
      }

      // Tab 3: Fonts
      Loader {
        active: root.currentTab === 3
        source: "./appearance/Fonts.qml"
        onLoaded: {
          item.visible = Qt.binding(function () {
              return root.currentTab === 3;
          });
        }
      }

      // Tab 4: Icons
      ColumnLayout {
        width: parent.width
        spacing: ScalerService.s(20)

        Text {
          text: lang?.appearance?.icons || "Icons"
          color: theme.primary.foreground
          font {
            family: "ComicShannsMono Nerd Font"
            pixelSize: ScalerService.s(24)
            bold: true
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: ScalerService.s(1)
          color: theme.primary.foreground
          opacity: 0.3
        }

        // Icons settings content
        Text {
          text: "Icons settings content"
          color: theme.primary.foreground
          font.pixelSize: ScalerService.s(14)
        }
      }

      // Tab 5: Effects
      ColumnLayout {
        width: parent.width
        spacing: ScalerService.s(20)

        Text {
          text: lang?.appearance?.effects || "Effects"
          color: theme.primary.foreground
          font {
            family: "ComicShannsMono Nerd Font"
            pixelSize: ScalerService.s(24)
            bold: true
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: ScalerService.s(1)
          color: theme.primary.foreground
          opacity: 0.3
        }

        // Effects settings content
        Text {
          text: "Effects settings content"
          color: theme.primary.foreground
          font.pixelSize: ScalerService.s(14)
        }
      }

      // Tab 6: Dashboard
      ColumnLayout {
        width: parent.width
        spacing: ScalerService.s(20)

        Text {
          text: lang?.appearance?.layout || "Layout"
          color: theme.primary.foreground
          font {
            family: "ComicShannsMono Nerd Font"
            pixelSize: ScalerService.s(24)
            bold: true
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: ScalerService.s(1)
          color: theme.primary.foreground
          opacity: 0.3
        }

        // Layout settings content
        Text {
          text: "Layout settings content"
          color: theme.primary.foreground
          font.pixelSize: ScalerService.s(14)
        }
      }

      // Tab 7: Wallpaper
      Com.Wallpapers {
        Layout.fillWidth: true
        Layout.fillHeight: true
      }

      // Tab 8: Advanced (nếu cần)
      ColumnLayout {
        width: parent.width
        spacing: ScalerService.s(20)

        Text {
          text: "Advanced"
          color: theme.primary.foreground
          font {
            family: "ComicShannsMono Nerd Font"
            pixelSize: ScalerService.s(24)
            bold: true
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: ScalerService.s(1)
          color: theme.primary.foreground
          opacity: 0.3
        }

        // Advanced settings content
        Text {
          text: "Advanced settings content"
          color: theme.primary.foreground
          font.pixelSize: ScalerService.s(14)
        }
      }
    }
  }
}
