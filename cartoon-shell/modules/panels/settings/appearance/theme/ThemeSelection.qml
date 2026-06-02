// components/Settings/ThemeSelection.qml
import QtQuick
import QtQuick.Layouts
import "." as Com
import qs.services
import qs.commons

RowLayout {
  id: themeSelection
  spacing: ScalerService.s(12)

  Text {
    text: lang.appearance?.theme_label || "Chủ đề:"
    color: theme.primary.foreground
    font {
      family: "ComicShannsMono Nerd Font"
      pixelSize: ScalerService.s(16)
    }
    Layout.preferredWidth: ScalerService.s(150)
  }

  Row {
    spacing: ScalerService.s(12)
    Layout.fillWidth: true

    // Light Theme Card
    Com.ThemeCard {
      type: "light"
      isSelected: theme.type === "light"
      label: lang.appearance?.theme_light || "Sáng"
      onClicked: {
        // Set theme to matugen and mode to light
        Settings.appearance.theme = "matugen";
        Settings.appearance.dynamic = true;
        Settings.appearance.mode = "light";
      }
    }

    // Dark Theme Card
    Com.ThemeCard {
      type: "dark"
      isSelected: theme.type === "dark"
      label: lang.appearance?.theme_dark || "Tối"
      onClicked: {
        Settings.appearance.theme = "matugen";
        Settings.appearance.dynamic = true;
        Settings.appearance.mode = "dark";
      }
    }
  }
}
