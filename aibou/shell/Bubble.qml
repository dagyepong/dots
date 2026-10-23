import QtQuick

// The speech bubble. Its tail points down at (tailX, bottom).
Item {
    id: bubble
    required property var st
    readonly property var world: st.world
    property string title: ""
    property string text: ""
    property bool chat: false
    property real tailX: width / 2
    property real shown: 0
    signal send(string text)
    signal dismiss()

    readonly property real maxW: 400
    width: Math.min(maxW, Math.max(140, content.implicitWidth + 28))
    height: content.implicitHeight + 22
    opacity: shown
    scale: 0.85 + 0.15 * shown
    transformOrigin: Item.Bottom
    Behavior on shown { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

    function focusInput() { input.forceActiveFocus() }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: bubble.world.bubbleBg
        border.width: 1
        border.color: Qt.rgba(bubble.world.outline.r, bubble.world.outline.g, bubble.world.outline.b, 0.5)
    }
    Rectangle {
        width: 12; height: 12
        rotation: 45
        x: Math.max(14, Math.min(bubble.width - 26, bubble.tailX - 6))
        y: bubble.height - 7
        color: bubble.world.bubbleBg
        border.width: 1
        border.color: Qt.rgba(bubble.world.outline.r, bubble.world.outline.g, bubble.world.outline.b, 0.5)
        Rectangle { x: -1; y: -1; width: 13; height: 6; color: bubble.world.bubbleBg; rotation: -45; transformOrigin: Item.BottomLeft; visible: false }
    }
    // hide the upper half of the tail's border so it joins the bubble
    Rectangle {
        width: 18; height: 7
        x: Math.max(11, Math.min(bubble.width - 29, bubble.tailX - 9))
        y: bubble.height - 8
        color: bubble.world.bubbleBg
    }

    Column {
        id: content
        x: 14; y: 11
        width: bubble.width - 28
        spacing: 5
        Text {
            visible: bubble.title !== ""
            width: Math.min(implicitWidth, bubble.maxW - 28)
            text: bubble.title
            color: bubble.world.primary
            font.pixelSize: 12
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            id: body
            visible: bubble.text !== "" || bubble.st.thinking
            width: Math.min(implicitWidth, bubble.maxW - 28)
            text: bubble.st.thinking ? "…" : bubble.text
            color: bubble.world.bubbleText
            font.pixelSize: 14
            wrapMode: Text.Wrap
            maximumLineCount: 8
            elide: Text.ElideRight
        }
        Rectangle {
            visible: bubble.chat
            width: Math.max(220, bubble.maxW - 28)
            height: 30
            radius: 10
            color: Qt.rgba(1, 1, 1, bubble.world.dark ? 0.06 : 0.5)
            border.width: input.activeFocus ? 1 : 0
            border.color: bubble.world.primary
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: bubble.world.bubbleText
                font.pixelSize: 14
                clip: true
                Keys.onReturnPressed: { if (text.trim() !== "") { bubble.send(text.trim()); text = "" } }
                Keys.onEscapePressed: bubble.dismiss()
            }
            Text {
                visible: input.text === "" && !input.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                x: 10
                text: bubble.world.tr("Schreib mir was …", "Say something …", "なにか話して …")
                color: bubble.world.outline
                font.pixelSize: 13
            }
        }
    }
}
