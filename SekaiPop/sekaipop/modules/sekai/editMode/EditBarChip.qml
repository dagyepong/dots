import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// One module of the bar as a little keycap, on Edit Desktop's BAR tab
// (EditBarLayout.qml): its icon and its name.
//
//   drag     picks it up; the lane it would land in lights up and a mint
//            marker shows where (EditBarLayout.qml does the tracking)
//   click    on the bar: sends it to the next zone (left -> center -> right);
//            in the OFF lane: puts it back on the bar, in the zone it had
//   right click   takes it off the bar (into the OFF lane)
//
// `lifted` is the chip left behind in its lane while its copy is being
// dragged; `off` is a module in the OFF lane (drawn paler); `ghost` is the
// copy that follows the pointer.
Item {
    id: chip

    property string moduleId: ""
    property bool ghost: false
    property bool lifted: false
    property bool off: false
    // Just the icon, no label (the lanes switch to this when the labelled keycaps
    // would not fit; the name then shows in a tooltip, EditBarLayout.qml).
    property bool iconOnly: false
    // EditBarLayout.qml: where drags are reported to.
    property Item editor: null

    readonly property real chipH: 32

    readonly property real padW: 2 * (Theme.borderWidth + 3) + 18
    // Both widths are known whichever one is showing: the lanes size themselves by them.
    readonly property real iconWidth: Math.round(16 + chip.padW)
    readonly property real fullWidth: Math.round(16 + 6 + label.implicitWidth + chip.padW)

    width: chip.iconOnly ? chip.iconWidth : chip.fullWidth
    height: chip.chipH

    opacity: chip.ghost ? 0.96 : (chip.lifted ? 0.28 : (chip.off ? 0.7 : 1))
    scale: chip.ghost ? 1.06 : 1

    Gradient {
        id: ghostFill
        GradientStop { position: 0.0; color: Theme.accentMint }
        GradientStop { position: 1.0; color: Theme.accentCyan }
    }

    Pill {
        anchors.fill: parent
        cornerRadius: 10
        ringWidth: 3
        shadowDy: 3
        pressed: area.pressed && !chip.ghost
        fillColor: area.containsMouse && !chip.ghost ? Theme.pSurfaceHover : Theme.pSurface
        fillGradient: chip.ghost ? ghostFill : null

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: BarLayoutService.iconOf(chip.moduleId)
                size: 16
                weight: 600
                color: chip.ghost ? Theme.colBorder : Theme.pInk
            }

            Text {
                id: label
                visible: !chip.iconOnly
                anchors.verticalCenter: parent.verticalCenter
                text: BarLayoutService.labelOf(chip.moduleId)
                color: chip.ghost ? Theme.colBorder : Theme.pInk
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.ExtraBold
                font.styleName: Theme.fontStyleBold
            }
        }
    }

    Component.onDestruction: {
        if (chip.editor)
            chip.editor.hideTip(chip.moduleId)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: !chip.ghost && chip.editor !== null
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.OpenHandCursor

        property real startX: 0
        property real startY: 0
        property bool moved: false

        onContainsMouseChanged: {
            if (!chip.editor || !chip.iconOnly)
                return
            if (area.containsMouse)
                chip.editor.showTip(chip.moduleId, chip)
            else
                chip.editor.hideTip(chip.moduleId)
        }

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                chip.editor.remove(chip.moduleId)
                return
            }
            area.startX = mouse.x
            area.startY = mouse.y
            area.moved = false
        }

        onPositionChanged: mouse => {
            if (!area.pressed || !(area.pressedButtons & Qt.LeftButton))
                return
            if (!area.moved && Math.abs(mouse.x - area.startX) + Math.abs(mouse.y - area.startY) < 8)
                return
            const p = area.mapToItem(chip.editor, mouse.x, mouse.y)
            if (!area.moved) {
                area.moved = true
                chip.editor.beginDrag(chip.moduleId, area.startX, area.startY)
            }
            chip.editor.track(p.x, p.y)
        }

        onReleased: mouse => {
            if (mouse.button !== Qt.LeftButton)
                return
            if (area.moved)
                chip.editor.endDrag()
            else
                chip.editor.nudge(chip.moduleId)
            area.moved = false
        }

        onCanceled: {
            if (area.moved)
                chip.editor.cancelDrag()
            area.moved = false
        }
    }
}
