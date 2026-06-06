import "../../core"
import "../../widgets"
import "../../core/functions" as Functions
import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property int itemIndex: 0
    property bool current: false
    property bool selected: false
    property string title: ""
    property string path: ""
    property string preview: ""
    property string typeLabel: "PIC"
    property real expandedWidth: 560
    property real sliceWidth: 116
    property real sliceHeight: 420
    property real skewOffset: 34
    property real cornerRadius: 0
    property color accent: Appearance.colors.colPrimary
    property color surface: Appearance.colors.colLayer1
    property bool dimmed: false

    signal activated()
    signal selectedRequested()

    width: current ? expandedWidth : sliceWidth
    height: sliceHeight
    z: current ? 100 : (hover.hovered ? 90 : 60 - Math.abs(itemIndex))
    scale: hover.hovered ? 1.018 : 1
    opacity: dimmed ? 0.32 : 1

    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    readonly property real skAbs: Math.abs(skewOffset)
    readonly property real topLeft: skewOffset >= 0 ? skAbs : 0
    readonly property real topRight: skewOffset >= 0 ? width : width - skAbs
    readonly property real bottomRight: skewOffset >= 0 ? width - skAbs : width
    readonly property real bottomLeft: skewOffset >= 0 ? 0 : skAbs

    Item {
        id: shadow
        anchors.fill: parent
        x: root.current ? 5 : 2
        y: root.current ? 12 : 5
        opacity: root.current ? 0.42 : 0.24
        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#000000"
                strokeColor: "transparent"
                startX: root.topLeft
                startY: 0
                PathLine { x: root.topRight; y: 0 }
                PathLine { x: root.bottomRight; y: root.height }
                PathLine { x: root.bottomLeft; y: root.height }
                PathLine { x: root.topLeft; y: 0 }
            }
        }
    }

    Item {
        id: maskItem
        anchors.fill: parent
        visible: true
        opacity: 0
        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "white"
                strokeColor: "transparent"
                startX: root.topLeft
                startY: 0
                PathLine { x: root.topRight; y: 0 }
                PathLine { x: root.bottomRight; y: root.height }
                PathLine { x: root.bottomLeft; y: root.height }
                PathLine { x: root.topLeft; y: 0 }
            }
        }
    }

    Item {
        id: imageClip
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask { maskSource: maskItem }

        Rectangle {
            anchors.fill: parent
            color: root.surface
        }

        Image {
            anchors.fill: parent
            source: root.preview
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: root.current ? 960 : 360
            sourceSize.height: root.current ? 540 : 640
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, root.current ? 0.04 : 0.24) }
                GradientStop { position: 0.62; color: Qt.rgba(0, 0, 0, root.current ? 0.08 : 0.42) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.accent
            opacity: hover.hovered ? 0.14 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.selected ? root.accent : (hover.hovered ? Functions.ColorUtils.applyAlpha(root.accent, 0.70) : Functions.ColorUtils.applyAlpha(Appearance.m3colors.m3onSurface, 0.30))
            strokeWidth: root.selected ? 3 : (root.current ? 2 : 1)
            startX: root.topLeft
            startY: 0
            PathLine { x: root.topRight; y: 0 }
            PathLine { x: root.bottomRight; y: root.height }
            PathLine { x: root.bottomLeft; y: root.height }
            PathLine { x: root.topLeft; y: 0 }
        }
    }

    Rectangle {
        id: typeBadge
        x: root.skewOffset >= 0 ? root.width - width - root.skAbs - 10 : root.skAbs + 10
        y: 12
        width: label.implicitWidth + 16
        height: 22
        radius: 0
        color: Qt.rgba(0, 0, 0, 0.62)
        border.width: 1
        border.color: Functions.ColorUtils.applyAlpha(root.accent, 0.48)
        visible: root.current || hover.hovered

        StyledText {
            id: label
            anchors.centerIn: parent
            text: root.typeLabel
            color: root.accent
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Bold
        }
    }

    StyledText {
        id: titleText
        x: root.skewOffset >= 0 ? root.skAbs + 18 : 18
        width: parent.width - root.skAbs - 36
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.current ? 28 : 20
        text: root.title.replace(/\.[^.]+$/, "")
        color: "white"
        font.pixelSize: root.current ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.smallest
        font.weight: root.current ? Font.DemiBold : Font.Medium
        elide: Text.ElideRight
        horizontalAlignment: root.current ? Text.AlignLeft : Text.AlignHCenter
        opacity: root.current ? 1 : 0.88
    }

    Rectangle {
        x: root.skewOffset >= 0 ? root.skAbs + 18 : 18
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        width: root.current ? Math.min(120, root.width - root.skAbs - 36) : 0
        height: 3
        radius: height / 2
        color: root.selected ? root.accent : Functions.ColorUtils.applyAlpha(Appearance.colors.colSecondary, 0.78)
        visible: root.current
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.current) root.selectedRequested();
            else root.activated();
        }
    }
}
