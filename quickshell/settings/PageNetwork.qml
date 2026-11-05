import QtQuick
import qs.pages

// The whole page is the WifiPage, stretched to fill it
Item {
    WifiPage {
        anchors.fill: parent
        anchors.margins: 14
        embedded: true
    }
}
