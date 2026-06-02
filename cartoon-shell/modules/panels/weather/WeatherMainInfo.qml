import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.commons
import qs.components
import "." as Com

Item {
  id: root
  property real animationProgress: 0

  RowLayout {
    anchors.fill: parent
    spacing: ScalerService.s(50)

    // Left Column - Current Weather
    Item {
      Layout.preferredWidth: parent.width/3
      Layout.fillHeight: true

      ColumnLayout {
        spacing: ScalerService.s(24)
        anchors.fill: parent
        anchors.topMargin: ScalerService.s(16)

        Com.WeatherCurrentInfo {
          animationProgress: root.animationProgress
        }

        Com.WeatherDateTimeInfo {
          animationProgress: root.animationProgress
        }

        Com.WeatherLocationInfo {
          animationProgress: root.animationProgress
        }

        Com.WeatherDetailsGrid {
          animationProgress: root.animationProgress
        }

        // Temperature Chart
        Com.TemperatureChart {
          Layout.preferredHeight: ScalerService.s(200)
          Layout.fillWidth: true
          Layout.topMargin: ScalerService.s(8)
          temperatures: [
          WeatherService.dataModel.forecast.forecastday[0].hour[0].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[2].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[4].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[6].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[8].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[10].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[12].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[14].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[16].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[18].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[20].temp_c,
          WeatherService.dataModel.forecast.forecastday[0].hour[22].temp_c
          ]
        }
      }
    }

    // Right Column - Forecast
    Item {
      Layout.fillHeight: true
      Layout.preferredWidth: parent.width/2

      ColumnLayout {
        anchors.fill: parent
        spacing: ScalerService.s(20)
        anchors.topMargin: ScalerService.s(16)

        // Header
        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: ScalerService.s(40)

          CustomText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: "Hourly Forecast"
            size: "large"
            isBold: true
            textColor: theme.primary.foreground
          }

          CustomText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            name: "7 Days"
            size: "small"
            textColor: theme.normal.cyan
            opacity: 0.8
          }
        }

        // Scrollable Forecast Cards
        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ScrollBar.vertical.policy: ScrollBar.AsNeeded

          ListView {
            id: forecastListView
            spacing: ScalerService.s(12)
            orientation: ListView.Vertical
            model: WeatherService.dataModel.forecast.forecastday

            delegate: Rectangle {
              width: ListView.view.width - ScalerService.s(20)
              height: ScalerService.s(100)
              radius: ScalerService.s(16)
              color: Qt.alpha(theme.button.background,0.4)
              opacity: 0.9

              RowLayout {
                anchors.fill: parent
                anchors.margins: ScalerService.s(12)
                spacing: ScalerService.s(12)

                // Left: Day info

                IconImage {
                  path: WeatherService.getWeatherIcon(modelData.day.condition.code)
                  size: "2xl"
                }
                ColumnLayout {
                  Layout.preferredWidth: ScalerService.s(60)
                  spacing: ScalerService.s(4)

                  CustomText {
                    name: getDayName(modelData.date)
                    size: "medium"
                    isBold: true
                    textColor: theme.primary.foreground
                  }

                  CustomText {
                    name: formatDate(modelData.date)
                    size: "xsmall"
                    textColor: theme.primary.dim_foreground
                  }
                }

                // Center: Weather icon and condition
                Item {
                  Layout.fillWidth: true
                  Layout.preferredHeight: ScalerService.s(50)

                  CustomText {
                    name: modelData.day.condition.text.length > 12
                    ? `${modelData.day.condition.text.slice(0, 12)}...`
                    : modelData.day.condition.text
                    textColor: theme.primary.dim_foreground
                  }
                }

                // Right: Temperature range
                ColumnLayout {
                  Layout.preferredWidth: ScalerService.s(70)
                  spacing: ScalerService.s(4)

                  // Max temp
                  CustomText {
                    name: `${Math.round(modelData.day.maxtemp_c)}°C`
                    size: "medium"
                    isBold: true
                    textColor: theme.normal.red
                  }

                  // Min temp

                  CustomText {
                    name: `${Math.round(modelData.day.mintemp_c)}°C`
                    size: "medium"
                    isBold: true
                    textColor: theme.normal.blue
                  }
                }
              }

              // Hover effect
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

              }
            }
          }
        }
      }
    }
  }

  // Helper functions
  function getDayName(dateString) {
    var date = new Date(dateString)
    const dayData = lang?.dateFormat?.day;
    const days = dayData
    ? [
    dayData.sunday || "Sunday",
    dayData.monday || "Monday",
    dayData.tuesday || "Tuesday",
    dayData.wednesday || "Wednesday",
    dayData.thursday || "Thursday",
    dayData.friday || "Friday",
    dayData.saturday || "Saturday"
    ]
    : [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday"
    ];
    return days[date.getDay()]
  }

  function formatDate(dateString) {
    var date = new Date(dateString)
    return `${date.getDate()}/${date.getMonth() + 1}`
  }
}
