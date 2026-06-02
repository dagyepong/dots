import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.components
import qs.commons
import "./panel/" as Com

Item {
  id: root
  ScrollView {
    id: scrollView
    anchors.fill: parent
    clip: true
    anchors.margins: ScalerService.s(20)

    ScrollBar.vertical.policy: ScrollBar.AsNeeded
    ScrollBar.horizontal.policy: ScrollBar.AsNeeded

    ColumnLayout {
      width: scrollView.availableWidth
      spacing: ScalerService.s(25)

      // Header
      HeaderSettings {
        name: root.lang?.appearance?.panel || "Panel"
      }

      // Separator
      Rectangle {
        Layout.fillWidth: true
        height: ScalerService.s(1)
        color: theme.primary.foreground
        opacity: 0.2
        Layout.bottomMargin: ScalerService.s(5)
      }

      // Panel Position Settings
      Com.PanelPositionSelector{}
      Com.Border{}
      Com.PanelSystemStats{}

      // Spacer
      Item {
        Layout.fillHeight: true
        Layout.minimumHeight: ScalerService.s(20)
      }
    }
  }
}
