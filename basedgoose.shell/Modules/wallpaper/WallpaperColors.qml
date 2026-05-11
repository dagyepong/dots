pragma Singleton

import QtQuick 6.10
import "../../Commons" as Commons

QtObject {
    readonly property color surface: Commons.Theme.background
    readonly property color surfaceContainer: Qt.lighter(Commons.Theme.background, 1.15)
    readonly property color primary: Commons.Theme.secondary
    readonly property color text: Commons.Theme.foreground
    readonly property color subText: Qt.rgba(text.r, text.g, text.b, 0.6)
    readonly property color border: Qt.rgba(text.r, text.g, text.b, 0.08)
    readonly property color hover: Qt.rgba(text.r, text.g, text.b, 0.06)
}