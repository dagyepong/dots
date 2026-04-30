import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Services
import qs.Widgets

ColumnLayout {
    property var context
    property var colors: context.colors

    spacing: 16

    Text {
        text: "Interface"
        font.family: Config.fontFamily
        font.pixelSize: 20
        font.bold: true
        color: colors.fg
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            Text {
                text: "" 
                font.family: "Symbols Nerd Font"
                font.pixelSize: 64
                color: colors.accent
                Layout.alignment: Qt.AlignHCenter
                opacity: 0.8
            }

            Text {
                text: "Work in Progress"
                font.family: Config.fontFamily
                font.pixelSize: 24
                font.bold: true
                color: colors.fg
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "This page is currently under development.\nCheck back later for interface settings."
                font.family: Config.fontFamily
                font.pixelSize: 14
                color: colors.subtext
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

}
