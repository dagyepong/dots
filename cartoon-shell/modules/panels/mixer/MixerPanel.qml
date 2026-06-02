// Main mixer panel
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import "./" as Components
import qs.commons
import qs.components
import qs.services

PanelWindow {
  id: root

  implicitWidth: ScalerService.s(450)
  implicitHeight: ScalerService.s(600)
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
  Behavior on implicitHeight {
    NumberAnimation {
      duration: 60
      easing.type: Easing.OutCubic
    }
  }
  Behavior on implicitWidth {
    NumberAnimation {
      duration: 60
      easing.type: Easing.OutCubic
    }
  }
  property var lang: LanguageService.translations

  anchors {
    // Anchor theo vị trí của bar
    left: Settings.bar.position === "left"
    right: Settings.bar.position === "right" || Settings.bar.position === "top" || Settings.bar.position === "bottom"
    top: Settings.bar.position === "top"
    bottom: Settings.bar.position === "left" || Settings.bar.position === "right" || Settings.bar.position === "bottom"
  }

  margins {
    top: Settings.bar.position === "top" ? ScalerService.s(10) : 0
    bottom: (Settings.bar.position === "bottom" || Settings.bar.position === "left" || Settings.bar.position === "right") ? ScalerService.s(10) : 0
    left: Settings.bar.position === "left" ? ScalerService.s(10) : 0
    right: (Settings.bar.position === "right" || Settings.bar.position === "top" || Settings.bar.position === "bottom") ? ScalerService.s(10) : 0
  }
  color: "transparent"

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
    border.color: theme.button.border
    radius: ScalerService.s(Settings.appearance.radius1)
    border.width: Settings.appearance.enableBorder ? ScalerService.s(3) : 0

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: ScalerService.s(16)
      spacing: ScalerService.s(20)

      // Header với icon và title
      RowLayout {
        Layout.fillWidth: true
        spacing: ScalerService.s(12)

        IconImage {
          path: "system/mixer.png"
          size: "xl"
        }

        CustomText {
          name: lang.mixer.title
          isBold: true
          size: "large"
        }

      }

      // Default sink section
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: ScalerService.s(120)
        color: theme.primary.dim_background
        border.color: theme.button.border_select
        radius: ScalerService.s(Settings.appearance.radius2)
        border.width: Settings.appearance.enableBorder ? ScalerService.s(2) : 0

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: ScalerService.s(12)
          spacing: ScalerService.s(8)

          Label {
            text: lang.mixer.output_device
            font.bold: true
            font.pixelSize: ScalerService.s(16)
            font.family: "ComicShannsMono Nerd Font"

            color: theme.normal.blue
            Layout.fillWidth: true
          }

          Components.MixerEntry {
            node: Pipewire.defaultAudioSink
            Layout.fillWidth: true
            Layout.fillHeight: true
            showIcon: false
            showMediaName: false
          }
        }
      }

      // Applications section
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: theme.primary.dim_background
        border.color: theme.button.border_select
        radius: ScalerService.s(Settings.appearance.radius2)
        border.width: Settings.appearance.enableBorder ? ScalerService.s(2) : 0

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: ScalerService.s(8)
          spacing: ScalerService.s(8)

          // Section header
          Label {
            text: lang.mixer.application_streams
            font.bold: true

            font.family: "ComicShannsMono Nerd Font"
            font.pixelSize: ScalerService.s(16)
            color: theme.primary.foreground
            Layout.fillWidth: true
            Layout.leftMargin: ScalerService.s(8)
            Layout.topMargin: ScalerService.s(4)
          }

          // Applications list
          ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth

            ColumnLayout {
              width: parent.width
              spacing: ScalerService.s(8)
              anchors.margins: ScalerService.s(8)

              Repeater {
                model: linkTracker.linkGroups

                Components.MixerEntry {
                  required property PwLinkGroup modelData
                  node: modelData.source
                  Layout.fillWidth: true
                }
              }

              // Empty state
              Label {
                visible: linkTracker.linkGroups.count === 0
                text: lang.mixer.no_streams
                color: theme.primary.dim_foreground
                font.italic: true
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: ScalerService.s(20)
              }
            }
          }
        }
      }

      // Footer với status info
      RowLayout {
        Layout.fillWidth: true
        spacing: ScalerService.s(8)

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: ScalerService.s(20)
          color: "transparent"
          CustomText{
            anchors.centerIn: parent
            name: `Active streams: ${linkTracker.linkGroups.count}`
            size: "small"
            textColor: theme.primary.dim_foreground
          }
        }

        Rectangle {
          Layout.preferredWidth: ScalerService.s(20)
          Layout.preferredHeight: ScalerService.s(20)
          radius: ScalerService.s(10)
          color: theme.normal.green
          opacity: 0.7

          Label {
            anchors.centerIn: parent
            text: "●"
            font.pixelSize: ScalerService.s(8)
            color: theme.primary.background
          }
        }
      }
    }
  }

  PwNodeLinkTracker {
    id: linkTracker
    node: Pipewire.defaultAudioSink
  }
}
