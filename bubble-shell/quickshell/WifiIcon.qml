import QtQuick
import QtQuick.Shapes

Item {
    id: root
    width: 20
    height: 16
    clip: true

    property int signalLevel: 0
    readonly property real _activeAlpha: 1.0
    readonly property real _dimAlpha: 0.3

    // SVG coords are in a 40×36 viewBox; anchor at (-11,-10) to fit the 20×16 container.
    component WifiArc: Shape {
        x: -11
        y: -10
        width: 40
        height: 36
        preferredRendererType: Shape.CurveRenderer
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }

    component WifiArcPath: ShapePath {
        strokeColor: "transparent"
        fillRule: ShapePath.WindingFill
        fillGradient: LinearGradient {
            x1: 20; y1: 11.7148
            x2: 20; y2: 24.3189
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
        }
    }

    WifiArc {
        opacity: root.signalLevel >= 3 ? root._activeAlpha : root._dimAlpha
        WifiArcPath {
            PathSvg { path: "M13.2749 16.4667C12.8166 16.85 12.1416 16.8084 11.7166 16.3834C11.2166 15.8834 11.2582 15.0667 11.7999 14.6333C16.5666 10.7417 23.4499 10.7417 28.2082 14.6333C28.7499 15.075 28.7832 15.8917 28.2916 16.3834C27.8666 16.8084 27.1832 16.8417 26.7166 16.4583C22.8166 13.2667 17.1666 13.2667 13.2749 16.4667Z" }
        }
    }

    WifiArc {
        opacity: root.signalLevel >= 2 ? root._activeAlpha : root._dimAlpha
        WifiArcPath {
            PathSvg { path: "M16.6001 19.8502C16.1251 20.1919 15.4834 20.1502 15.0751 19.7419C14.5667 19.2335 14.6001 18.3919 15.1751 17.9752C18.0501 15.9002 21.9584 15.9002 24.8251 17.9752C25.4001 18.3835 25.4334 19.2335 24.9334 19.7335L24.9251 19.7419C24.5167 20.1502 23.8751 20.1835 23.4001 19.8502C22.4061 19.1463 21.2181 18.7683 20.0001 18.7683C18.7821 18.7683 17.5941 19.1463 16.6001 19.8502Z" }
        }
    }

    WifiArc {
        opacity: root.signalLevel >= 1 ? root._activeAlpha : root._dimAlpha
        WifiArcPath {
            PathSvg { path: "M18.1831 22.8502L19.4081 24.0752C19.7331 24.4002 20.2581 24.4002 20.5831 24.0752L21.8081 22.8502C22.1998 22.4585 22.1165 21.7835 21.6165 21.5252C21.1124 21.2663 20.5539 21.1313 19.9873 21.1313C19.4207 21.1313 18.8622 21.2663 18.3581 21.5252C17.8831 21.7835 17.7915 22.4585 18.1831 22.8502Z" }
        }
    }
}
