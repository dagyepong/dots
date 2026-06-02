import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import qs.commons
import qs.components

Rectangle {
  id: root
  border.color: theme.button.border
  border.width: Settings.appearance.enableBorder ? ScalerService.s(3) : 0
  radius: ScalerService.s(Settings.appearance.radius2)

  anchors.centerIn: parent
  property real animationProgress: 0
  SequentialAnimation on animationProgress {
    running: true
    NumberAnimation {
      from: 0
      to: 1
      duration: 1000
      easing.type: Easing.Linear
    }
  }
  implicitWidth: root.animationProgress > 0.1 ? parent.width : 0
  implicitHeight: root.animationProgress > 0.1 ? parent.height : 0
  Behavior on implicitHeight {
    NumberAnimation {
      id: heightAnim
      duration: 500
      easing.type: Easing.OutCubic
    }
  }
  Behavior on implicitWidth {
    NumberAnimation {
      id: widthAnim
      duration: 500
      easing.type: Easing.OutCubic
    }
  }
  property bool isVertical: Settings.bar.position === "left" || Settings.bar.position === "right"
  color: theme.primary.background

  // Sử dụng CompositorService
  property var workspacesModel: CompositorService.workspaces
  property string activeWorkspace: "1"
  property bool initialized: false

  // Workspace UI data - lưu 10 workspace đầu (1-10)
  property var uiWorkspaces: []

  // Accumulated scroll delta for smooth, threshold-based switching
  property real scrollAccumulator: 0

  // Debounce timer cho updates
  Timer {
    id: updateTimer
    interval: 100
    repeat: false
    onTriggered: updateUIWorkspaces()
  }

  // Reset accumulator when user stops scrolling (no events for 80ms).
  Timer {
    id: idleResetTimer
    interval: 80
    repeat: false
    onTriggered: root.scrollAccumulator = 0
  }

  // Khởi tạo
  function initialize() {
    if (initialized) return;

    // Đợi backend sẵn sàng
    if (!CompositorService.backend) {
      backendCheckTimer.start();
      return;
    }

    initUIWorkspaces();
    syncWorkspaces();
    initialized = true;
  }

  Timer {
    id: backendCheckTimer
    interval: 100
    repeat: true
    onTriggered: {
      if (CompositorService.backend) {
        stop();
        initialize();
      }
    }
  }

  // Khởi tạo UI workspaces
  function initUIWorkspaces() {
    var arr = [];
    for (var i = 1; i <= 10; i++) {
      arr.push({
          id: i.toString(),
          exists: false,
          isActive: false
      });
    }
    uiWorkspaces = arr;
  }

  // Đồng bộ workspaces từ CompositorService
  function syncWorkspaces() {
    if (!initialized) return;

    // Tạo map từ workspaces hiện có
    var wsMap = {};
    for (var i = 0; i < workspacesModel.count; i++) {
      var ws = workspacesModel.get(i);
      if (ws && ws.id) {
        wsMap[ws.id.toString()] = ws;

        // Cập nhật active workspace
        if (ws.isActive || ws.isFocused) {
          activeWorkspace = ws.id.toString();
        }
      }
    }

    // Cập nhật UI workspaces
    var needUpdate = false;
    for (var j = 0; j < uiWorkspaces.length; j++) {
      var uiWs = uiWorkspaces[j];
      var wsData = wsMap[uiWs.id];

      var newExists = wsData ? (wsData.isOccupied || false) : false;
      var newIsActive = (uiWs.id === root.activeWorkspace);

      if (uiWs.exists !== newExists || uiWs.isActive !== newIsActive) {
        uiWs.exists = newExists;
        uiWs.isActive = newIsActive;
        needUpdate = true;
      }
    }

    // Chỉ cập nhật nếu có thay đổi
    if (needUpdate) {
      uiWorkspaces = uiWorkspaces.slice();
    }
  }

  function updateUIWorkspaces() {
    if (!initialized) return;
    syncWorkspaces();
  }

  // Chuyển workspace - FIXED: Tìm workspace object từ model
  function switchWs(wsId) {
    if (!CompositorService.backend) {
      console.log("No backend available");
      return;
    }

    // Kiểm tra ID
    if (!wsId || wsId === undefined || wsId === "") {
      console.log("Invalid workspace id:", wsId);
      return;
    }

    // Tìm workspace object từ model
    var workspaceObj = null;
    for (var i = 0; i < workspacesModel.count; i++) {
      var ws = workspacesModel.get(i);
      if (ws && ws.id.toString() === wsId.toString()) {
        workspaceObj = ws;
        break;
      }
    }

    if (!workspaceObj) {
      // Nếu không tìm thấy, tạo object tạm với idx
      workspaceObj = { id: parseInt(wsId), idx: parseInt(wsId) };
    }

    try {
      CompositorService.switchToWorkspace(workspaceObj);

      // Update activeWorkspace immediately so the pacman icon moves
      // right away without waiting for the compositor signal round-trip
      activeWorkspace = wsId.toString();

      // Force a UI sync instantly so icon state reflects the new active ws
      syncWorkspaces();
    } catch (e) {
      console.log("Failed to switch workspace:", e);
    }
  }

  // Smooth scroll using a pure accumulator
  function handleScroll(angleDeltaY, angleDeltaX) {
    if (!initialized) return;

    // Keep restarting idle timer on every event so accumulator only
    // resets after a real pause in scrolling
    idleResetTimer.restart();

    // Pick the dominant axis
    var raw = isVertical
      ? (angleDeltaX !== 0 ? angleDeltaX : angleDeltaY)
      : (angleDeltaY !== 0 ? angleDeltaY : angleDeltaX);

    var current = parseInt(activeWorkspace);

    // Block accumulation at hard boundaries to avoid phantom delta buildup
    if ((raw < 0 && current >= 10) || (raw > 0 && current <= 1)) {
      scrollAccumulator = 0;
      return;
    }

    // Invert: scroll-up (positive angleDelta) = previous workspace
    scrollAccumulator -= raw;

    // 120 = one standard mouse notch; feels immediate on mouse,
    // requires a deliberate swipe on touchpad
    var threshold = 120;

    if (scrollAccumulator >= threshold) {
      var next = current + 1;
      if (next > 10) { scrollAccumulator = 0; return; }
      switchWs(next.toString());
      // Subtract threshold so fast flicks chain smoothly
      scrollAccumulator -= threshold;

    } else if (scrollAccumulator <= -threshold) {
      var prev = current - 1;
      if (prev < 1) { scrollAccumulator = 0; return; }
      switchWs(prev.toString());
      scrollAccumulator += threshold;
    }
  }

  // Kết nối signals
  Connections {
    target: CompositorService

    function onWorkspaceChanged() {
      if (initialized) {
        updateTimer.restart();
      }
    }

    function onWorkspacesChanged() {
      if (initialized) {
        updateTimer.restart();
      }
    }
  }

  // UI Layout
  Loader {
    anchors.centerIn: parent
    sourceComponent: isVertical ? verticalLayout : horizontalLayout
  }

  Component {
    id: horizontalLayout

    RowLayout {
      id: workspaceRow
      spacing: ScalerService.s(4)

      Repeater {
        model: root.uiWorkspaces

        Rectangle {
          required property var modelData
          property string wsId: modelData.id

          Layout.preferredWidth: ScalerService.s(32)
          Layout.preferredHeight: ScalerService.s(32)
          radius: ScalerService.s(6)
          color: "transparent"

          IconImage {
            path: modelData.isActive ? "workspace/pacman.png" : modelData.exists ? "workspace/ghost.png" : "workspace/empty.png"
            size: "large"
            anchors.centerIn: parent
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              // Gọi hàm switchWs đã được định nghĩa
              root.switchWs(modelData.id);
            }
            onEntered: {
              if (wsId !== root.activeWorkspace)
              parent.scale = 1.1;
            }
            onExited: {
              if (wsId !== root.activeWorkspace)
              parent.scale = 1.0;
            }
            // Forward wheel events to the shared accumulator-based handler
            onWheel: (event) => {
              root.handleScroll(event.angleDelta.y, event.angleDelta.x);
            }
          }

          Behavior on scale {
            NumberAnimation {
              duration: 100
            }
          }
        }
      }
    }
  }

  Component {
    id: verticalLayout

    ColumnLayout {
      id: workspaceColumn
      spacing: ScalerService.s(2)

      Repeater {
        model: root.uiWorkspaces

        Rectangle {
          required property var modelData
          property string wsId: modelData.id

          Layout.preferredWidth: ScalerService.s(24)
          Layout.preferredHeight: ScalerService.s(24)
          radius: ScalerService.s(6)
          color: "transparent"

          IconImage {
            path: modelData.isActive ? "workspace/pacman.png" : modelData.exists ? "workspace/ghost.png" : "workspace/empty.png"
            anchors.centerIn: parent
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.switchWs(modelData.id);
            }
            onEntered: {
              if (wsId !== root.activeWorkspace)
              parent.scale = 1.1;
            }
            onExited: {
              if (wsId !== root.activeWorkspace)
              parent.scale = 1.0;
            }
            // Forward wheel events to the shared accumulator-based handler
            onWheel: (event) => {
              root.handleScroll(event.angleDelta.y, event.angleDelta.x);
            }
          }

          Behavior on scale {
            NumberAnimation {
              duration: 100
            }
          }
        }
      }
    }
  }

  Component.onCompleted: {
    initialize();
  }
}