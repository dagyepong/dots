import QtQuick
import qs.pages

// The whole page is the SoundPage, stretched to fill it
Item {
    SoundPage {
        anchors.fill: parent
        anchors.margins: 14
        embedded: true
    }
}
