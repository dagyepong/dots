import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import "../../Commons" as Commons
import "../../Widgets" as Widgets
import "DisplayUtils.js" as DisplayUtils

Rectangle {
    id: root

    property var pendingModeData: null
    property var pendingSettings: null
    property int countdownSeconds: 10
    property bool isPositionChange: false

    readonly property color cSurface: Commons.Theme.background
    readonly property color cPrimary: Commons.Theme.secondary
    readonly property color cText: Commons.Theme.foreground
    readonly property color cSubText: Qt.rgba(cText.r, cText.g, cText.b, 0.6)
    readonly property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.08)

    signal confirmClicked
    signal revertClicked

    function getTransformLabel(transform) {
        var labels = {
            0: "Normal",
            1: "90°",
            2: "180°",
            3: "270°",
            4: "Flipped",
            5: "Flipped 90°",
            6: "Flipped 180°",
            7: "Flipped 270°"
        };
        return labels[transform] || "Unknown";
    }

    width: 400
    height: confirmationContent.implicitHeight + 32
    radius: Commons.Theme.radius
    color: cSurface
    border.color: cBorder
    border.width: 1

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.4)
        shadowBlur: 1.0
        shadowVerticalOffset: 8
    }

    ColumnLayout {
        id: confirmationContent
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                width: 40
                height: 40
                radius: Commons.Theme.radius
                color: Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.15)

                Text {
                    anchors.centerIn: parent
                    text: "󰍹"
                    font.family: Commons.Theme.fontIcon
                    font.pixelSize: 20
                    color: cPrimary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: {
                        return root.isPositionChange ? "Confirm Display Layout" : "Confirm Display Mode";
                    }
                    font.family: Commons.Theme.fontUI
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: cText
                }

                Text {
                    text: {
                        if (root.isPositionChange) {
                            return "Monitor positions have been changed";
                        }
                        var text = "";
                        if (root.pendingModeData) {
                            text = "New mode: " + root.pendingModeData.formatted;
                        }
                        if (root.pendingSettings) {
                            var settings = [];
                            if (root.pendingSettings.scale !== undefined) {
                                settings.push("Scale: " + root.pendingSettings.scale.toFixed(1) + "x");
                            }
                            if (root.pendingSettings.transform !== undefined) {
                                settings.push("Rotation: " + DisplayUtils.getTransformLabel(root.pendingSettings.transform));
                            }
                            if (root.pendingSettings.mirror !== undefined && root.pendingSettings.mirror !== "") {
                                settings.push("Mirror: " + root.pendingSettings.mirror);
                            }
                            if (settings.length > 0) {
                                text += (text ? " | " : "") + settings.join(", ");
                            }
                        }
                        return text || "Applying new display mode...";
                    }
                    font.family: Commons.Theme.fontUI
                    font.pixelSize: 11
                    color: cSubText
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: cBorder
        }

        Text {
            Layout.fillWidth: true
            text: root.isPositionChange ? "Keep this display layout? Changes will be reverted in " + root.countdownSeconds + " second" + (root.countdownSeconds !== 1 ? "s" : "") + "." : "Keep this display mode? Changes will be reverted in " + root.countdownSeconds + " second" + (root.countdownSeconds !== 1 ? "s" : "") + "."
            font.family: Commons.Theme.fontUI
            font.pixelSize: 12
            color: cText
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Widgets.ActionButton {
                Layout.fillWidth: true
                text: "Keep Changes"
                textColor: cPrimary
                baseColor: Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.1)
                hoverColor: Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.18)
                pressedColor: Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.25)
                fontSize: 12
                horizontalPadding: 20
                implicitHeight: 36
                onClicked: {
                    root.confirmClicked();
                }
            }

            Widgets.ActionButton {
                Layout.fillWidth: true
                text: "Revert"
                textColor: cSubText
                baseColor: Qt.rgba(cSubText.r, cSubText.g, cSubText.b, 0.08)
                hoverColor: Qt.rgba(cSubText.r, cSubText.g, cSubText.b, 0.15)
                pressedColor: Qt.rgba(cSubText.r, cSubText.g, cSubText.b, 0.25)
                fontSize: 12
                horizontalPadding: 20
                implicitHeight: 36
                onClicked: {
                    root.revertClicked();
                }
            }
        }
    }
}
