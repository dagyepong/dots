import QtQuick
import qs.theme
import qs.services

// Dashboard page 3: quick layouts · drawn map of the screens · one card per monitor
Item {
    id: root

    signal openPage(string name)
    property bool dragging: false

    width: 860
    height: 308

    onVisibleChanged: if (visible) Displays.refresh()

    readonly property bool several: Displays.outputs.length > 1

    // First screen other than the built-in one, for the Mirror button
    function mirrorPair() {
        const on = Displays.onList()
        if (on.length < 2) return null
        let src = on[0]
        for (let i = 0; i < on.length; i++) if (Displays.isInternal(on[i].name)) { src = on[i]; break }
        for (let i = 0; i < on.length; i++) if (on[i].name !== src.name) return { src: src.name, dst: on[i].name }
        return null
    }

    // ---------- Quick layouts ----------
    Rectangle {
        x: 14; y: 0
        width: 300; height: 84
        radius: 22
        color: Theme.surfaceSoft

        Text {
            x: 16; y: 10
            text: "Quick layout"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 10
            visible: Displays.mirrorFrom !== ""
            text: Displays.mirrorFrom + " → " + Displays.mirrorTo
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Grid {
            x: 10; y: 30
            columns: 4
            spacing: 6

            Repeater {
                model: [
                    { id: "internal", l: "Built-in" },
                    { id: "external", l: "External" },
                    { id: "extend",   l: "Extend" },
                    { id: "mirror",   l: "Mirror" }
                ]

                delegate: Chip {
                    required property var modelData

                    width: 65; height: 40
                    label: modelData.l
                    enabled: modelData.id === "internal" || root.several || modelData.id === "external"
                    selected: modelData.id === "mirror" && Displays.mirrorFrom !== ""
                    onClicked: {
                        if (modelData.id === "internal") Displays.onlyInternal()
                        else if (modelData.id === "external") Displays.onlyExternal()
                        else if (modelData.id === "extend") Displays.extend()
                        else {
                            const p = root.mirrorPair()
                            if (Displays.mirrorFrom !== "") Displays.stopMirror()
                            else if (p) Displays.mirror(p.src, p.dst)
                            else Displays.toast("Mirror needs two screens turned on")
                        }
                    }
                }
            }
        }
    }

    // ---------- The screens, drawn ----------
    Rectangle {
        id: mapCard
        x: 14; y: 94
        width: 300; height: 214
        radius: 22
        color: Theme.surfaceSoft

        Text {
            x: 16; y: 10
            text: "Screens"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 10
            text: "Identify"
            color: idMouse.containsMouse ? Theme.foreground : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10

            MouseArea {
                id: idMouse
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Displays.identify()
            }
        }

        // Bounding box of the screens that are on, scaled to fit
        readonly property var boxes: {
            const on = Displays.onList()
            const out = []
            for (let i = 0; i < on.length; i++) {
                const s = Displays.lsize(on[i])
                out.push({ name: on[i].name, x: on[i].x, y: on[i].y, w: s.w, h: s.h, res: on[i].width + "×" + on[i].height })
            }
            return out
        }
        readonly property real minX: boxes.reduce((a, b) => Math.min(a, b.x), 1e9)
        readonly property real minY: boxes.reduce((a, b) => Math.min(a, b.y), 1e9)
        readonly property real maxX: boxes.reduce((a, b) => Math.max(a, b.x + b.w), -1e9)
        readonly property real maxY: boxes.reduce((a, b) => Math.max(a, b.y + b.h), -1e9)
        readonly property real areaW: 268
        readonly property real areaH: 160
        readonly property real k: boxes.length === 0 ? 1
            : Math.min(areaW / Math.max(1, maxX - minX), areaH / Math.max(1, maxY - minY))

        Item {
            x: 16; y: 34
            width: mapCard.areaW
            height: mapCard.areaH

            Repeater {
                model: mapCard.boxes

                delegate: Rectangle {
                    id: box

                    required property var modelData
                    readonly property real bw: modelData.w * mapCard.k
                    readonly property real bh: modelData.h * mapCard.k

                    x: (mapCard.areaW - (mapCard.maxX - mapCard.minX) * mapCard.k) / 2 + (modelData.x - mapCard.minX) * mapCard.k
                    y: (mapCard.areaH - (mapCard.maxY - mapCard.minY) * mapCard.k) / 2 + (modelData.y - mapCard.minY) * mapCard.k
                    width: bw - 3
                    height: bh - 3
                    radius: 8
                    color: Displays.focused === modelData.name ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30) : Theme.island
                    border.width: 1
                    border.color: Displays.focused === modelData.name ? Theme.accent : Theme.border

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: box.modelData.name
                            color: Theme.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: box.width > 70
                            text: box.modelData.res
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: mapCard.boxes.length === 0
                text: "No screens turned on"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }

    // ---------- One card per monitor ----------
    Flickable {
        x: 328; y: 0
        width: 518; height: root.height
        contentHeight: flow.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Flow {
            id: flow
            width: parent.width
            spacing: 8

            Repeater {
                model: Displays.outputs

                delegate: MonitorCard {
                    width: (flow.width - 8) / 2
                    onOpenDisplay: root.openPage("display")
                }
            }
        }

        Text {
            width: parent.width
            y: 20
            visible: Displays.outputs.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: "No screens detected"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }
}
