import QtQuick
import QtQuick.Layouts
import qs.services

Item {
  id: root

  property string panelName: ""

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: VisibleService.togglePanel(root.panelName)
    onEntered: root.opacity = 0.8
    onExited: root.opacity = 1.0
  }

  Behavior on opacity {
    NumberAnimation {
      duration: 100
    }
  }
}
