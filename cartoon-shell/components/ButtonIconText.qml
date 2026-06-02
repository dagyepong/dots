import QtQuick
import qs.services

Item {
  id: root

  // Properties
  property string name: "undefined"
  property string size: "normal"  // xs | small | normal | large | xl
  property color textColor: theme.primary.foreground
  property string fontFamily: "Material Symbols Rounded"

  // Fixed size based on the maximum (hovered) size
  implicitWidth: maxSize
  implicitHeight: maxSize

  // Calculate max size to prevent layout shifting
  readonly property int maxSize: {
    switch (size) {
      case "xs": return ScalerService.s(20)     // Max hovered size
      case "small": return ScalerService.s(26)  // Max hovered size
      case "normal": return ScalerService.s(40) // Max hovered size
      case "large": return ScalerService.s(58)  // Max hovered size
      case "xl": return ScalerService.s(72)     // Max hovered size
      default: return ScalerService.s(46)       // Max hovered size
    }
  }

  Text {
    id: iconText
    anchors.centerIn: parent

    // Font configuration
    font.variableAxes: { "FILL": 1 }
    renderType: Text.NativeRendering
    font.family: root.fontFamily

    // Bind to root properties
    text: root.name
    color: root.hovered ? Qt.lighter(root.textColor, 1.2) : root.textColor

    // Smooth animations
    Behavior on font.pixelSize {
      NumberAnimation {
        duration: 150
        easing.type: Easing.OutQuad
      }
    }
    Behavior on rotation {
      NumberAnimation {
        duration: 500
        easing.type: Easing.OutQuad
      }
    }

    Behavior on color {
      ColorAnimation { duration: 150 }
    }

    // Dynamic pixel size based on hover state
    font.pixelSize: {
      switch (root.size) {
        case "xs":
        return mouseArea.containsMouse ? ScalerService.s(20) : ScalerService.s(16)
        case "small":
        return mouseArea.containsMouse ? ScalerService.s(26) : ScalerService.s(22)
        case "normal":
        return mouseArea.containsMouse ? ScalerService.s(42) : ScalerService.s(38)
        case "large":
        return mouseArea.containsMouse ? ScalerService.s(58) : ScalerService.s(52)
        case "xl":
        return mouseArea.containsMouse ? ScalerService.s(72) : ScalerService.s(64)
        default:
        return mouseArea.containsMouse ? ScalerService.s(46) : ScalerService.s(40)
      }
    }

  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: {
      root.clicked()
    }
  }

  signal clicked()
}
