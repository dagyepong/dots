import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.services

// Full-screen welcome, once per session (like Apple's "hello"):
// the quote appears word by word, the language depends on the keyboard layout.
// Prova a mano: qs ipc call hello show
Scope {
    id: root

    property bool shown: false
    property string lang: "it"

    // Lives in XDG_RUNTIME_DIR: gone on every logout/reboot, so the welcome returns on every login
    readonly property string flag: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-hello-shown"

    // Identifies the current graphical session: changes on every login, even if /run/user stays
    readonly property string session: Quickshell.env("NIRI_SOCKET") || Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "session"

    // The lines are already split: each word appears in turn
    readonly property var texts: ({
        it: {
            lines: [["La", "vita", "non", "è", "né", "brutta", "né", "bella,"], ["ma", "è", "originale!"]],
            by: "Italo Svevo",
            from: "da «La coscienza di Zeno»"
        },
        en: {
            lines: [["Life", "is", "neither", "ugly", "nor", "beautiful,"], ["but", "it", "is", "original!"]],
            by: "Italo Svevo",
            from: "from “Confessions of Zeno”"
        },
        fr: {
            lines: [["La", "vie", "n’est", "ni", "laide", "ni", "belle,"], ["mais", "elle", "est", "originale !"]],
            by: "Italo Svevo",
            from: "extrait de « La Conscience de Zeno »"
        },
        de: {
            lines: [["Das", "Leben", "ist", "weder", "hässlich", "noch", "schön,"], ["aber", "es", "ist", "originell!"]],
            by: "Italo Svevo",
            from: "aus „Zeno Cosini“"
        }
    })

    function langFor(xkb) {
        if (xkb === "us" || xkb === "gb") return "en"
        if (xkb === "fr") return "fr"
        if (xkb === "de") return "de"
        return "it"
    }

    function begin(force) {
        if (shown) return
        pending = true
    }

    property bool pending: false

    // The layout is read shortly after startup: wait a moment before choosing the language
    Timer {
        interval: 900
        running: root.pending
        onTriggered: {
            root.pending = false
            root.lang = root.langFor(KbLayout.xkb)
            root.shown = true
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "f=\"$1\"; cur=\"$2\"; if [ \"$(cat \"$f\" 2>/dev/null)\" = \"$cur\" ]; then echo no; else printf '%s' \"$cur\" > \"$f\"; echo yes; fi", "sh", root.flag, root.session]

        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "yes" && HelloState.enabled) root.begin(false)
        }
    }

    Connections {
        target: HelloState

        function onPreview() { root.begin(true) }
    }

    // qs ipc call hello show | on | off | toggle
    IpcHandler {
        target: "hello"

        function show(): void { root.begin(true) }
        function on(): void { HelloState.set(true) }
        function off(): void { HelloState.set(false) }
        function toggle(): void { HelloState.toggle() }
    }

    Variants {
        model: root.shown ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shell-hello"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            readonly property var msg: root.texts[root.lang]
            // Each word knows which letter it starts from: one letter per "tick", a space counts as one tick
            readonly property var plan: {
                const out = []
                let n = 0
                for (let i = 0; i < msg.lines.length; i++) {
                    const ln = []
                    for (let j = 0; j < msg.lines[i].length; j++) {
                        ln.push({ text: msg.lines[i][j], start: n })
                        n += msg.lines[i][j].length + 1
                    }
                    out.push(ln)
                }
                return { lines: out, total: n }
            }
            readonly property int total: plan.total
            readonly property real fontPx: Math.round(Math.min(win.width * 0.05, win.height * 0.075))

            // runs from 0 to total + 10: the letters appear one after another, then "light up"
            property real t: 0
            property real veil: 0       // sfondo scuro
            property real out: 1        // dissolvenza finale

            function clamp(v) { return Math.max(0, Math.min(1, v)) }

            SequentialAnimation {
                running: true

                NumberAnimation { target: win; property: "veil"; to: 1; duration: 800; easing.type: Easing.OutCubic }
                NumberAnimation { target: win; property: "t"; to: win.total + 10
                                  duration: (win.total + 10) * 62 }
                PauseAnimation { duration: 3200 }
                NumberAnimation { target: win; property: "out"; to: 0; duration: 1000; easing.type: Easing.InOutCubic }
                ScriptAction { script: root.shown = false }
            }

            Item {
                anchors.fill: parent
                opacity: win.out

                Rectangle {
                    anchors.fill: parent
                    color: Theme.background
                    opacity: 0.94 * win.veil
                }

                // A click or a mouse button and it goes away
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.shown = false
                }

                Column {
                    anchors.centerIn: parent
                    spacing: win.fontPx * 0.3

                    Repeater {
                        model: win.plan.lines

                        delegate: Row {
                            id: lineRow

                            required property var modelData

                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: win.fontPx * 0.3

                            Repeater {
                                model: lineRow.modelData

                                delegate: Row {
                                    id: wordRow

                                    required property var modelData

                                    Repeater {
                                        model: wordRow.modelData.text.length

                                        delegate: Text {
                                            id: letter

                                            required property int index

                                            readonly property real at: wordRow.modelData.start + index
                                            readonly property real appear: win.clamp((win.t - at) / 3)
                                            readonly property real settle: win.clamp((win.t - at - 3) / 7)

                                            text: wordRow.modelData.text.charAt(index)
                                            font.family: "serif"
                                            font.italic: true
                                            font.pixelSize: win.fontPx
                                            color: Theme.mix(Theme.accent, Theme.foreground, settle)
                                            opacity: appear
                                            transform: Translate { y: (1 - letter.appear) * win.fontPx * 0.3 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Where the phrase comes from, bottom left
                Column {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 56
                    anchors.bottomMargin: 48
                    spacing: 4
                    opacity: win.clamp((win.t - win.total) / 5)

                    Rectangle {
                        width: 28 + 36 * win.clamp((win.t - win.total) / 5)
                        height: 2
                        radius: 1
                        color: Theme.accent
                    }

                    Text {
                        text: win.msg.by
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Text {
                        text: win.msg.from
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
