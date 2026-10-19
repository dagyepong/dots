import QtQuick
import qs.modules.sekai.quickPanel

// A button that does something once rather than switch something (Reload
// shell, Check for updates, Wallpapers...): a SekaiTile that is white until
// you hover it, then lights up; `busy` keeps it lit while the thing is
// happening.
//
//   SettingAction { icon: "refresh"; label: "Reload shell"; onActivated: ... }
SekaiTile {
    id: root

    property string detail: ""
    property bool busy: false

    signal activated()

    function ancestorTileWidth() {
        for (let p = root.parent; p; p = p.parent) {
            if (p.tileWidth !== undefined && p !== root)
                return p.tileWidth
        }
        return 300
    }

    tileWidth: ancestorTileWidth()
    hoverLights: true
    lit: busy
    subtitle: detail
    onClicked: activated()
}
