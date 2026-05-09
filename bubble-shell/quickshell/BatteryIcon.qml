import QtQuick
import QtQuick.Shapes

Item {
    id: root
    width: 20
    height: 12

    property real percent: 0
    property bool isCharging: false

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("battery.svg")
        sourceSize: Qt.size(width * 2, height * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Rectangle {
        x: 3
        y: 3
        width: Math.max(1, 13 * (root.percent / 100))
        height: 6
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
        }
        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
    }

    Shape {
        x: 6.5; y: 1.5
        width: 7; height: 9
        visible: root.isCharging
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: "black"
            PathSvg { path: "M3.61913 0.168477C3.68042 0.0912047 3.76564 0.0364817 3.86141 0.0129039C3.95718 -0.0106739 4.05807 -0.00177063 4.14823 0.0382153C4.23839 0.0782012 4.31271 0.147004 4.35952 0.233816C4.40633 0.320628 4.42298 0.420531 4.40684 0.517831L3.93733 3.33759H5.63693C5.72059 3.33757 5.80255 3.36114 5.87343 3.40558C5.94431 3.45002 6.00123 3.51354 6.03765 3.58885C6.07408 3.66417 6.08853 3.74822 6.07937 3.83138C6.07021 3.91453 6.03779 3.99342 5.98584 4.05899L2.46248 8.50936C2.40119 8.58664 2.31596 8.64136 2.22019 8.66494C2.12442 8.68852 2.02354 8.67961 1.93338 8.63963C1.84322 8.59964 1.7689 8.53084 1.72208 8.44403C1.67527 8.35721 1.65863 8.25731 1.67476 8.16001L2.14427 5.34025H0.444677C0.361056 5.34019 0.279146 5.31656 0.208334 5.27209C0.137522 5.22761 0.0806729 5.16408 0.0443019 5.08879C0.00793093 5.01349 -0.00649034 4.92947 0.00269085 4.84635C0.011872 4.76324 0.0442842 4.68439 0.0962128 4.61885L3.61913 0.168477Z" }
        }
    }
}
