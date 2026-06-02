import qs.components
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.commons

Item {
  property real animationProgress: 0
  ColumnLayout {
    anchors.fill: parent
    spacing: ScalerService.s(8)
    anchors.margins: ScalerService.s(10)
    Item {
      id: timeContainerVertical
      Layout.fillWidth: true
      Layout.preferredHeight: ScalerService.s(50)

      // Xoay container để hiển thị theo chiều dọc
      Item {
        anchors.centerIn: parent
        implicitWidth: parent.width
        implicitHeight: parent.height

        ColumnLayout {
          id: contenTime
          spacing: ScalerService.s(2)

          CustomText {
            name: DateTimeService.currentHour
            isBold: true
          }
          CustomText {
            name: DateTimeService.currentMinus
            isBold: true
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          VisibleService.togglePanel("calendar");
        }
      }
    }
    Item {
      id: weatherContainerVertical
      Layout.fillWidth: true
      Layout.fillHeight: true

      // Xoay container để hiển thị theo chiều dọc
      Item {
        anchors.centerIn: parent
        implicitWidth: parent.width
        implicitHeight: parent.height
        transformOrigin: Item.Center

        ColumnLayout {
          anchors.centerIn: parent
          spacing: ScalerService.s(8)

          IconImage {
            path: WeatherService.getWeatherIcon(
              WeatherService.dataModel.current.condition.code,
              WeatherService.dataModel.current.is_day
            )
            Layout.alignment: Qt.AlignHCenter
          }

          ColumnLayout {
            spacing: ScalerService.s(1)
            CustomText {
              name: `${WeatherService.dataModel.current.temp_c}°C` || "Đang tải..."
              Layout.alignment: Qt.AlignHCenter
              size: "xs"
            }
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          VisibleService.togglePanel("weather");
        }

        onEntered: {
          weatherContainerVertical.opacity = 0.8;
        }
        onExited: {
          weatherContainerVertical.opacity = 1.0;
        }
      }

      Behavior on opacity {
        NumberAnimation {
          duration: 100
        }
      }
    }

    // Flag ở trên cùng
    Item {
      id: flagContainer
      Layout.preferredWidth: ScalerService.s(32)
      Layout.fillHeight: parent

      ButtonIconImage{
        path:  `flags/${root.selectedFlag}.png`
        size: "large"
        anchors.centerIn: parent
        onClicked: VisibleService.togglePanel("flag");
      }
    }
  }
}
