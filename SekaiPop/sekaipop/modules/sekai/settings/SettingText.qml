import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// A line of text to type, in the Settings Panel's style: a name on the left and a
// keycap-like field to its right, full width of its row. Enter (or leaving the
// field) sends `submitted`; the button on the right sends `cleared` (when
// `clearable`). Escape puts the old text back.
//
//   SettingText {
//       label: "Location"
//       sublabel: "Type your city"
//       value: SettingsService.get("weather.location")
//       placeholder: "automatic (from your IP)"
//       onSubmitted: text => SettingsService.set("weather.location", text)
//   }
Item {
    id: root

    property string label: ""
    property string sublabel: ""
    property string value: ""
    property string placeholder: ""
    property bool clearable: true
    property real labelWidth: 196

    signal submitted(string text)
    signal cleared()

    width: parent ? parent.width : 600
    height: Math.max(labelColumn.implicitHeight, 58)

    Column {
        id: labelColumn
        y: Math.max(0, (root.height - implicitHeight) / 2)
        width: root.labelWidth - 14
        spacing: 2

        Text {
            width: parent.width
            text: root.label
            color: Theme.pInk
            font.family: Theme.fontFamily
            font.pixelSize: 18
            font.weight: Font.ExtraBold
            font.styleName: Theme.fontStyleBold
            wrapMode: Text.WordWrap
        }
        Text {
            visible: root.sublabel !== ""
            width: parent.width
            text: root.sublabel
            color: Theme.pInkSub
            font.family: Theme.fontFamily
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
    }

    // The field: the Pill look (outline, hard shadow) the rest of the panel uses.
    Pill {
        id: field
        x: root.labelWidth
        y: Math.max(0, (root.height - height) / 2)
        width: root.width - root.labelWidth - (root.clearable ? 58 : 0)
        height: 46 + Theme.shadowOffset
        cornerRadius: 16
        ringWidth: 4
        fillColor: Theme.pSurface

        MouseArea {
            anchors.fill: parent
            onPressed: input.forceActiveFocus()
        }

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            selectByMouse: true
            text: root.value
            color: Theme.pInk
            selectionColor: Theme.accentCyan
            selectedTextColor: Theme.colBorder
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold

            onAccepted: {
                root.submitted(input.text.trim())
                input.focus = false
            }
            Keys.onEscapePressed: {
                input.text = root.value
                input.focus = false
            }
            onActiveFocusChanged: {
                if (!activeFocus && input.text.trim() !== root.value)
                    root.submitted(input.text.trim())
            }

            Text {
                visible: input.text === "" && !input.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                text: root.placeholder
                color: Theme.pInkSub
                font: input.font
            }
        }
    }

    // Back to the default (empty).
    SettingRoundButton {
        visible: root.clearable
        x: field.x + field.width + 12
        y: Math.max(0, (root.height - height) / 2)
        icon: "close"
        enabled: root.value !== ""
        opacity: enabled ? 1 : 0.4
        onClicked: {
            input.text = ""
            root.cleared()
        }
    }

    // The saved value changed from elsewhere.
    onValueChanged: if (!input.activeFocus) input.text = root.value
}
