import QtQuick
import qs.modules.common

// The small heading over a row of EditPickKeys: the word (STYLE, POSITION...),
// then, paler, the name of what is picked, or of what the pointer is over.
Row {
    id: head

    property string title: ""
    property string value: ""

    spacing: 8

    Text {
        text: head.title
        color: Theme.pInk
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.ExtraBold
        font.styleName: Theme.fontStyleBold
        font.letterSpacing: 1.2
    }

    Text {
        text: head.value
        color: Theme.pInkSub
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }
}
