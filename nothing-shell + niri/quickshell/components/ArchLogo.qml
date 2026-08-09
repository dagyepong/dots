// Gentoo logo as vector geometry. Authored in a 256x256 box matching the shell's icon scale.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: root
    property color color: Config.accent

    implicitWidth: 22
    implicitHeight: 22

    Shape {
        anchors.centerIn: parent
        width: 256
        height: 256
        scale: Math.min(root.width, root.height) / 256
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            // Gentoo swirl vector path normalized to the 256x256 container space
            PathSvg { path: "M128 0C57.308 0 0 57.308 0 128s57.308 128 128 128 128-57.308 128-128S198.692 0 128 0zm0 39.385c49.034 0 88.615 39.581 88.615 88.615 0 20.354-6.953 39.112-18.598 54.02l-49.336-49.336v-14.77c0-11.96-9.67-21.631-21.631-21.631-11.96 0-21.631 9.67-21.631 21.631v63.139c-14.908-11.645-21.861-30.403-21.861-54.757 0-49.034 39.581-88.615 88.615-88.615z" }
        }
    }

    Behavior on color { ColorAnim {} }
}
