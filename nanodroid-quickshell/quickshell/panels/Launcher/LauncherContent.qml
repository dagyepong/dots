import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../widgets"
import "../../core"
import "../../core/functions" as Functions
import "../../services"

Rectangle {
    id: root

    readonly property bool isSpotlight: false
    readonly property var resultsProxy: LauncherSearch.results
    readonly property bool hasQuery: LauncherSearch.query.trim().length > 0
    readonly property int resultCount: resultsProxy ? resultsProxy.length : 0
    readonly property int maxItems: 7
    readonly property var displayItems: {
        const source = root.resultsProxy || [];
        if (source.length <= root.maxItems) return source;

        const items = [];
        for (let i = 0; i < root.maxItems; i++) {
            items.push(source[(root.resultOffset + i) % source.length]);
        }
        return items;
    }
    readonly property int itemCount: root.displayItems.length
    readonly property real u: Appearance.effectiveScale
    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real orbitRadius: Math.min(width, height) * 0.34
    readonly property real nodeSize: 68 * u
    readonly property real pillWidth: 188 * u
    readonly property real pillHeight: 36 * u
    readonly property real hubSize: 176 * u
    readonly property var orbitPalette: ["#44f0f3", "#ff6f91", "#b79cff", "#ffb38a", "#58e98e", "#ff79cf", "#79b8ff"]

    property int selectedIndex: 0
    property int resultOffset: 0
    property bool isKeyboardNavigation: false
    property real orbitSpin: 0
    property real selectionAngleOffset: -selectedIndex * (360 / Math.max(1, itemCount))
    property real wheelAccumulator: 0

    color: "transparent"
    radius: 36 * u
    border.width: 0
    border.color: "transparent"
    antialiasing: true

    onSelectionAngleOffsetChanged: {
        const currentRot = dialContainer.targetRotation;
        const targetAngle = selectionAngleOffset;
        let diff = targetAngle - currentRot;
        diff = (diff + 180) % 360;
        if (diff < 0) diff += 360;
        diff -= 180;
        dialContainer.targetRotation = currentRot + diff;
    }

    NumberAnimation on orbitSpin {
        running: false // Fix performance: disable continuous spinning idle animation to avoid 60FPS redraws
        from: 0
        to: 360
        duration: 18000
        loops: Animation.Infinite
    }

    function normalizeIndex(index) {
        if (itemCount <= 0) return 0;
        if (index < 0) return itemCount - 1;
        if (index >= itemCount) return 0;
        return index;
    }

    function accentFor(index) {
        return orbitPalette[index % orbitPalette.length];
    }

    function angleForIndex(index, count) {
        if (count <= 0) return -90;
        const idleDrift = hasQuery ? 0 : Math.sin(orbitSpin * Math.PI / 180) * 2.2;
        return -90 + (360 / count) * index + selectionAngleOffset + idleDrift;
    }

    function nodeX(index, count) {
        const angle = angleForIndex(index, count) * Math.PI / 180;
        return centerX + Math.cos(angle) * orbitRadius;
    }

    function nodeY(index, count) {
        const angle = angleForIndex(index, count) * Math.PI / 180;
        return centerY + Math.sin(angle) * orbitRadius;
    }

    function staticAngleForIndex(index, count) {
        if (count <= 0) return -90;
        return -90 + (360 / count) * index;
    }

    function staticNodeX(index, count) {
        const angle = staticAngleForIndex(index, count) * Math.PI / 180;
        return centerX + Math.cos(angle) * orbitRadius;
    }

    function staticNodeY(index, count) {
        const angle = staticAngleForIndex(index, count) * Math.PI / 180;
        return centerY + Math.sin(angle) * orbitRadius;
    }

    function executeSelected() {
        if (!root.displayItems || root.displayItems.length === 0) return;
        const item = root.displayItems[Math.max(0, Math.min(root.selectedIndex, root.displayItems.length - 1))];
        if (item && item.execute) {
            item.execute();
            GlobalStates.launcherOpen = false;
        }
    }

    function rotateSelection(delta) {
        if (resultCount <= 0 || itemCount <= 0) return;

        if (delta > 0) {
            if (selectedIndex < itemCount - 1) {
                selectedIndex++;
            } else if (resultCount > itemCount) {
                resultOffset = (resultOffset + 1) % resultCount;
            } else {
                selectedIndex = 0;
            }
        } else if (delta < 0) {
            if (selectedIndex > 0) {
                selectedIndex--;
            } else if (resultCount > itemCount) {
                resultOffset = (resultOffset - 1 + resultCount) % resultCount;
            } else {
                selectedIndex = itemCount - 1;
            }
        }

        orbitCanvas.requestPaint();
    }

    onItemCountChanged: {
        resultOffset = Math.min(resultOffset, Math.max(0, resultCount - 1));
        selectedIndex = Math.min(selectedIndex, Math.max(0, itemCount - 1));
        orbitCanvas.requestPaint();
    }

    onSelectedIndexChanged: orbitCanvas.requestPaint()
    onOrbitSpinChanged: orbitCanvas.requestPaint()
    onHasQueryChanged: orbitCanvas.requestPaint()

    Connections {
        target: LauncherSearch
        function onQueryChanged() {
            root.resultOffset = 0;
            root.selectedIndex = 0;
        }
    }

    Connections {
        target: GlobalStates
        function onLauncherOpenChanged() {
            if (GlobalStates.launcherOpen) {
                root.resultOffset = 0;
                root.selectedIndex = 0;
                root.wheelAccumulator = 0;
                input.text = "";
                focusTimer.restart();
            } else {
                root.selectedIndex = 0;
                root.wheelAccumulator = 0;
                input.text = "";
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 80
        repeat: false
        onTriggered: input.forceActiveFocus()
    }

    WheelHandler {
        id: launcherWheel
        target: root
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y;
            if (delta !== 0) {
                root.wheelAccumulator += delta;
                
                // One full swipe (360 delta) rotates one full circle (itemCount steps)
                const stepThreshold = 360 / Math.max(1, root.itemCount);
                
                while (Math.abs(root.wheelAccumulator) >= stepThreshold) {
                    if (root.wheelAccumulator > 0) {
                        root.rotateSelection(-1);
                        root.wheelAccumulator -= stepThreshold;
                    } else {
                        root.rotateSelection(1);
                        root.wheelAccumulator += stepThreshold;
                    }
                }
                event.accepted = true;
            }
        }
    }

    Item {
        id: dialContainer
        anchors.fill: parent
        
        property real targetRotation: 0
        rotation: targetRotation

        Behavior on rotation {
            NumberAnimation { duration: 450; easing.type: Easing.OutQuint }
        }

        Canvas {
            id: orbitCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                const cx = root.centerX;
                const cy = root.centerY;
                const minSide = Math.min(width, height);
                const rings = [0.19, 0.28, 0.37];

                for (let r = 0; r < rings.length; r++) {
                    ctx.beginPath();
                    ctx.arc(cx, cy, minSide * rings[r], 0, Math.PI * 2);
                    ctx.shadowBlur = 0; // Disabled for performance
                    ctx.strokeStyle = Functions.ColorUtils.applyAlpha(r % 2 === 0 ? "#16cfd5" : "#e94eb5", 0.34);
                    ctx.lineWidth = (r === 1 ? 1.7 : 1.2) * root.u;
                    ctx.stroke();
                }

                for (let i = 0; i < root.itemCount; i++) {
                    const nx = root.staticNodeX(i, root.itemCount);
                    const ny = root.staticNodeY(i, root.itemCount);
                    const accent = root.accentFor(i);

                    ctx.beginPath();
                    ctx.moveTo(cx, cy);
                    ctx.quadraticCurveTo(cx + (nx - cx) * 0.34, cy + (ny - cy) * 0.34, nx, ny);
                    ctx.shadowBlur = 0; // Disabled for performance
                    ctx.strokeStyle = Functions.ColorUtils.applyAlpha(accent, i === root.selectedIndex ? 0.92 : 0.46);
                    ctx.lineWidth = (i === root.selectedIndex ? 2.8 : 1.5) * root.u;
                    ctx.stroke();

                    ctx.beginPath();
                    ctx.arc(nx, ny, 4.5 * root.u, 0, Math.PI * 2);
                    ctx.fillStyle = Functions.ColorUtils.applyAlpha(accent, 0.95);
                    ctx.fill();

                    ctx.beginPath();
                    const dotAngle = (root.orbitSpin + i * 64) * Math.PI / 180;
                    ctx.arc(cx + Math.cos(dotAngle) * minSide * 0.27, cy + Math.sin(dotAngle) * minSide * 0.27, 2.8 * root.u, 0, Math.PI * 2);
                    ctx.fillStyle = Functions.ColorUtils.applyAlpha(i % 2 === 0 ? "#44f0f3" : "#ff79cf", 0.72);
                    ctx.fill();
                }
            }
        }

        Repeater {
            model: root.displayItems

            delegate: Item {
                id: planet
                required property var modelData
                required property int index

                readonly property real globalAngle: root.staticAngleForIndex(index, root.itemCount) + dialContainer.rotation
                readonly property real angleRad: globalAngle * Math.PI / 180
                readonly property bool leftSide: Math.cos(angleRad) < -0.18
                readonly property bool selected: root.selectedIndex === index
                readonly property color accent: root.accentFor(index)
                readonly property real nodeCenterX: root.staticNodeX(index, root.itemCount)
                readonly property real nodeCenterY: root.staticNodeY(index, root.itemCount)

                width: root.nodeSize + root.pillWidth + 18 * root.u
                height: root.nodeSize + 10 * root.u
                x: nodeCenterX - (leftSide ? width - root.nodeSize / 2 : root.nodeSize / 2)
                y: nodeCenterY - height / 2
                z: selected ? 20 : 8
                opacity: 1
                scale: selected ? 1.08 : 1.0

                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: labelPill
                    x: planet.leftSide ? 0 : root.nodeSize * 0.58
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.pillWidth
                    height: root.pillHeight
                    radius: height / 2
                    color: Functions.ColorUtils.applyAlpha("#090d11", planet.selected ? 0.96 : 0.90)
                    border.width: Math.max(1, 1.2 * root.u)
                    border.color: Functions.ColorUtils.applyAlpha(planet.accent, planet.selected ? 0.98 : 0.70)
                    antialiasing: true

                    // Counter-rotate label to keep it perfectly horizontal
                    rotation: -dialContainer.rotation

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1 * root.u
                        radius: parent.radius - 1 * root.u
                        color: Functions.ColorUtils.applyAlpha(planet.accent, planet.selected ? 0.10 : 0.035)
                        antialiasing: true
                    }

                    StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: planet.leftSide ? 16 * root.u : 44 * root.u
                        anchors.rightMargin: planet.leftSide ? 44 * root.u : 16 * root.u
                        text: modelData.name || modelData.id || ""
                        color: "#f8fbff"
                        font.pixelSize: 13 * root.u
                        font.weight: Font.Medium
                        horizontalAlignment: planet.leftSide ? Text.AlignRight : Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: nodeGlow
                    x: planet.leftSide ? root.pillWidth + 14 * root.u : 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.nodeSize
                    height: root.nodeSize
                    radius: width / 2
                    color: Functions.ColorUtils.applyAlpha(planet.accent, planet.selected ? 0.40 : 0.24)
                    antialiasing: true

                    // Counter-rotate icon node to keep it perfectly upright
                    rotation: -dialContainer.rotation

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 12 * root.u
                        height: width
                        radius: width / 2
                        color: Functions.ColorUtils.applyAlpha("#090d11", 0.98)
                        border.width: Math.max(1, 1.4 * root.u)
                        border.color: Functions.ColorUtils.applyAlpha(planet.accent, planet.selected ? 0.96 : 0.64)
                        antialiasing: true
                    }

                    IconImage {
                        anchors.centerIn: parent
                        width: 32 * root.u
                        height: 32 * root.u
                        source: Quickshell.iconPath(modelData.icon || "application-x-executable", "application-x-executable")
                        visible: !modelData.isPlugin
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: modelData.icon || "apps"
                        iconSize: 31 * root.u
                        color: "#f8fbff"
                        visible: modelData.isPlugin
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedIndex = index;
                        root.executeSelected();
                    }
                }
            }
        }
    }

    Rectangle {
        id: hubGlow
        anchors.centerIn: parent
        width: root.hubSize + 34 * root.u
        height: width
        radius: width / 2
        color: Functions.ColorUtils.applyAlpha("#44f0f3", 0.11)
        border.width: Math.max(1, 2 * root.u)
        border.color: Functions.ColorUtils.applyAlpha("#ff79cf", 0.48)
        antialiasing: true

        Rectangle {
            anchors.centerIn: parent
                width: root.hubSize
                height: width
                radius: width / 2
            color: Functions.ColorUtils.applyAlpha("#080c10", 0.97)
            border.width: Math.max(1, 2 * root.u)
            border.color: Functions.ColorUtils.applyAlpha("#44f0f3", 0.86)
            antialiasing: true

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 34 * root.u
                height: width
                radius: width / 2
                color: Functions.ColorUtils.applyAlpha("#05070b", 0.52)
                border.width: Math.max(1, 1.3 * root.u)
                border.color: Functions.ColorUtils.applyAlpha("#b79cff", 0.72)
                antialiasing: true
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -18 * root.u
                text: ":3"
                color: "#f8fbff"
                font.pixelSize: 32 * root.u
                font.weight: Font.DemiBold
            }

            TextInput {
                id: input
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 28 * root.u
                width: 116 * root.u
                height: 30 * root.u
                focus: true
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 13 * root.u
                font.weight: Font.Medium
                color: "#f8fbff"
                selectedTextColor: Appearance.colors.colOnPrimary
                selectionColor: Appearance.colors.colPrimary
                clip: true

                Text {
                    anchors.centerIn: parent
                    text: root.hasQuery ? "" : "search"
                    color: Functions.ColorUtils.applyAlpha("#f8fbff", 0.66)
                    font: input.font
                    visible: input.text.length === 0
                }

                onTextChanged: debounceTimer.restart()
                onAccepted: root.executeSelected()

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.launcherOpen = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                        root.isKeyboardNavigation = true;
                        root.rotateSelection(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        root.isKeyboardNavigation = true;
                        root.rotateSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.executeSelected();
                        event.accepted = true;
                    }
                }

                Timer {
                    id: debounceTimer
                    interval: 20
                    repeat: false
                    onTriggered: LauncherSearch.query = input.text
                }
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20 * root.u
        width: Math.min(parent.width - 80 * root.u, 420 * root.u)
        text: root.itemCount > 0
            ? ((root.hasQuery ? "search" : "recent") + " / " + (root.displayItems[root.selectedIndex] ? root.displayItems[root.selectedIndex].name : "apps") + (root.resultCount > root.itemCount ? "  " + (root.resultOffset + 1) + "-" + Math.min(root.resultOffset + root.itemCount, root.resultCount) + "/" + root.resultCount : ""))
            : "no results"
        color: Functions.ColorUtils.applyAlpha("#f8fbff", 0.88)
        font.pixelSize: 12 * root.u
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }
}
