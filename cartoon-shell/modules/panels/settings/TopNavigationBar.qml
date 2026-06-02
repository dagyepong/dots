import QtQuick
import QtQuick.Layouts
import qs.services
import qs.components
import qs.commons

Rectangle {
  id: root
  property real animationProgress: 0
  property int indexCategoegory: 0
  signal currentTab(int index);
  property var listCategoegory : [
  {
    categoryName: "General",
    items: [
    {
      name: "Language & Region",
      icon: "settings/languages.png",
      category: "language"
    },
    {
      name: "Date & Time",
      icon: "settings/time.png",
      category: "datetime"
    },
    {
      name: "Startup",
      icon: "settings/startup.png",
      category: "session"
    },
    {
      name: "Behavior",
      icon: "settings/behavior.png",
      category: "behavior"
    },
    {
      name: "Notifications",
      icon: "settings/notification.png",
      category: "notifications"
    },
    {
      name: "Privacy",
      icon: "settings/privacy.png",
      category: "privacy"
    },
    ]
  },
  {
    categoryName: "Appearance",
    items: [
    {
      name: "Theme",
      icon: "settings/theme.png",
      category: "theme"
    },
    {
      name: "Panel",
      icon: "settings/layout.png",
      category: "panel"
    },
    {
      name: "Clock",
      icon: "settings/clock.png",
      category: "clock"
    },
    {
      name: "Fonts",
      icon: "settings/fonts.png",
      category: "fonts"
    },
    {
      name: "Icons",
      icon: "settings/icons.png",
      category: "icons"
    },
    {
      name: "Effects",
      icon: "settings/effects.png",
      category: "effects"
    },
    {
      name: "Layout",
      icon: "settings/layout.png",
      category: "layout"
    },
    {
      name: "Wallpaper",
      icon: "settings/Wallpaper.png",
      category: "wallpaper"
    }
    ]
  }
  ]

  Layout.fillWidth: true
  Layout.preferredHeight: ScalerService.s(50)
  opacity: root.animationProgress > 0.1 ? 1 : 0
  Behavior on opacity {
    NumberAnimation {
      duration: 200
    }
  }

  color: Qt.alpha(theme.button.background,0.6)
  radius: ScalerService.s(12)

  RowLayout {
    anchors.fill: parent
    anchors.margins: ScalerService.s(8)
    spacing: ScalerService.s(16)

    Item {
      Layout.fillWidth: true
    } // Spacer
    Repeater {
      model: root.listCategoegory[root.indexCategoegory].items

      delegate: Item {
        id: minimalDelegate
        Layout.fillHeight: true
        Layout.preferredWidth: ScalerService.s(42)

        property bool selected: root.currentTab === index

        // Hiệu ứng scale
        scale: mouseArea.containsPress ? 0.95 : 1.0
        Behavior on scale {
          NumberAnimation {
            duration: 100
          }
        }

        // Icon
        IconImage {
          anchors.centerIn: parent
          path: modelData.icon
          opacity: 0
          size: "large"
          SequentialAnimation on opacity {
            running: root.animationProgress > 0.4

            PauseAnimation {
              duration: index * 15
            }

            NumberAnimation {
              to: 1
              duration: 200
              easing.type: Easing.OutCubic
            }
          }

        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: {
            root.currentTab(index)
          }
        }
      }
    }

    Item {
      Layout.fillWidth: true
    } // Spacer
  }
}
