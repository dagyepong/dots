import QtQuick
import qs.theme
import qs.services

Item {
    id: root

    readonly property var req: Auth.flow
    readonly property bool waiting: req ? !req.isResponseRequired : true

    readonly property string promptText: {
        if (!req || req.inputPrompt === "") return "Password"
        return req.inputPrompt.replace(/:\s*$/, "")
    }

    readonly property string statusText: {
        if (!req) return ""
        if (req.supplementaryMessage !== "") return req.supplementaryMessage
        if (req.failed) return "Wrong password, try again."
        if (waiting) return "Checking…"
        return ""
    }

    readonly property bool statusIsError: req ? (req.supplementaryIsError || req.failed) : false

    function reset() {
        pw.text = ""
        pw.forceActiveFocus()
    }

    function submit() {
        if (!req || !req.isResponseRequired) return
        req.submit(pw.text)
        pw.text = ""
    }

    function cancel() {
        if (req) req.cancelAuthenticationRequest()
    }

    // After a wrong password: clear the field and restore the cursor
    Connections {
        target: root.req
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            pw.text = ""
            pw.forceActiveFocus()
        }
    }

    // ---------- Header ----------
    Rectangle {
        x: 20; y: 18
        width: 34; height: 34
        radius: 17
        color: Theme.border

        Glyph {
            anchors.centerIn: parent
            kind: "lock"
            size: 16
            color: Theme.accent
        }
    }

    Text {
        x: 64; y: 18
        height: 34
        verticalAlignment: Text.AlignVCenter
        text: "Authentication required"
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 15
        font.bold: true
    }

    // ---------- Request message ----------
    Rectangle {
        x: 20; y: 64
        width: root.width - 40
        height: 76
        radius: 16
        color: Theme.surfaceSoft

        Text {
            x: 14; y: 10
            width: parent.width - 28
            text: root.req ? root.req.message : ""
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Text {
            x: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: parent.width - 28
            text: root.req ? root.req.actionId : ""
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    // ---------- Campo password ----------
    Rectangle {
        x: 20; y: 152
        width: root.width - 40
        height: 38
        radius: 19
        color: Theme.surfaceSoft
        border.width: pw.activeFocus ? 1 : 0
        border.color: Theme.accent

        Glyph {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            kind: "lock"
            size: 13
            color: Theme.muted
        }

        TextInput {
            id: pw

            x: 38
            width: parent.width - 38 - 16
            height: parent.height
            verticalAlignment: TextInput.AlignVCenter
            echoMode: (root.req && root.req.responseVisible) ? TextInput.Normal : TextInput.Password
            passwordCharacter: "•"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 13
            clip: true

            onAccepted: root.submit()
            Keys.onEscapePressed: root.cancel()
        }

        Text {
            x: 38
            anchors.verticalCenter: parent.verticalCenter
            visible: pw.text === ""
            text: root.promptText
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }
    }

    // ---------- Stato / errore ----------
    Text {
        x: 24; y: 196
        width: root.width - 48
        height: 16
        text: root.statusText
        color: root.statusIsError ? Theme.danger : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
        elide: Text.ElideRight
    }

    // ---------- Pulsanti ----------
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 20
        y: 222
        spacing: 8

        Rectangle {
            width: 90; height: 34
            radius: 17
            color: cancelMouse.containsMouse ? Theme.islandHover : Theme.surfaceSoft
            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: "Cancel"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }

            MouseArea {
                id: cancelMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cancel()
            }
        }

        Rectangle {
            width: 120; height: 34
            radius: 17
            color: Theme.accent
            opacity: root.waiting ? 0.5 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "Authenticate"
                color: Theme.island
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.submit()
            }
        }
    }
}
