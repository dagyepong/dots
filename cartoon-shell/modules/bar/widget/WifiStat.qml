import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.commons

RowLayout {
  id: root

  NetworkService {
    id: networkService
  }
  property int style: Settings.bar.wifi.style
  property var nameIcon1: ""
  property var nameIcon2: ""
  property var pathIcon: ""
  spacing: ScalerService.s(2)
  IconImage {
    visible: root.style === 1
    path: networkService.wifi_icon
    size: "large"
  }
  IconText{
    visible: root.style === 2
    name: networkService.wifi_icon_text_1
    textColor: theme.button.text
  }
  IconText{
    visible: root.style === 3
    name: networkService.wifi_icon_text_2
    textColor: theme.button.text
  }

}
