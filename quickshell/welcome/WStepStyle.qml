import QtQuick
import qs.theme
import qs.services
import qs.settings

// Step 2: the style of the shell (applied right away: look behind the card)
WStep {
    title: "Choose your style"
    subtitle: "The shell changes right now, behind this card. Pick the one you like; you can switch at any time with Alt+S."

    Row {
        id: thumbs
        y: 6
        spacing: 16

        Repeater {
            model: [
                { id: "island",  hint: "Floating pills that expand" },
                { id: "classic", hint: "A full-width bar" },
                { id: "dash",    hint: "One pill that grows" },
                { id: "side",    hint: "Bar on the left, frame around" }
            ]

            delegate: StyleThumb {
                required property var modelData
                kind: modelData.id
                label: Style.styles.filter(s => s.id === modelData.id)[0].name
                hint: modelData.hint
                selected: Style.current === modelData.id
                onClicked: Style.set(modelData.id)
            }
        }
    }

    Item {
        y: thumbs.y + 190 + 30
        width: parent.width
        height: 60
        opacity: Style.current === "dash" ? 1 : 0.35
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Dashboard version"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.bold: true
        }

        Text {
            x: 0
            y: parent.height / 2 + 12
            text: "Only for the Dashboard style (Alt+V)"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        SChoice {

            base: Theme.surfaceSoft
            x: 230
            anchors.verticalCenter: parent.verticalCenter
            model: Style.dashVariants.map(v => ({ id: v.id, label: v.name }))
            current: Style.dashVariant
            onPicked: id => { Style.setDashVariant(id); if (Style.current !== "dash") Style.set("dash") }
        }
    }
}
