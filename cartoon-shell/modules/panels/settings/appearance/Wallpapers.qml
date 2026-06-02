import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.services
import qs.commons

Item {
  id: systemSettings
  property string homePath: ""
  property string wallpapersPath: ""
  property string wallpaperPath: ""
  property string currentWallpaper: ""
  property int currentScreenIndex: 0
  property var currentScreen: Quickshell.screens[currentScreenIndex] || null

  // Process để lấy home directory
  Process {
    id: getHomeProcess
    command: ["bash", "-c", "echo $HOME"]
    running: true
    stdout: StdioCollector {
      id: homeOutput
      onTextChanged: {
        if (text) {
          var path = text.trim();
          systemSettings.homePath = path;
          systemSettings.wallpapersPath = "file://" + path + "/Pictures/Wallpapers/";
        }
      }
    }
  }

  // Process để set wallpaper
  Process {
    id: wallpaperProcess

    stdout: StdioCollector {
      onTextChanged: {}
    }

    onRunningChanged: {
      if (!running) {
        currentWallpaper = wallpaperPath;
        showNotification(lang?.wallpapers?.success_set || "Đã đặt hình nền thành công!");
        folderModel.update();
      }
    }
  }

  // Process để xóa file
  Process {
    id: deleteProcess
    command: ["rm", ""]

    stdout: StdioCollector {
      onTextChanged: {}
    }

    onRunningChanged: {
      if (!running) {
        showNotification(lang?.wallpapers?.success_delete || "Đã xóa ảnh thành công!");
      }
    }
  }

  // Process để tạo thumbnail cho video
  Process {
    id: thumbnailProcess

    onRunningChanged: {
      if (!running) {
        console.log("Thumbnail ready:");
      }
    }
  }

  ScrollView {
    id: scrollView
    anchors.fill: parent
    anchors.margins: ScalerService.s(20)
    clip: true
    ScrollBar.vertical.policy: ScrollBar.AsNeeded

    ColumnLayout {
      width: parent.width
      spacing: ScalerService.s(15)

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: ScalerService.s(10)

        Text {
          text: lang?.wallpapers?.title || "Quản lý hình ảnh"
          color: theme.primary.foreground
          font.pixelSize: ScalerService.s(24)
          font.bold: true
          font.family: "ComicShannsMono Nerd Font"
        }

        Item {
          Layout.fillWidth: true
        }

        // Đã xóa nút "Nâng cao" vì nó có tham chiếu đến panelManager.fullsetting
      }

      Rectangle {
        Layout.fillWidth: true
        height: ScalerService.s(1)
        color: theme.primary.foreground
      }

      // Screen selector
      RowLayout {
        Layout.fillWidth: true
        spacing: ScalerService.s(5)

        Repeater {
          model: Quickshell.screens

          delegate: Rectangle {
            Layout.preferredWidth: ScalerService.s(100)
            Layout.preferredHeight: ScalerService.s(30)
            radius: ScalerService.s(6)
            color: systemSettings.currentScreenIndex === index ? theme.normal.blue : theme.button.background
            border.color: theme.button.border
            border.width: ScalerService.s(1)

            Text {
              anchors.centerIn: parent
              text: modelData.name || `Screen ${index + 1}`
              color: systemSettings.currentScreenIndex === index ? theme.primary.background : theme.primary.foreground
              font.pixelSize: ScalerService.s(12)
              font.family: "ComicShannsMono Nerd Font"
            }

            MouseArea {
              anchors.fill: parent
              onClicked: systemSettings.currentScreenIndex = index
            }
          }
        }
      }

      // Statistics
      RowLayout {
        Layout.fillWidth: true
        spacing: ScalerService.s(20)

        Rectangle {
          Layout.preferredHeight: ScalerService.s(40)
          Layout.fillWidth: true
          radius: ScalerService.s(8)
          color: theme.button.background
          border.color: theme.button.border
          border.width: ScalerService.s(2)

          Row {
            anchors.centerIn: parent
            spacing: ScalerService.s(8)

            Text {
              text: lang?.wallpapers?.total_images || "Tổng số ảnh:"
              font.family: "ComicShannsMono Nerd Font"
              color: theme.primary.dim_foreground
              font.pixelSize: ScalerService.s(15)
            }

            Text {
              text: folderModel.count
              color: theme.normal.blue
              font.family: "ComicShannsMono Nerd Font"
              font.pixelSize: ScalerService.s(18)
              font.bold: true
            }

            Text {
              text: "|"
              color: theme.primary.dim_foreground
              font.pixelSize: ScalerService.s(15)
            }

            Text {
              text: homePath ? (lang?.wallpapers?.path || "Đường dẫn:") + " ~/Pictures/Wallpapers/" : (lang?.wallpapers?.loading || "Đang tải...")
              font.family: "ComicShannsMono Nerd Font"
              color: theme.primary.dim_foreground
              font.pixelSize: ScalerService.s(15)
              elide: Text.ElideMiddle
            }
          }
        }
      }

      // Wallpapers Section
      ColumnLayout {
        Layout.fillWidth: true
        spacing: ScalerService.s(10)

        Text {
          text: lang?.wallpapers?.wallpapers_label || "Hình nền:"
          color: theme.primary.foreground
          font {
            family: "ComicShannsMono Nerd Font"
            pixelSize: ScalerService.s(16)
          }
        }

        // Wallpapers Grid
        Grid {
          id: wallpapersGrid
          Layout.fillWidth: true
          columns: 3  // Đã sửa từ: !panelManager.fullsetting ? 3 : 6
          columnSpacing: ScalerService.s(10)  // Đã sửa từ: !panelManager.fullsetting ? 8 : 10
          rowSpacing: ScalerService.s(10)  // Đã sửa từ: !panelManager.fullsetting ? 8 : 10

          Repeater {
            model: FolderListModel {
              id: folderModel
              folder: wallpapersPath
              nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.webp", "*.gif", "*.mp4", "*.webm", "*.mkv", "*.avi", "*.mov", "*.flv", "*.wmv", "*.m4v", "*.mpg", "*.mpeg"]
              showDirs: false
              sortField: FolderListModel.Name
            }

            delegate: Rectangle {
              width: systemSettings.width / 4  // Đã sửa từ: !panelManager.fullsetting ? systemSettings.width/4 : systemSettings.width/7
              height: systemSettings.width / 4  // Đã sửa từ: !panelManager.fullsetting ? systemSettings.width/4 : systemSettings.width/7
              radius: ScalerService.s(12)
              color: theme.button.background
              border.color: theme.button.border
              border.width: ScalerService.s(1)

              Column {
                anchors.fill: parent
                anchors.margins: ScalerService.s(8)
                spacing: ScalerService.s(8)

                // Thumbnail
                Rectangle {
                  width: parent.width
                  height: parent.height - ScalerService.s(70)
                  radius: ScalerService.s(8)
                  clip: true
                  color: "transparent"

                  Component.onCompleted: {
                    if (isVideoFile(fileName)) {
                      generateThumbnail(filePath);
                    }
                  }

                  Image {
                    id: thumbnailImage
                    anchors.fill: parent
                    source: isVideoFile(fileName) ? getThumbnailPath(filePath) : filePath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true

                    onStatusChanged: {
                      if (status === Image.Error && isVideoFile(fileName)) {
                        // Nếu thumbnail chưa có, thử tạo lại
                        thumbnailImage.source = "";
                        generateThumbnail(filePath);
                      }
                    }
                  }

                  // Video indicator
                  Rectangle {
                    visible: isVideoFile(fileName)
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: ScalerService.s(5)
                    width: ScalerService.s(24)
                    height: ScalerService.s(24)
                    radius: ScalerService.s(12)
                    color: theme.normal.magenta

                    Text {
                      text: "▶"
                      color: theme.primary.background
                      font.pixelSize: ScalerService.s(12)
                      font.bold: true
                      anchors.centerIn: parent
                    }
                  }

                  // Current Wallpaper Indicator
                  Rectangle {
                    visible: systemSettings.currentWallpaper === filePath
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: ScalerService.s(5)
                    width: ScalerService.s(24)
                    height: ScalerService.s(24)
                    radius: ScalerService.s(12)
                    color: theme.normal.green

                    Text {
                      text: "✓"
                      color: theme.primary.background
                      font.pixelSize: ScalerService.s(12)
                      font.bold: true
                      anchors.centerIn: parent
                    }
                  }
                }

                // File Info & Actions
                Column {
                  width: parent.width
                  spacing: ScalerService.s(6)

                  Text {
                    text: fileName
                    color: theme.primary.foreground
                    font.pixelSize: ScalerService.s(12)
                    elide: Text.ElideMiddle
                    width: parent.width
                  }

                  Row {
                    width: parent.width
                    spacing: ScalerService.s(8)
                    Text {
                      text: Math.round(fileSize / 1024) + " KB"
                      color: theme.primary.dim_foreground
                      font.pixelSize: ScalerService.s(9)
                    }
                    Text {
                      text: new Date(fileModified).toLocaleDateString(Qt.locale(), "dd/MM/yyyy")
                      color: theme.primary.dim_foreground
                      font.pixelSize: ScalerService.s(9)
                    }
                  }

                  Row {
                    width: parent.width
                    spacing: ScalerService.s(6)

                    // Set Wallpaper
                    Rectangle {
                      width: (parent.width - ScalerService.s(6)) / 2
                      height: ScalerService.s(28)
                      radius: ScalerService.s(6)
                      color: systemSettings.currentWallpaper === filePath ? theme.normal.green : theme.normal.blue

                      Text {
                        anchors.centerIn: parent
                        text: systemSettings.currentWallpaper === filePath ? (lang?.wallpapers?.already_set || "Đã đặt") : (lang?.wallpapers?.set_wallpaper || "Đặt nền")
                        color: theme.primary.background
                        font.pixelSize: ScalerService.s(10)
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          setWallpaper(filePath)
                          console.log(filePath)
                        }
                      }
                    }

                    // Delete Button
                    Rectangle {
                      width: (parent.width - ScalerService.s(6)) / 2
                      height: ScalerService.s(28)
                      radius: ScalerService.s(6)
                      color: theme.normal.red

                      Text {
                        anchors.centerIn: parent
                        text: lang?.wallpapers?.delete || "Xóa"
                        color: theme.primary.background
                        font.pixelSize: ScalerService.s(10)
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: showDeleteDialog(fileName, filePath)
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // No images message
        Text {
          visible: folderModel.count === 0 && homePath
          text: lang?.wallpapers?.no_images || "Không tìm thấy ảnh nào trong thư mục ~/Pictures/Wallpapers"
          color: theme.primary.dim_foreground
          font.pixelSize: ScalerService.s(14)
          Layout.alignment: Qt.AlignCenter
        }

        // Loading message
        Text {
          visible: !homePath
          text: lang?.wallpapers?.loading_info || "Đang tải thông tin..."
          color: theme.primary.dim_foreground
          font.pixelSize: ScalerService.s(14)
          Layout.alignment: Qt.AlignCenter
        }
      }

      Item {
        Layout.fillHeight: true
      } // Spacer
    }
  }

  // Delete dialog
  Rectangle {
    id: deleteDialog
    visible: false
    anchors.centerIn: parent
    width: ScalerService.s(300)
    height: ScalerService.s(160)
    radius: ScalerService.s(12)
    color: theme.primary.background
    border.color: theme.normal.red
    border.width: ScalerService.s(2)
    z: 1000

    property string fileNameToDelete: ""
    property string filePathToDelete: ""

    Column {
      anchors.fill: parent
      anchors.margins: ScalerService.s(20)
      spacing: ScalerService.s(15)

      Text {
        text: (lang?.wallpapers?.delete_confirm || "Xác nhận xóa") + "\n" + deleteDialog.fileNameToDelete
        color: theme.normal.red
        font.pixelSize: ScalerService.s(16)
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
      }

      Row {
        spacing: ScalerService.s(15)
        anchors.horizontalCenter: parent.horizontalCenter

        // Cancel
        Rectangle {
          width: ScalerService.s(100)
          height: ScalerService.s(35)
          radius: ScalerService.s(6)
          color: theme.button.background
          border.color: theme.button.border

          Text {
            anchors.centerIn: parent
            text: lang?.wallpapers?.cancel || "Hủy"
            color: theme.primary.foreground
            font.pixelSize: ScalerService.s(14)
          }

          MouseArea {
            anchors.fill: parent
            onClicked: deleteDialog.visible = false
          }
        }

        // Confirm delete
        Rectangle {
          width: ScalerService.s(100)
          height: ScalerService.s(35)
          radius: ScalerService.s(6)
          color: theme.normal.red

          Text {
            anchors.centerIn: parent
            text: lang?.wallpapers?.delete || "Xóa"
            color: theme.primary.background
            font.pixelSize: ScalerService.s(14)
          }

          MouseArea {
            anchors.fill: parent
            onClicked: {
              deleteWallpaper(deleteDialog.filePathToDelete);
              deleteDialog.visible = false;
            }
          }
        }
      }
    }
  }

  // Notification
  Rectangle {
    id: successNotification
    visible: false
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: ScalerService.s(20)
    width: ScalerService.s(250)
    height: ScalerService.s(50)
    radius: ScalerService.s(8)
    color: theme.normal.green
    z: 1001

    Row {
      anchors.centerIn: parent
      spacing: ScalerService.s(10)
      Text {
        text: "✓"
        color: theme.primary.background
        font.bold: true
        font.pixelSize: ScalerService.s(16)
      }
      Text {
        id: notificationText
        color: theme.primary.background
        text: ""
        font.bold: true
        font.pixelSize: ScalerService.s(16)
      }
    }

    Timer {
      id: notificationTimer
      interval: 3000
      onTriggered: successNotification.visible = false
    }
  }

  function setWallpaper(filePath) {
    Settings.wallpaper.shaders = Math.floor(Math.random() * 4)
    var cleanPath = filePath.toString().replace("file://", "");
    // Set cho tất cả màn hình
    if (Settings.wallpaper.setWallpaperOnAllMonitors) {
      for (var i = 0; i < Quickshell.screens.length; i++) {
        WallpaperService.changeWallpaper(cleanPath, Quickshell.screens[i].name);
      }
    } else {
      // Set cho màn hình hiện tại trong selector
      var screen = systemSettings.currentScreen;
      if (screen) {
        WallpaperService.changeWallpaper(cleanPath, screen.name);
      } else if (Quickshell.screens.length > 0) {
        WallpaperService.changeWallpaper(cleanPath, Quickshell.screens[0].name);
      }
    }

    showNotification(lang?.wallpapers?.success_set || "Đã đặt hình nền thành công!");
    systemSettings.currentWallpaper = filePath
  }

  function generateThumbnail(filePath) {
    if (!homePath)
    return;
    var actualPath = filePath.toString().replace("file://", "");
    var thumbnailDir = homePath + "/.config/hypr/custom/scripts/mpvpaper_thumbnails";
    var fileName = actualPath.split('/').pop();
    var thumbnailPath = thumbnailDir + "/" + fileName + ".jpg";
    var scriptPath = homePath + "/.config/quickshell/cartoon-shell/scripts/generate-video-thumbnail.sh";

    thumbnailProcess.command = ["bash", scriptPath, actualPath, thumbnailPath];
    thumbnailProcess.running = true;
  }

  function isVideoFile(fileName) {
    var ext = fileName.toLowerCase().split('.').pop();
    return ["mp4", "webm", "mkv", "avi", "mov", "flv", "wmv", "m4v", "mpg", "mpeg"].includes(ext);
  }

  function getThumbnailPath(filePath) {
    if (!homePath)
    return "";
    var actualPath = filePath.toString().replace("file://", "");
    var thumbnailDir = homePath + "/.config/hypr/custom/scripts/mpvpaper_thumbnails";
    var fileName = actualPath.split('/').pop();
    return "file://" + thumbnailDir + "/" + fileName + ".jpg";
  }

  function deleteWallpaper(filePath) {
    var actualPath = filePath.toString().replace("file://", "");

    deleteProcess.command = ["rm", actualPath];
    deleteProcess.running = true;
  }

  function showDeleteDialog(fileName, filePath) {
    deleteDialog.fileNameToDelete = fileName;
    deleteDialog.filePathToDelete = filePath;
    deleteDialog.visible = true;
  }

  function showNotification(message) {
    notificationText.text = message;
    successNotification.visible = true;
    notificationTimer.start();
  }

  function isCurrentWallpaper(filePath) {
    if (!currentScreen)
    return false;

    // Lấy hình nền hiện tại của màn hình từ WallpaperService
    var currentWallpaper = WallpaperService.getWallpaper(currentScreen.name);

    // Chuẩn hóa đường dẫn để so sánh
    var cleanFilePath = filePath.toString().replace("file://", "");
    var cleanCurrentWallpaper = currentWallpaper.toString().replace("file://", "");

    return cleanFilePath === cleanCurrentWallpaper;
  }

  Component.onCompleted: {
    systemSettings.currentWallpaper = `${WallpaperService.getWallpaper(currentScreen.name)}`;
    console.log(systemSettings.currentWallpaper)
  }
}
