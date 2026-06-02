import QtQuick
import qs.services
import qs.commons

Text {
  property string name: "undefined"

  // xs | small | normal | large | xl
  property string size: "normal"

  property bool isBold: false
  property color textColor: theme.primary.foreground
  property string fontFamily: Settings.appearance.font
  Behavior on opacity {
    NumberAnimation {
      duration: 200
    }
  }
  Behavior on font.bold {
    PropertyAnimation {
      duration: 150
    }
  }
  Behavior on scale {
    NumberAnimation {
      duration: 200
    }
  }
  Behavior on font.pixelSize {
    ColorAnimation {
      duration: 200
    }
  }

  Behavior on rotation {
    NumberAnimation {
      duration: 500
    }
  }

  text: name
  color: textColor

  font.family: fontFamily
  font.bold: isBold

  font.pixelSize: {
    switch (size) {
      case "4sx":
      return ScalerService.s(4)
      case "2xs":
      return ScalerService.s(8)
      case "xs":
      return ScalerService.s(12)

      case "small":
      return ScalerService.s(16)

      case "normal":
      return ScalerService.s(24)

      case "large":
      return ScalerService.s(32)

      case "xl":
      return ScalerService.s(40)

      case "2xl":
      return ScalerService.s(48)
      case "3xl":
      return ScalerService.s(70)

      case "4xl":
      return ScalerService.s(100)

      default:
      return ScalerService.s(32)
    }
  }
}
