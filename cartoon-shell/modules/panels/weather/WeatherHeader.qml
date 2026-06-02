import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

Item {
  id: headerCard

  IconText{
    anchors.left: parent.left
    name:"settings"
    rotation: mouseArea.containsMouse ? 90 : 0
    Behavior on rotation {
      NumberAnimation {
        duration: 200
      }
    }
    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onClicked: {
      }
    }
  }

  CustomText {
    name: lang?.weather?.title || "Thời Tiết"
    size: "large"
    isBold: true
    anchors.centerIn: parent
  }
  CloseButton{
    onClicked: VisibleService.togglePanel("weather")
  }
}
