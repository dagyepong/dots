import QtQuick
import Quickshell
import Quickshell.Services.UPower

Row {
    spacing: 4

    // Dynamic icon that changes during charging/discharging
    IconImage {
        source: UPower.displayDevice.iconName !== "" 
            ? "image://icon/" + UPower.displayDevice.iconName 
            : ""
        implicitWidth: 16
        implicitHeight: 16
    }

    // Text showing percentage + explicit charging indicator text
    Text {
        text: Math.round(UPower.displayDevice.percentage * 100) + "%" + 
              (UPower.displayDevice.state === UPowerDeviceState.Charging ? " (Charging)" : "")
        color: "white"
    }
}
