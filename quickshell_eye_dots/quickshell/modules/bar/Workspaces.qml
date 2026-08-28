// ┌────────────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█░█░█▀█░█▀▄░█░█░█▀▀░█▀█░█▀█░█▀▀░█▀▀░█▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█▄█░█░█░█▀▄░█▀▄░▀▀█░█▀▀░█▀█░█░░░█▀▀░▀▀█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░▀▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>                        ├┤
// ├┤ Converted for Niri compositor support                         ├┤
// ├┤ License : GNU General Public License v3                       ├┤
// └────────────────────────────────────────────────────────────────┘

import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Layouts
import qs.services
import qs.config
import qs.components
import qs.utils
pragma ComponentBehavior: Bound

BorderRect {
  id: root
  leftBorder: Style.bar.borderWidth
  rightBorder: Style.bar.borderWidth
  borderColor: Style.srcery.gray3
  color: Style.srcery.black
  required property string monitorId
  
  // Pull workspace array dynamically from Niri wrapper
  property var workspaces: HyprlandData.workspacesByMonitor[monitorId] ?? []
  
  // Calculate window counts per workspace via Niri's windowsByWorkspace object
  readonly property var occupied: workspaces.reduce((acc, ws) => {
    let wins = HyprlandData.windowsByWorkspace[ws.id] ?? [];
    acc[ws.id] = wins.length > 0;
    return acc;
  }, {})
  
  // Match active workspace for current output from Niri singleton
  readonly property int activeWorkspaceId: {
    let ws = HyprlandData.activeWorkspace;
    if (ws && (ws.monitor === monitorId || !ws.monitor)) {
      return ws.id;
    }
    // Fallback: look up workspace matching monitor output marked active
    let activeWs = workspaces.find(w => w.active || w.focused);
    return activeWs ? activeWs.id : (workspaces[0]?.id ?? 1);
  }

  readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

  Behavior on implicitWidth {
    NumberAnimation {
      duration: Style.durations.small
      easing.type: Easing.InOutCubic
    }
  }
  implicitWidth: layout.implicitWidth + Style.spacing.p3 + Style.bar.borderWidth * 2
  implicitHeight: Style.bar.height - Style.bar.borderWidth
  Layout.topMargin: Style.bar.borderWidth
  radius: Style.bar.radius

  Item {
    id: inner
    anchors.fill: parent

    // Moving active workspace indicator rectangle
    GradientRect {
      id: activeIndicator
      z: 3
      height: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2
      property Gradient activeGradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 1; color: Style.srcery.magenta }
        GradientStop { position: 0; color: Style.srcery.blue }
      }
      gradientAngle: 45
      borderColor: Style.srcery.brightBlack
      gradient: activeGradient
      gradientActive: true
      property real targetX: 0
      property real targetWidth: 0

      function updateIndicator() {
        let x = Style.spacing.p1 + Style.bar.borderWidth
        let targetIdx = root.workspaces.findIndex(w => {
          return w.id === root.activeWorkspaceId
        });

        if (targetIdx < 0) targetIdx = 0;

        for (let i = 0; i < targetIdx && i < workspaceRepeater.count; i++) {
          let item = workspaceRepeater.itemAt(i);
          if (item) {
            x += item.calculatedWidth + layout.spacing;
          }
        }

        let activeItem = workspaceRepeater.itemAt(targetIdx);

        if (activeItem) {
          targetX = x;
          targetWidth = activeItem.calculatedWidth;
        }
      }

      Behavior on x {
        NumberAnimation {
          duration: Style.animationCurves
            .expressiveDefaultSpatialDuration
          easing.type: Easing.BezierSpline
          easing.bezierCurve: Style.animationCurves
            .expressiveDefaultSpatial
        }
      }

      Behavior on width {
        NumberAnimation {
          duration: Style.animationCurves
            .expressiveDefaultSpatialDuration
          easing.type: Easing.BezierSpline
          easing.bezierCurve: Style.animationCurves
            .expressiveDefaultSpatial
        }
      }

      anchors.verticalCenter: parent.verticalCenter
      x: targetX
      width: targetWidth
    }
    
    RowLayout {
      id: layout
      spacing: Style.spacing.p1
      z: 2
      anchors.centerIn: parent
      Repeater {
        model: root.workspaces
        id: workspaceRepeater

        Workspace {
          monitorId: root.monitorId
          isOccupied: root.occupied[modelData?.id] ?? false
          activeWorkspaceId: root.activeWorkspaceId
          workspaceId: modelData?.id ?? 1
          onCalculatedWidthChanged: activeIndicator.updateIndicator()
        }
      }
    }
  }

  onActiveWorkspaceIdChanged: activeIndicator.updateIndicator()
  onWorkspacesChanged: activeIndicator.updateIndicator()
  Component.onCompleted: {
    activeIndicator.updateIndicator();
  }
}
