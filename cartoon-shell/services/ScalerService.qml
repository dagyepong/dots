pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // =========================
  // Base config
  // =========================

  property real baseWidth: 1920.0
  property real baseHeight: 1080.0
  property real baseScale: 1.0

  // =========================
  // Current monitor info
  // =========================

  property real screenWidth: 1920
  property real screenHeight: 1080
  property real screenScale: 1.0

  // =========================
  // Final calculated scale
  // =========================

  property real scaleFactor:
  ((screenWidth / baseWidth) / screenScale) * baseScale

  // =========================
  // Helper
  // =========================

  function s(val) {
    return val * scaleFactor
  }

  // =========================
  // Detect monitor scale
  // =========================

  Process {
    id: monitorProcess

    running: true

    command: [
    "sh",
    "-c",
    `
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    hyprctl monitors -j | jq -r '
    .[0] |
    "\\(.width) \\(.height) \\(.scale)"
    '
    elif [ -n "$NIRI_SOCKET" ]; then
    niri msg outputs | awk '
    /Current mode:/ {
    split($3, r, "x");
    width=r[1];
    split(r[2], h, "@");
    height=h[1];
  }
    /Scale:/ {
    scale=$2;
  }
    END {
    print width, height, scale;
  }
    '
    else
    echo "1920 1080 1"
    fi
    `
    ]

    stdout: StdioCollector {
      onStreamFinished: {
        const parts = text.trim().split(" ")

        if (parts.length >= 3) {
          root.screenWidth = parseFloat(parts[0])
          root.screenHeight = parseFloat(parts[1])
          root.screenScale = parseFloat(parts[2])

          console.log(
            "[ScaleService]",
            "width:", root.screenWidth,
            "height:", root.screenHeight,
            "scale:", root.screenScale,
            "factor:", root.scaleFactor
          )
        }
      }
    }
  }
}
