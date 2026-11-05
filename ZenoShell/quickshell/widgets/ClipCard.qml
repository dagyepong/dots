import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.services

// Clipboard history card (dashboard pages). Set x/y/width/height from outside.
Item {
    id: root

    signal pasted()

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 20
        color: Theme.surfaceSoft

        Text {
            x: 14; y: 11
            text: "Clipboard"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 11
            visible: ClipHist.items.length > 0
            text: "Clear"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: ClipHist.wipe()
            }
        }

        Text {
            x: 12; y: 34
            width: parent.width - 24
            visible: !ClipHist.available
            wrapMode: Text.WordWrap
            text: "Needs cliphist, wl-clipboard and wtype"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            x: 0; y: 34
            width: parent.width
            height: parent.height - 34
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: ClipHist.available && ClipHist.items.length === 0
            text: "Nothing copied yet"
            color: Theme.muted
            opacity: 0.7
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        ListView {
            x: 8; y: 34
            width: parent.width - 16
            height: parent.height - 34 - 8
            spacing: 5
            clip: true
            visible: ClipHist.available
            model: ClipHist.items

            delegate: Rectangle {
                id: cItem

                required property var modelData
                readonly property bool img: modelData.isImage

                width: ListView.view.width
                height: img ? 50 : 32
                radius: 12
                color: cMouse.containsMouse ? Theme.islandHover : Theme.island
                Behavior on color { ColorAnimation { duration: 100 } }

                MouseArea {
                    id: cMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        ClipHist.paste(cItem.modelData.id)
                        root.pasted()
                    }
                }

                ClippingRectangle {
                    visible: cItem.img
                    x: 6; y: 6
                    width: 50; height: 38
                    radius: 8
                    color: Theme.surfaceSoft

                    Image {
                        anchors.fill: parent
                        source: ClipHist.ready[cItem.modelData.id]
                                ? "file://" + ClipHist.thumbDir + "/" + cItem.modelData.id : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(120, 90)
                    }
                }

                Text {
                    x: cItem.img ? 64 : 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 24
                    text: cItem.img ? "Image" : cItem.modelData.preview
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: Theme.muted
                    font.pixelSize: 15

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ClipHist.remove(cItem.modelData.raw)
                    }
                }
            }
        }
    }
}
