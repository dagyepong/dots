import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.components
import qs.commons

Rectangle {
  id: container
  radius: ScalerService.s(Settings.appearance.radius2)
  color:  Qt.alpha(theme.primary.dim_background,0.6)
  border.color: theme.button.border
  border.width: Settings.appearance.enableBorder ? ScalerService.s(2) : 0

  property real animationProgress: 0
  property var apps: []
  property var allApps: []
  property string lastQuery: ""
  property int currentIndex: 0

  signal appLaunched

  Repeater {
    id: appRepeater
    model: DesktopEntries.applications

    Item {
      Component.onCompleted: {
        container.allApps.push({
            name: modelData.name || "",
            comment: modelData.comment || "",
            icon: modelData.icon || "",
            exec: modelData.execString || "",
            entry: modelData
        });
      }
    }
  }

  Component.onCompleted: {
    Qt.callLater(function () {
        container.allApps.sort(function (a, b) {
            return a.name.toLowerCase().localeCompare(b.name.toLowerCase());
        });
        container.apps = container.allApps;
    });
  }

  ColumnLayout {
    id: rootLayout
    anchors.fill: parent
    anchors.margins: ScalerService.s(8)
    spacing: ScalerService.s(6)

    ListView {
      id: appList
      Layout.fillWidth: true
      Layout.fillHeight: true
      clip: true
      spacing: ScalerService.s(4)
      model: container.apps
      currentIndex: container.currentIndex
      focus: true
      keyNavigationWraps: true

      delegate: Rectangle {
        width: ListView.view.width
        height: ScalerService.s(56)
        radius: ScalerService.s(Settings.appearance.radius3)
        color: (ListView.isCurrentItem || mouseArea.containsMouse) ? theme.button.background_select : "transparent"
        border.color: (ListView.isCurrentItem || mouseArea.containsMouse) ? theme.button.border_select : "transparent"
        border.width: Settings.appearance.enableBorder ? ScalerService.s(1) : 0

        opacity: 0

        SequentialAnimation on opacity {
          running: animationProgress > 0.5

          PauseAnimation {
            duration: index * 15
          }

          NumberAnimation {
            to: 1
            duration: 200
            easing.type: Easing.OutCubic
          }
        }

        RowLayout {
          anchors.fill: parent
          anchors.margins: ScalerService.s(8)
          spacing: ScalerService.s(10)

          Image {
            Layout.preferredWidth: ScalerService.s(36)
            Layout.preferredHeight: ScalerService.s(36)
            fillMode: Image.PreserveAspectFit
            source: modelData.icon ? "image://icon/" + modelData.icon : ""
            asynchronous: true
            opacity: 0

            SequentialAnimation on opacity {
              running: animationProgress > 0.6

              PauseAnimation {
                duration: index * 15
              }

              NumberAnimation {
                to: 1
                duration: 200
                easing.type: Easing.OutCubic
              }
            }
          }

          ColumnLayout {
            spacing: ScalerService.s(2)

            CustomText{
              name: modelData.name || "Unknown"
              size: "small"
              elide: Text.ElideRight
              opacity: 0

              SequentialAnimation on opacity {
                running: animationProgress > 0.7

                PauseAnimation {
                  duration: index * 15
                }

                NumberAnimation {
                  to: 1
                  duration: 200
                  easing.type: Easing.OutCubic
                }
              }
            }
            CustomText{
              name: modelData.comment || ""
              size: "xs"
              elide: Text.ElideRight
              textColor: theme.button.text
              opacity: 0

              SequentialAnimation on opacity {
                running: animationProgress > 0.8

                PauseAnimation {
                  duration: index * 15
                }

                NumberAnimation {
                  to: 1
                  duration: 200
                  easing.type: Easing.OutCubic
                }
              }

            }
          }
          Item{Layout.fillWidth: true}
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (modelData && modelData.entry) {
              modelData.entry.execute();
              VisibleService.closeAllPanels();
            }
          }
          onEntered: {
            if (ListView.view) {
              ListView.view.currentIndex = index;
            }
          }
        }
      }
    }

    CustomText{
      visible: container.apps.length === 0
      name: "Không có kết quả"
      anchors.centerIn: parent

    }
  }

  function runSearch(query) {
    if (query === undefined || query === null)
    query = "";
    container.lastQuery = query;

    if (query.length === 0) {
      container.apps = container.allApps;
      container.currentIndex = 0;
      return;
    }

    var q = query.toLowerCase();
    var filtered = [];

    for (var i = 0; i < container.allApps.length; i++) {
      var app = container.allApps[i];
      var name = (app.name || "").toLowerCase();
      var comment = (app.comment || "").toLowerCase();
      var exec = (app.exec || "").toLowerCase();

      // Tìm kiếm trong name, comment và exec
      var match = name.indexOf(q) >= 0 || comment.indexOf(q) >= 0 || exec.indexOf(q) >= 0;

      // Thêm tìm kiếm theo tên file từ exec (ví dụ: "firefox" từ "firefox %u")
      if (!match && exec) {
        // Tách exec để lấy tên file
        var execParts = exec.split(' ');
        if (execParts.length > 0) {
          var executableName = execParts[0];
          // Loại bỏ đường dẫn nếu có
          var lastSlash = executableName.lastIndexOf('/');
          if (lastSlash >= 0) {
            executableName = executableName.substring(lastSlash + 1);
          }
          match = executableName.toLowerCase().indexOf(q) >= 0;
        }
      }

      if (match) {
        filtered.push(app);
      }
    }

    container.apps = filtered;
    container.currentIndex = 0;
  }

  Shortcut {
    sequence: "Tab"
    onActivated: {
      container.currentIndex = (container.currentIndex + 1) % container.apps.length;
      appList.currentIndex = container.currentIndex;
    }
  }

  Shortcut {
    sequence: "Up"
    onActivated: {
      container.currentIndex = Math.max(container.currentIndex - 1, 0);
      appList.currentIndex = container.currentIndex;
    }
  }

  Shortcut {
    sequence: "Down"
    onActivated: {
      container.currentIndex = (container.currentIndex + 1) % container.apps.length;
      appList.currentIndex = container.currentIndex;
    }
  }

  Shortcut {
    sequence: "Return"
    onActivated: {
      if (container.apps.length > 0 && container.currentIndex < container.apps.length) {
        var item = container.apps[container.currentIndex];
        if (item && item.entry) {
          item.entry.execute();
          VisibleService.closeAllPanels();
        }
      }
    }
  }
}
