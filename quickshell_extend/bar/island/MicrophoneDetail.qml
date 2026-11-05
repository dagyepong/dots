// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M I C R O P H O N E   D E T A I L                                      │
// │   the microphone · its level, who records it, which one                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"

// Opened from the control centre's microphone tile: its level, every
// application recording it with its own level — what the island's privacy
// mark points at — and the microphones to choose from, each a titled section,
// as the sound page is. Sizes are `AudioService`'s.
ColumnLayout {
    id: root

    signal back()

    spacing: Theme.detailGap

    DetailHeading {
        title: Tr.t("Microphone")
        detail: AudioService.sourceReady ? AudioService.outputName(AudioService.source) : ""
        onBack: root.back()
    }

    DetailSection {
        title: Tr.t("Volume")

        LevelRow {
            glyph: AudioService.sourceIcon
            name: AudioService.sourceReady ? AudioService.outputName(AudioService.source) : ""
            value: AudioService.sourceVolume
            available: AudioService.sourceReady
            dimmed: AudioService.sourceMuted
            onMoved: value => AudioService.setSourceVolume(value)
            onMarkClicked: AudioService.toggleSourceMute()
        }
    }

    DetailSection {
        title: Tr.t("Recording")
        visible: AudioService.captures.length > 0

        Repeater {
            model: AudioService.captures

            LevelRow {
                id: app

                required property var modelData

                picture: AudioService.streamIcon(app.modelData)
                name: AudioService.streamName(app.modelData)
                value: app.modelData.audio ? Math.round(app.modelData.audio.volume * 100) : 0
                dimmed: app.modelData.audio ? app.modelData.audio.muted : false
                onMoved: value => AudioService.setStreamVolume(app.modelData, value)
                onMarkClicked: AudioService.toggleStreamMute(app.modelData)
            }
        }
    }

    DetailSection {
        title: Tr.t("Input")

        Repeater {
            model: AudioService.inputs

            DetailChoice {
                required property var modelData

                text: AudioService.outputName(modelData)
                chosen: AudioService.source === modelData
                onPicked: AudioService.chooseInput(modelData)
            }
        }
    }

    Item { Layout.fillHeight: true }
}
