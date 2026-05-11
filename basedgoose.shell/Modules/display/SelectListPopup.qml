import QtQuick 6.10
import QtQuick.Effects
import "../../Commons" as Commons

Rectangle {
    id: root

    property var model: []
    property string contextMonitor: ""
    property int popupWidth: 200
    property int itemHeight: 36
    property int maxListHeight: 300

    property color cSurface: Commons.Theme.background
    property color cText: Commons.Theme.foreground
    property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.08)
    property color cHover: Qt.rgba(cText.r, cText.g, cText.b, 0.06)

    signal itemSelected(var value)

    visible: false
    width: popupWidth
    height: listHeight
    radius: Commons.Theme.radius
    color: cSurface
    border.color: cBorder
    border.width: 1
    z: 1000
    clip: true

    readonly property int padding: 16
    readonly property int listHeight: Math.min(maxListHeight, (model ? model.length : 0) * itemHeight + padding)

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.35)
        shadowBlur: 1.0
        shadowVerticalOffset: 4
    }

    onItemSelected: root.visible = false

    Flickable {
        anchors.fill: parent
        anchors.margins: 8
        contentWidth: listView.width
        contentHeight: listView.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ListView {
            id: listView
            width: root.width - 16
            height: (model ? model.length : 0) * itemHeight
            model: root.model
            interactive: false

            delegate: Rectangle {
                width: listView.width
                height: root.itemHeight
                color: itemMa.containsMouse ? root.cHover : "transparent"
                radius: Commons.Theme.radiusSm

                readonly property var rowValue: modelData && (modelData.value !== undefined) ? modelData.value : modelData
                readonly property string rowText: modelData ? (modelData.text || modelData.label || String(rowValue)) : ""

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowText
                    font.family: Commons.Theme.fontUI
                    font.pixelSize: 12
                    color: root.cText
                }

                MouseArea {
                    id: itemMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: 1
                    onClicked: {
                        root.itemSelected(rowValue);
                    }
                }
            }
        }
    }

    function open(parentItem, container) {
        var count = model ? model.length : 0;
        var calcHeight = Math.min(maxListHeight, count * itemHeight + padding);

        var buttonPos = parentItem.mapToItem(container, 0, 0);
        var buttonBottom = buttonPos.y + parentItem.height;
        var availableBelow = container.height - buttonBottom - 8;
        var availableAbove = buttonPos.y - 8;
        var showAbove = availableBelow < calcHeight && availableAbove > availableBelow;
        var space = showAbove ? availableAbove : availableBelow;
        var finalHeight = Math.min(calcHeight, space);

        root.x = Math.max(8, Math.min(buttonPos.x, container.width - popupWidth - 8));
        if (showAbove) {
            root.y = Math.max(8, buttonPos.y - finalHeight - 4);
        } else {
            root.y = Math.min(buttonBottom + 4, container.height - finalHeight - 8);
        }
        root.height = finalHeight;
        root.visible = true;
    }

    function hide() {
        root.visible = false;
    }
}
