import QtQuick

Image {
    width: 20
    height: 20
    source: Qt.resolvedUrl("sleep.svg")
    sourceSize: Qt.size(width * 2, height * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
}
