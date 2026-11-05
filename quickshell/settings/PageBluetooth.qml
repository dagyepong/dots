import QtQuick
import qs.pages

// The whole page is the BluetoothPage, stretched to fill it
Item {
    BluetoothPage {
        anchors.fill: parent
        anchors.margins: 14
        embedded: true
    }
}
