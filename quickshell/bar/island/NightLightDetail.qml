// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N I G H T   L I G H T   D E T A I L                                    │
// │   how warm the night light makes the screen                              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"

// Opened from the night light's tile: its warmth as a level, and four warmths
// to pick with one press, as the sound page is laid out. The tile is the
// switch; a click on the level's mark is too. Sizes are `SunsetService`'s.
ColumnLayout {
    id: root

    signal back()

    spacing: Theme.detailGap

    DetailHeading {
        title: Tr.t("Night light")
        detail: SunsetService.on ? `${SunsetService.temperature} K` : Tr.t("Off")
        onBack: root.back()
    }

    DetailSection {
        title: Tr.t("Warmth")

        // The warmest at the left, nearly daylight at the right.
        LevelRow {
            glyph: SunsetService.icon
            name: SunsetService.on ? Tr.t("On") : Tr.t("Off")
            unit: " K"
            from: SunsetService.warmest
            to: SunsetService.coolest
            value: SunsetService.temperature
            dimmed: !SunsetService.on
            onMoved: value => SunsetService.setTemperature(value)
            onMarkClicked: SunsetService.toggle()
        }
    }

    DetailSection {
        title: Tr.t("Presets")

        Repeater {
            model: SunsetService.presets

            DetailChoice {
                required property var modelData

                text: `${Tr.t(modelData.label)}  ·  ${modelData.kelvin} K`
                chosen: SunsetService.temperature === modelData.kelvin
                onPicked: SunsetService.setTemperature(modelData.kelvin)
            }
        }
    }

    Item { Layout.fillHeight: true }
}
