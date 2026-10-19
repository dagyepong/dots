import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sekai.quickPanel

// One pinned app, as a small key on Edit Desktop's DOCK tab (APPS group). Lit with the
// accent gradient while the app is ON the dock; off, the key is plain and the icon is
// faded. A click switches it (PinnedAppsService.toggleHidden): the app stays pinned
// either way, it just has no key on the dock while it is off.
//
//   EditAppKey { iconName: "firefox"; on: ...; onPicked: ... }
//
// `hovered` lets the owner show the app's name under the pointer.
Item {
    id: ak

    property string iconName: ""
    property bool on: true

    signal picked()

    readonly property bool hovered: akArea.containsMouse

    width: 40
    height: 40

    Gradient {
        id: akFill
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }

    Pill {
        anchors.fill: parent
        cornerRadius: 12
        ringWidth: 3
        shadowDy: 3
        pressed: akArea.pressed
        fillColor: ak.hovered && !ak.on ? Theme.pSurfaceHover : Theme.pSurface
        fillGradient: ak.on ? akFill : null

        Image {
            anchors.centerIn: parent
            width: 24
            height: 24
            opacity: ak.on ? 1 : 0.35
            source: IconCursorService.path(ak.iconName, "application-x-executable")
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            sourceSize: Qt.size(48, 48)

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        id: akArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: ak.picked()
    }
}
