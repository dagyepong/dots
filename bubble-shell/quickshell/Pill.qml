import QtQuick
import QtQuick.Shapes

Item {
    id: pill

    property int collapsedWidth: 80
    property int expandedWidth: 140
    property int pillHeight: 48
    readonly property int padding: 18
    readonly property bool hovered: mouseArea.containsMouse

    property int activeWidth: -1
    property int activeHeight: -1
    property real activeCornerRadius: -1
    readonly property bool expanded: activeHeight > 0

    // When alpha > 0, overrides the default fill and suppresses the hover glow.
    property color themeColor: Qt.rgba(0, 0, 0, 0)
    readonly property bool _themed: themeColor.a > 0.01

    property bool interactive: true
    property int animationDuration: 350
    property bool animateShader: true
    property bool shaderEnabled: true

    property color restFill1:  Qt.rgba(1, 1, 1, 0.04)
    property color restFill2:  Qt.rgba(1, 1, 1, 0.10)
    property color hoverFill1: Qt.rgba(0.447, 0.373, 0.498, 0.25)
    property color hoverFill2: Qt.rgba(0.031, 0.302, 0.631, 0.25)

    property bool glowEnabled: true

    signal clicked()

    default property alias contentData: contentContainer.data

    implicitWidth: activeWidth > 0 ? activeWidth : (hovered ? expandedWidth : collapsedWidth)
    implicitHeight: activeHeight > 0 ? activeHeight : pillHeight
    clip: true

    Behavior on implicitWidth {
        NumberAnimation { duration: pill.animationDuration; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: pill.animationDuration; easing.type: Easing.OutCubic }
    }

    property real _cornerRadius: activeCornerRadius > 0 ? activeCornerRadius : height / 2
    Behavior on _cornerRadius {
        NumberAnimation { duration: pill.animationDuration; easing.type: Easing.OutCubic }
    }

    ShaderEffect {
        id: fillShader
        anchors.fill: parent
        visible: pill.shaderEnabled

        property size  iSize:        Qt.size(width, height)
        property real  cornerRadius: pill._cornerRadius

        property color fillColor1: pill._themed
            ? Qt.rgba(pill.themeColor.r, pill.themeColor.g, pill.themeColor.b, 0.25)
            : (pill.expanded
                ? Qt.rgba(0.447, 0.373, 0.498, 0.25)
                : pill.hovered
                    ? pill.hoverFill1
                    : pill.restFill1)
        property color fillColor2: pill._themed
            ? Qt.rgba(pill.themeColor.r, pill.themeColor.g, pill.themeColor.b, 0.50)
            : (pill.expanded
                ? Qt.rgba(0.031, 0.302, 0.631, 0.25)
                : pill.hovered
                    ? pill.hoverFill2
                    : pill.restFill2)

        // Named `glowAmber` to match the shader uniform; the actual color is blue.
        property color glowAmber: pill._themed
            ? Qt.rgba(0, 0, 0, 0)
            : Qt.rgba(0.349, 0.557, 1.0, 0.12)
        property color glowWhite: Qt.rgba(1.000, 1.000, 1.000, 0.06)
        property real  glowRadius: pill.expanded ? 12.0 : 15.0
        property real  glowIntensity: pill.glowEnabled
            ? (pill.expanded ? 0.5 : (pill.hovered ? 1.0 : 0.0))
            : 0.0

        Behavior on fillColor1    { enabled: pill.animateShader; ColorAnimation  { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on fillColor2    { enabled: pill.animateShader; ColorAnimation  { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on glowIntensity { enabled: pill.animateShader; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on glowRadius    { enabled: pill.animateShader; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        fragmentShader: Qt.resolvedUrl("pill.frag.qsb")
    }

    Shape {
        id: borderRing
        anchors.fill: parent
        visible: pill.shaderEnabled

        ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                x1: 0.870 * borderRing.width
                y1: 0.146 * borderRing.height
                x2: 0.586 * borderRing.width
                y2: 1.287 * borderRing.height
                GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.00) }
                GradientStop { position: 0.78; color: Qt.rgba(1, 1, 1, 0.00) }
                GradientStop { position: 1.0;  color: Qt.rgba(1, 1, 1, 0.07) }
            }
            PathRectangle {
                x: 0; y: 0
                width: borderRing.width
                height: borderRing.height
                radius: pill._cornerRadius
            }
            PathRectangle {
                x: 2; y: 2
                width: borderRing.width - 4
                height: borderRing.height - 4
                radius: Math.max(0, pill._cornerRadius - 2)
            }
        }
    }

    // Below content so child MouseAreas get click priority.
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: pill.interactive && !pill.expanded
        acceptedButtons: pill.interactive && !pill.expanded ? Qt.LeftButton : Qt.NoButton
        onClicked: pill.clicked()
    }

    Item {
        id: contentContainer
        anchors.fill: parent
    }
}
