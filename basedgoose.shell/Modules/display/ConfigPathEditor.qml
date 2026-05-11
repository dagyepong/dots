import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../../Commons" as Commons

Rectangle {
    id: root

    property string configPath: ""
    property string placeholder: "Enter config file path..."
    property string helpText: ""

    readonly property color cSurface: Commons.Theme.background
    readonly property color cSurfaceContainer: Qt.lighter(Commons.Theme.background, 1.15)
    readonly property color cPrimary: Commons.Theme.secondary
    readonly property color cText: Commons.Theme.foreground
    readonly property color cSubText: Qt.rgba(cText.r, cText.g, cText.b, 0.6)
    readonly property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.08)

    signal pathChanged(string newPath)

    radius: Commons.Theme.radius
    color: cSurfaceContainer
    implicitHeight: configPathColumn.implicitHeight + 16

    ColumnLayout {
        id: configPathColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰈙"
                font.family: Commons.Theme.fontIcon
                font.pixelSize: 14
                color: cSubText
            }

            Text {
                text: "Hyprland Config File"
                font.family: Commons.Theme.fontUI
                font.pixelSize: 11
                color: cSubText
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Commons.Theme.radius
            color: configPathInput.activeFocus ? Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.08) : cSurface
            border.color: configPathInput.activeFocus ? cPrimary : cBorder
            border.width: 1

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: 100
                }
            }

            TextInput {
                id: configPathInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                font.family: Commons.Theme.fontUI
                font.pixelSize: 12
                color: cText
                selectByMouse: true
                clip: true
                text: root.configPath

                onEditingFinished: {
                    if (text !== root.configPath) {
                        root.pathChanged(text);
                    }
                }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: Text.AlignVCenter
                font.family: Commons.Theme.fontUI
                font.pixelSize: 12
                color: cSubText
                text: root.placeholder
                visible: configPathInput.text === "" && !configPathInput.activeFocus
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.helpText
            font.family: Commons.Theme.fontUI
            font.pixelSize: 10
            color: Qt.rgba(cSubText.r, cSubText.g, cSubText.b, 0.7)
            wrapMode: Text.WordWrap
            visible: root.helpText !== ""
        }
    }
}
