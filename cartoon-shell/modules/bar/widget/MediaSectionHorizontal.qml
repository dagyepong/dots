import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.services
import qs.commons
import qs.components
Item {
  RowLayout {
    anchors.fill: parent
    spacing: ScalerService.s(12)

    // Song info with marquee effect
    ColumnLayout {
      id: songInfoColumn
      Layout.fillWidth: true
      spacing: 0

      // Container for song title with marquee effect
      Item {
        id: songContainer
        Layout.fillWidth: true
        Layout.preferredHeight: ScalerService.s(23)
        clip: true

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onClicked: {
            VisibleService.togglePanel("music");
          }
          onEntered: songContainer.opacity = 0.8
          onExited: songContainer.opacity = 1.0
        }

        Text {
          id: songText
          text: Players.mprisPlayer?.trackTitle ?? "Not Playing"
          color: theme.primary.foreground
          font.family: "ComicShannsMono Nerd Font"
          font.pixelSize: ScalerService.s(16)

          property bool needsMarquee: width > songContainer.width

          x: 0

          SequentialAnimation on x {
            id: marqueeAnimation
            running: songText.needsMarquee
            loops: Animation.Infinite

            // Pause at start
            PauseAnimation {
              duration: 2000
            }

            // Scroll left
            NumberAnimation {
              to: -(songText.width - songContainer.width)
              duration: Math.max(2000, (songText.width - songContainer.width) * 20)
              easing.type: Easing.Linear
            }

            // Pause at end
            PauseAnimation {
              duration: 2000
            }

            // Scroll back
            NumberAnimation {
              to: 0
              duration: Math.max(2000, (songText.width - songContainer.width) * 20)
              easing.type: Easing.Linear
            }
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: 100
          }
        }
      }

      // Artist name
      CustomText {
        name: Players.mprisPlayer ? (Players.mprisPlayer.trackArtist || "Unknown Artist") : "Unknown Artist"
        textColor: theme.primary.dim_foreground
        size: "xs"
        elide: Text.ElideRight
        Layout.fillWidth: true
      }
    }

    // Controls
    Item {
      Layout.fillHeight: true
      Layout.preferredWidth: ScalerService.s(120)

      RowLayout {
        id: controlsRow

        anchors.centerIn: parent
        spacing: ScalerService.s(2)

        ButtonIconText {
          name: "skip_previous"
          size: "normal"

          Layout.alignment: Qt.AlignVCenter
          onClicked: Players?.mprisPlayer.previous()

        }
        ButtonIconText {
          name: Players.mprisPlayer && Players.mprisPlayer.isPlaying
          ? "pause"
          : "play_arrow"
          size: "normal"

          Layout.alignment: Qt.AlignVCenter
          onClicked: Players?.mprisPlayer.togglePlaying()

        }
        ButtonIconText {
          name: "skip_next"
          size: "normal"

          Layout.alignment: Qt.AlignVCenter
          onClicked: Players?.mprisPlayer.next()

        }

      }
    }
  }
}
