// components/Settings/ShortcutsSettings.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services

Item {
  ScrollView {
    anchors.fill: parent
    anchors.margins: ScalerService.s(20)
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    ColumnLayout {
      width: parent.parent.width - ScalerService.s(40)
      spacing: ScalerService.s(20)

      // Header
      Text {
        text: "⌨️ Hyprland Shortcuts"
        color: theme.primary.foreground
        font {
          family: "ComicShannsMono Nerd Font"
          pixelSize: ScalerService.s(24)
          bold: true
        }
        Layout.topMargin: ScalerService.s(10)
      }

      Rectangle {
        Layout.fillWidth: true
        height: ScalerService.s(1)
        color: theme.primary.foreground
      }

      // Basic Window Management
      ShortcutCategory {
        title: "🪟 Basic Window Management"
        shortcuts: [
        {
          key: "SUPER + RETURN",
          action: "Open Terminal"
        },
        {
          key: "SUPER + Q",
          action: "Close Window"
        },
        {
          key: "SUPER + M",
          action: "Exit Hyprland"
        },
        {
          key: "SUPER + E",
          action: "File Manager"
        },
        {
          key: "SUPER + SPACE",
          action: "Toggle Launcher Panel"
        },
        {
          key: "SUPER + V",
          action: "Toggle Floating"
        },
        {
          key: "SUPER + F",
          action: "Fullscreen"
        },
        {
          key: "SUPER + P",
          action: "Pseudo Tiling"
        },
        {
          key: "SUPER + J",
          action: "Toggle Split"
        }
        ]
      }

      // Window Focus
      ShortcutCategory {
        title: "🎯 Window Focus"
        shortcuts: [
        {
          key: "SUPER + ←",
          action: "Focus Left"
        },
        {
          key: "SUPER + →",
          action: "Focus Right"
        },
        {
          key: "SUPER + ↑",
          action: "Focus Up"
        },
        {
          key: "SUPER + ↓",
          action: "Focus Down"
        }
        ]
      }

      // Workspace Management
      ShortcutCategory {
        title: "🎨 Workspace Management"
        shortcuts: [
        {
          key: "SUPER + 1-0",
          action: "Switch to Workspace 1-10"
        },
        {
          key: "SUPER + SHIFT + 1-0",
          action: "Move Window to Workspace"
        },
        {
          key: "SUPER + S",
          action: "Toggle Special Workspace"
        },
        {
          key: "SUPER + SHIFT + S",
          action: "Move to Special Workspace"
        }
        ]
      }

      // Mouse Actions
      ShortcutCategory {
        title: "🖱️ Mouse Actions"
        shortcuts: [
        {
          key: "SUPER + Scroll Up",
          action: "Previous Workspace"
        },
        {
          key: "SUPER + Scroll Down",
          action: "Next Workspace"
        },
        {
          key: "SUPER + Left Drag",
          action: "Move Window"
        },
        {
          key: "SUPER + Right Drag",
          action: "Resize Window"
        }
        ]
      }

      // Media Control
      ShortcutCategory {
        title: "🎵 Media Control"
        shortcuts: [
        {
          key: "XF86AudioPlay",
          action: "Play/Pause"
        },
        {
          key: "XF86AudioPause",
          action: "Play/Pause"
        },
        {
          key: "XF86AudioNext",
          action: "Next Track"
        },
        {
          key: "XF86AudioPrev",
          action: "Previous Track"
        },
        {
          key: "XF86AudioRaiseVolume",
          action: "Volume Up +5%"
        },
        {
          key: "XF86AudioLowerVolume",
          action: "Volume Down -5%"
        },
        {
          key: "XF86AudioMute",
          action: "Toggle Mute"
        },
        {
          key: "XF86AudioMicMute",
          action: "Toggle Mic Mute"
        }
        ]
      }

      // Brightness
      ShortcutCategory {
        title: "💡 Display Brightness"
        shortcuts: [
        {
          key: "XF86MonBrightnessUp",
          action: "Brightness Up +5%"
        },
        {
          key: "XF86MonBrightnessDown",
          action: "Brightness Down -5%"
        }
        ]
      }

      // Screenshot
      ShortcutCategory {
        title: "📸 Screenshots"
        shortcuts: [
        {
          key: "PrintScreen",
          action: "Fullscreen Screenshot"
        },
        {
          key: "SUPER + PrintScreen",
          action: "Area Screenshot (Select region)"
        }
        ]
      }

      Item {
        Layout.fillHeight: true
      } // Spacer
    }
  }

  // Shortcut Category Component
  component ShortcutCategory: ColumnLayout {
    property string title: ""
    property var shortcuts: []

    Layout.fillWidth: true
    spacing: ScalerService.s(10)

    // Category Header
    Rectangle {
      Layout.fillWidth: true
      height: ScalerService.s(50)
      color: theme.primary.dim_background
      radius: ScalerService.s(12)
      border.width: ScalerService.s(2)
      border.color: theme.normal.black

      Text {
        anchors.centerIn: parent
        text: title
        color: theme.primary.foreground
        font {
          family: "ComicShannsMono Nerd Font"
          pixelSize: ScalerService.s(18)
          bold: true
        }
      }
    }

    // Shortcuts List
    ColumnLayout {
      Layout.fillWidth: true
      spacing: ScalerService.s(8)

      Repeater {
        model: shortcuts

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: ScalerService.s(60)
          color: theme.button.background
          radius: ScalerService.s(10)
          border.width: ScalerService.s(1)
          border.color: theme.button.border

          RowLayout {
            anchors.fill: parent
            anchors.margins: ScalerService.s(15)
            spacing: ScalerService.s(20)

            // Key Badge (Left side)
            Rectangle {
              Layout.preferredWidth: ScalerService.s(220)
              Layout.minimumWidth: ScalerService.s(220)
              Layout.maximumWidth: ScalerService.s(280)
              Layout.preferredHeight: ScalerService.s(35)
              color: theme.normal.blue
              radius: ScalerService.s(8)

              Text {
                id: keyText
                anchors.centerIn: parent
                text: modelData.key
                color: theme.primary.background
                font {
                  family: "ComicShannsMono Nerd Font"
                  pixelSize: ScalerService.s(13)
                  bold: true
                }
              }
            }

            // Action Description (Right side)
            Text {
              text: modelData.action
              color: theme.primary.foreground
              font {
                family: "ComicShannsMono Nerd Font"
                pixelSize: ScalerService.s(15)
              }
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
            }
          }
        }
      }
    }
  }
}
