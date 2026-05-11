import QtQuick 6.10
import QtQuick.Layouts 6.10
import "../../Commons" as Commons
import "../../Widgets" as Widgets

RowLayout {
    id: root

    property int monitorCount: 0
    property bool isLoading: false

    readonly property color cPrimary: Commons.Theme.secondary
    readonly property color cSubText: Qt.rgba(Commons.Theme.foreground.r, Commons.Theme.foreground.g, Commons.Theme.foreground.b, 0.6)

    signal refreshClicked

    spacing: 12

    Widgets.HeaderWithIcon {
        icon: "󰍹"
        title: "Display Management"
        subtitle: root.isLoading ? "Loading..." : (root.monitorCount > 0 ? root.monitorCount + " display(s)" : "No displays")
        iconColor: root.cPrimary
    }

    Item { Layout.fillWidth: true }

    Widgets.IconButton {
        width: 32
        height: 32
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        icon: "󰑓"
        iconSize: 14
        iconColor: root.cSubText
        hoverIconColor: root.cPrimary
        baseColor: "transparent"
        hoverColor: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.15)
        onClicked: {
            root.refreshClicked();
        }
    }
}
