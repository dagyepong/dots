import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "exampleDesktopClock"

    SelectionSetting {
        settingKey: "clockStyle"
        label: I18n.tr("Clock Style")
        options: [
            {
                label: I18n.tr("Analog"),
                value: "analog"
            },
            {
                label: I18n.tr("Digital"),
                value: "digital"
            }
        ]
        defaultValue: "analog"
    }

    ToggleSetting {
        settingKey: "showSeconds"
        label: I18n.tr("Show Seconds")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showDate"
        label: I18n.tr("Show Date")
        defaultValue: true
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: I18n.tr("Background Opacity")
        defaultValue: 50
        minimum: 0
        maximum: 100
        unit: "%"
    }
}
