import QtQuick
import qs.modules.common
import qs.services
import "../../common/functions/WelcomeMath.js" as WM

// The video's "Track Matte" slide: a full-width black band with the artwork
// sitting in it. Here the artwork is one round sticker per unit theme (the
// colours come from ThemeService.baseGroups), the current theme marked with a
// sparkle. They pop in one after another; `idle` makes them bob in turn.
Item {
    id: root

    property real unit: 1
    property real reveal: 0
    property real idle: 0
    property bool idling: false
    property real pageWidth: 576

    // Short names for the unit themes (the full names are too long for a badge).
    readonly property var tags: ({ vs: "VS", leoneed: "L/N", mmj: "MMJ", vbs: "VBS", wxs: "WxS", nightcord: "25:00" })
    // The row is 6 badges with a gap of a third of a badge between them; on a
    // narrow page the badges shrink so the row always fits inside the band.
    readonly property real badge: Math.min(88 * root.unit, (root.pageWidth - 64 * root.unit) / 7.7)
    readonly property real gap: root.badge * 0.34

    width: root.pageWidth
    height: 246 * root.unit

    Rectangle {
        anchors.fill: parent
        color: "#050505"
    }

    Row {
        anchors.centerIn: parent
        spacing: root.gap

        Repeater {
            model: ThemeService.baseGroups

            Item {
                id: unitItem

                required property var modelData
                required property int index
                readonly property real p: WM.stagger(root.reveal, index, 6, 0.5)

                width: root.badge
                height: root.badge + root.badge * 0.34
                visible: p > 0
                opacity: Math.min(1, p * 4)
                scale: WM.easeOutBack(p)
                transformOrigin: Item.Center
                y: root.idling ? Math.sin(root.idle + index * 1.05) * 3 * root.unit : 0

                Rectangle {
                    id: disc

                    width: root.badge
                    height: root.badge
                    radius: root.badge / 2
                    border.width: Math.max(2, 3 * root.unit)
                    border.color: "#ffffff"
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: unitItem.modelData.c.A }
                        GradientStop { position: 1.0; color: unitItem.modelData.c.B }
                    }

                    // a small gloss, like the letters have
                    Rectangle {
                        x: parent.width * 0.2
                        y: parent.height * 0.15
                        width: parent.width * 0.34
                        height: Math.max(3, parent.height * 0.1)
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.55)
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: root.badge + root.badge * 0.11
                    text: root.tags[unitItem.modelData.id] || unitItem.modelData.name
                    color: Qt.rgba(1, 1, 1, 0.78)
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.max(8, root.badge * 0.136)
                    font.weight: Font.Medium
                    font.letterSpacing: 0.6 * root.unit
                }

                // marks the theme that is on now
                WelcomeSparkle {
                    visible: unitItem.modelData.id === ThemeService.current
                    x: root.badge - width * 0.7
                    y: -height * 0.35
                    size: root.badge * 0.3
                    ink: "#050505"
                    stroke: 1.4 * root.unit
                }
            }
        }
    }
}
