import QtQuick

Item {
    id: root
    width: 12
    height: 12

    component Dot: Rectangle {
        width: 5
        height: 5
        radius: 2.5
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.9) }
        }
    }

    Dot { x: 0; y: 0 }
    Dot { x: 7; y: 0 }
    Dot { x: 0; y: 7 }
    Dot { x: 7; y: 7 }
}
