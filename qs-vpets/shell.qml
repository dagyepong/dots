//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded

import QtQuick
import Quickshell
import "services"
import "config"
import "components"

ShellRoot {
    id: root

    property var petList: []

    Variants {
        model: root.petList

        PetWindow {
            required property var modelData
            petData: modelData
            screen: {
                if (!Quickshell.screens || Quickshell.screens.length === 0) return null;
                if (modelData.monitor) {
                    const match = Quickshell.screens.find(s => s.name === modelData.monitor);
                    if (match) return match;
                }
                return Quickshell.screens[0];
            }
        }
    }

    Connections {
        target: Config
        // fires on first load and on every external config edit; only touch
        // petList when the pets actually changed, since reassigning it tears
        // down and respawns every pet window
        function onConfigReady(): void {
            const next = Config.pets.map(p => Object.assign({}, p));
            if (JSON.stringify(next) !== JSON.stringify(root.petList))
                root.petList = next;
        }
    }
}
