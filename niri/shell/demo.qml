import QtQuick
import Quickshell
import Quickshell.Wayland

// A short scripted scene for the README: seven figures on a frame strip
// wave, hop, float, juggle, peck, hug and cheer. Every frame is saved as a
// PNG with a clear ground under shell/.demo/ (tools/demo_gif.sh lays a
// wallpaper under them and makes the GIF), then it quits.
//
//     qs -p shell/demo.qml
//
// It draws on a background surface while it runs, so the figures show for
// a few seconds behind the windows.
ShellRoot {
    id: root
    readonly property string out: Quickshell.shellDir + "/.demo"
    readonly property real floor: 158

    World {
        id: world
        areaW: 600; areaH: 170
        cast: [kuro, shiro, neko, kumo, tako, hiyoko, arai]
        glassOpacity: 0.85
    }
    Character { id: kuro; world: world; slot: 0; skin: "kuro"; x0: 56 }
    Character { id: shiro; world: world; slot: 1; skin: "shiro"; x0: 150 }
    Character { id: neko; world: world; slot: 2; skin: "neko"; x0: 230 }
    Character { id: kumo; world: world; slot: 3; skin: "kumo"; x0: 312 }
    Character { id: tako; world: world; slot: 4; skin: "tako"; x0: 396 }
    Character { id: hiyoko; world: world; slot: 5; skin: "hiyoko"; x0: 470 }
    Character { id: arai; world: world; slot: 6; skin: "arai"; x0: 546 }

    PanelWindow {
        anchors { left: true; bottom: true }
        implicitWidth: 1200; implicitHeight: 340
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "aibou-demo"
        mask: Region {}

        Item {
            id: stage
            width: 1200; height: 340
            Item {
                width: 600; height: 170
                scale: 2
                transformOrigin: Item.TopLeft
                // the frame they live on
                Rectangle { x: 0; y: root.floor; width: 600; height: 12; radius: 6; color: "#1b2226"; opacity: 0.92 }
                Repeater {
                    model: world.cast
                    Creature {
                        required property var modelData
                        st: modelData
                        x: modelData.x0; y: root.floor
                    }
                }
            }
        }
    }

    // the script: [seconds, what]
    readonly property var script: [
        [0.3, () => kuro.wave()],
        [0.5, () => hiyoko.hop(hiyoko.x0 - 18, 12)],
        [0.9, () => hiyoko.hop(hiyoko.x0 + 18, 12)],
        [1.0, () => neko.jump(30)],
        [1.4, () => kumo.drift(kumo.x0 + 26, false)],
        [1.6, () => tako.juggle()],
        [2.2, () => arai.eatSnack()],
        [2.4, () => shiro.hop(shiro.x0 - 40, 16)],
        [2.6, () => kuro.hop(kuro.x0 + 14, 12)],
        [3.3, () => { kuro.hug(1); shiro.hug(-1) }],
        [3.4, () => kumo.feel("sad", 2)],
        [3.6, () => hiyoko.eatSnack()],
        [4.4, () => neko.spin(1)],
        [5.4, () => kumo.feel("happy", 2)],
        [5.6, () => kumo.drift(kumo.x0 - 26, false)],
        [6.2, () => arai.feel("proud", 2)],
        [6.4, () => neko.feel("happy", 3)],
        [7.4, () => { for (const c of world.cast) c.cheer() }],
        [7.5, () => { for (const c of world.cast) c.feel("happy", 3) }],
        [8.6, () => { kuro.jump(26); tako.jump(22); hiyoko.jump(30) }],
        [9.0, () => { shiro.jump(24); arai.jump(22); neko.jump(28) }]
    ]
    readonly property real length: 10.6
    property real t0: 0
    property int frame: 0
    property int next: 0
    property bool grabbing: false
    Timer {
        id: tick
        interval: 10; repeat: true
        onTriggered: {
            const t = (Date.now() - root.t0) / 1000
            while (root.next < root.script.length && root.script[root.next][0] <= t) root.script[root.next++][1]()
            if (t > root.length) { stop(); Qt.quit(); return }
            if (root.grabbing) return
            root.grabbing = true
            const n = root.frame++
            stage.grabToImage(res => {
                res.saveToFile(root.out + "/f" + String(n).padStart(4, "0") + "-" + Math.round(t * 1000) + ".png")
                root.grabbing = false
            })
        }
    }
    // a moment to draw everything once, then go
    Timer { interval: 600; running: true; onTriggered: { root.t0 = Date.now(); tick.start() } }
}
