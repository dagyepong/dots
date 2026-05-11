import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../../Commons" as Commons
import "../../Widgets" as Widgets
import "DisplayUtils.js" as DisplayUtils

Rectangle {
    id: root

    required property string name
    required property bool enabled
    required property string currentMode
    required property string availableModesJson
    required property int index
    required property real monitorScale
    required property int monitorTransform
    required property string mirrorTarget
    required property int positionX
    required property int positionY
    required property int monitorWidth
    required property int monitorHeight

    property var pendingChanges: null

    readonly property color cSurface: Commons.Theme.background
    readonly property color cSurfaceContainer: Qt.lighter(Commons.Theme.background, 1.15)
    readonly property color cPrimary: Commons.Theme.secondary
    readonly property color cText: Commons.Theme.foreground
    readonly property color cSubText: Qt.rgba(cText.r, cText.g, cText.b, 0.6)
    readonly property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.08)
    readonly property color cHover: Qt.rgba(cText.r, cText.g, cText.b, 0.06)

    readonly property string effectiveMode: pendingChanges && pendingChanges.mode ? pendingChanges.mode.formatted : currentMode
    readonly property real effectiveScale: pendingChanges && pendingChanges.scale !== undefined ? pendingChanges.scale : monitorScale
    readonly property int effectiveTransform: pendingChanges && pendingChanges.transform !== undefined ? pendingChanges.transform : monitorTransform
    readonly property string effectiveMirror: pendingChanges && pendingChanges.mirror !== undefined ? pendingChanges.mirror : mirrorTarget
    readonly property int effectivePositionX: pendingChanges && pendingChanges.positionX !== undefined ? pendingChanges.positionX : positionX
    readonly property int effectivePositionY: pendingChanges && pendingChanges.positionY !== undefined ? pendingChanges.positionY : positionY

    readonly property bool hasPendingChanges: pendingChanges !== null && Object.keys(pendingChanges).length > 0

    signal toggleDisplay(string monitorName, bool enabled)
    signal modeDropdownRequested(Item parentItem, var modes, string currentMode, string monitorName)
    signal scaleDropdownRequested(Item parentItem, string monitorName, real currentScale)
    signal rotateDropdownRequested(Item parentItem, string monitorName, int currentTransform)
    signal mirrorDropdownRequested(Item parentItem, string monitorName, string currentMirror)
    signal stopMirroringRequested(string monitorName)

    property var availableModes: {
        try {
            return JSON.parse(availableModesJson);
        } catch (e) {
            return [];
        }
    }

    width: parent ? parent.width : 300
    height: enabled ? (mirrorTarget && mirrorTarget !== "" ? 260 : 300) : 60
    radius: Commons.Theme.radius
    color: cSurface
    border.color: cBorder
    border.width: 1

    ColumnLayout {
        id: monitorContentLayout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Header row
        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.name
                    font.family: Commons.Theme.fontUI
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: cText
                }

                Text {
                    text: "Position: " + root.effectivePositionX + "x" + root.effectivePositionY + (root.hasPendingChanges ? " *" : "")
                    font.family: Commons.Theme.fontUI
                    font.pixelSize: 10
                    color: root.hasPendingChanges ? cPrimary : cSubText
                    visible: root.enabled
                }
            }

            Widgets.ToggleSwitch {
                checked: root.enabled
                onToggled: {
                    root.toggleDisplay(root.name, checked);
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: cBorder
            visible: root.enabled
        }

        // Settings section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.enabled

            Widgets.SectionLabel {
                text: "Resolution & Refresh Rate"
                labelColor: cSubText
            }

            Widgets.DropdownButton {
                id: modeDropdownButton
                Layout.fillWidth: true
                text: root.effectiveMode
                placeholderText: "Select mode..."
                textColor: cText
                placeholderColor: cSubText
                highlightColor: cPrimary
                baseColor: cSurfaceContainer
                hoverColor: cHover
                borderColor: cBorder
                hoverBorderColor: cPrimary
                isHighlighted: pendingChanges && pendingChanges.mode
                onClicked: {
                    root.modeDropdownRequested(modeDropdownButton, root.availableModes, root.effectiveMode, root.name);
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Widgets.SectionLabel {
                        text: "Scale"
                        labelColor: cSubText
                    }

                    Widgets.DropdownButton {
                        id: scaleDropdownButton
                        Layout.fillWidth: true
                        text: root.effectiveScale.toFixed(1) + "x"
                        textColor: cText
                        highlightColor: cPrimary
                        baseColor: cSurfaceContainer
                        hoverColor: cHover
                        borderColor: cBorder
                        hoverBorderColor: cPrimary
                        isHighlighted: pendingChanges && pendingChanges.scale !== undefined
                        onClicked: {
                            root.scaleDropdownRequested(scaleDropdownButton, root.name, root.effectiveScale);
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Widgets.SectionLabel {
                        text: "Rotation"
                        labelColor: cSubText
                    }

                    Widgets.DropdownButton {
                        id: rotateDropdownButton
                        Layout.fillWidth: true
                        text: DisplayUtils.getTransformLabel(root.effectiveTransform)
                        textColor: cText
                        highlightColor: cPrimary
                        baseColor: cSurfaceContainer
                        hoverColor: cHover
                        borderColor: cBorder
                        hoverBorderColor: cPrimary
                        isHighlighted: pendingChanges && pendingChanges.transform !== undefined
                        onClicked: {
                            root.rotateDropdownRequested(rotateDropdownButton, root.name, root.effectiveTransform);
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: !root.effectiveMirror || root.effectiveMirror === ""

                    Text {
                        text: "Mirror"
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 11
                        color: cSubText
                    }

                    Rectangle {
                        id: mirrorDropdownButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Commons.Theme.radius
                        color: mirrorDropdownArea.containsMouse ? cHover : cSurfaceContainer
                        border.color: mirrorDropdownArea.containsMouse ? cPrimary : cBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: root.effectiveMirror && root.effectiveMirror !== "" ? root.effectiveMirror : "None"
                                font.family: Commons.Theme.fontUI
                                font.pixelSize: 12
                                color: cText
                            }

                            Text {
                                text: mirrorDropdownArea.containsMouse ? "󰅀" : "󰅂"
                                font.family: Commons.Theme.fontIcon
                                font.pixelSize: 12
                                color: cSubText
                            }
                        }

                        MouseArea {
                            id: mirrorDropdownArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.mirrorDropdownRequested(mirrorDropdownButton, root.name, root.effectiveMirror);
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    spacing: 4
                    visible: root.effectiveMirror && root.effectiveMirror !== ""

                    Text {
                        text: "Mirroring: " + root.effectiveMirror
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 11
                        color: (pendingChanges && pendingChanges.mirror !== undefined) ? cPrimary : cSubText
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Commons.Theme.radius
                        color: mirrorRemoveArea.containsMouse ? cHover : cSurfaceContainer
                        border.color: mirrorRemoveArea.containsMouse ? cPrimary : cBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                text: "Stop Mirroring"
                                font.family: Commons.Theme.fontUI
                                font.pixelSize: 12
                                color: cPrimary
                            }

                            Text {
                                text: "󰅀"
                                font.family: Commons.Theme.fontIcon
                                font.pixelSize: 12
                                color: cSubText
                            }
                        }

                        MouseArea {
                            id: mirrorRemoveArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.stopMirroringRequested(root.name);
                            }
                        }
                    }
                }
            }
        }
    }
}
