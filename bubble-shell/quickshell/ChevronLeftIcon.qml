import QtQuick

Image {
    width: 16
    height: 16
    source: Qt.resolvedUrl("chevron-left.svg")
    sourceSize: Qt.size(width * 2, height * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
}
