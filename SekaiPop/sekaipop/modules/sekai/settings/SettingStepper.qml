import QtQuick
import qs.modules.common.widgets
import qs.modules.sekai.quickPanel

// A number you nudge with − and +: a SekaiTile (the same footprint as a
// toggle, so they line up in a grid) with the name and the current value on
// the left and two diamond buttons on the right. Holding either repeats.
//
// Pure UI: `value` goes in, moved(value) comes out, already clamped to
// from..to and rounded to `step`.
SekaiTile {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property int decimals: 0
    property string suffix: ""
    // Shown instead of the number at one value (e.g. 0 -> "Off").
    property real specialValue: NaN
    property string specialText: ""

    signal moved(real value)

    function ancestorTileWidth() {
        for (let p = root.parent; p; p = p.parent) {
            if (p.tileWidth !== undefined && p !== root)
                return p.tileWidth
        }
        return 300
    }

    function nudge(dir) {
        const v = Math.max(root.from, Math.min(root.to, Number((root.value + dir * root.step).toFixed(6))))
        if (v !== root.value)
            root.moved(v)
    }

    readonly property string valueText: (!isNaN(specialValue) && Math.abs(value - specialValue) < 1e-6 && specialText !== "")
        ? specialText : value.toFixed(decimals) + suffix

    tileWidth: ancestorTileWidth()
    clickable: false
    subtitle: valueText
    textRightPad: 118

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        SettingRoundButton {
            icon: "remove"
            size: 40
            autoRepeat: true
            onClicked: root.nudge(-1)
        }

        SettingRoundButton {
            icon: "add"
            size: 40
            autoRepeat: true
            onClicked: root.nudge(1)
        }
    }
}
