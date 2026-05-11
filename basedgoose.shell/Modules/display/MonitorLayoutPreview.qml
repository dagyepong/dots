pragma ComponentBehavior: Bound
import QtQuick 6.10
import "../../Commons" as Commons
import "../../Widgets" as Widgets

Rectangle {
    id: root

    property var monitorsModel: null

    property var pendingChanges: ({})

    readonly property color cSurface: Commons.Theme.background
    readonly property color cSurfaceContainer: Qt.lighter(Commons.Theme.background, 1.15)
    readonly property color cPrimary: Commons.Theme.secondary
    readonly property color cText: Commons.Theme.foreground
    readonly property color cSubText: Qt.rgba(cText.r, cText.g, cText.b, 0.6)
    readonly property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.15)

    signal positionsChanged(var positions)

    property string selectedMonitor: ""
    property bool isDragging: false

    function getEffectivePosition(monitor) {
        var changes = pendingChanges[monitor.name];
        return {
            x: (changes && changes.positionX !== undefined) ? changes.positionX : monitor.positionX,
            y: (changes && changes.positionY !== undefined) ? changes.positionY : monitor.positionY
        };
    }

    function getMonitorsAtPosition(posX, posY) {
        var monitors = [];
        if (!monitorsModel)
            return monitors;

        for (var i = 0; i < monitorsModel.count; i++) {
            var monitor = monitorsModel.get(i);
            var pos = getEffectivePosition(monitor);
            if (pos.x === posX && pos.y === posY) {
                monitors.push(monitor);
            }
        }
        return monitors;
    }

    function areMonitorsAdjacent(mon1, pos1, mon2, pos2) {
        var m1Left = pos1.x;
        var m1Right = pos1.x + mon1.monitorWidth;
        var m1Top = pos1.y;
        var m1Bottom = pos1.y + mon1.monitorHeight;

        var m2Left = pos2.x;
        var m2Right = pos2.x + mon2.monitorWidth;
        var m2Top = pos2.y;
        var m2Bottom = pos2.y + mon2.monitorHeight;

        var horizontalAdjacent = (m1Right === m2Left || m1Left === m2Right) && !(m1Bottom <= m2Top || m1Top >= m2Bottom);

        var verticalAdjacent = (m1Bottom === m2Top || m1Top === m2Bottom) && !(m1Right <= m2Left || m1Left >= m2Right);

        return horizontalAdjacent || verticalAdjacent;
    }

    function findNearestAdjacentPosition(monitor, targetX, targetY) {
        if (!monitorsModel || monitorsModel.count <= 1) {
            return {
                x: Math.max(0, targetX),
                y: Math.max(0, targetY)
            };
        }

        var bestX = Math.max(0, targetX);
        var bestY = Math.max(0, targetY);
        var bestDistance = Infinity;

        for (var i = 0; i < monitorsModel.count; i++) {
            var other = monitorsModel.get(i);
            if (other.name === monitor.name)
                continue;
            var otherPos = getEffectivePosition(other);
            var otherLeft = otherPos.x;
            var otherRight = otherPos.x + other.monitorWidth;
            var otherTop = otherPos.y;
            var otherBottom = otherPos.y + other.monitorHeight;

            var x1 = otherRight;
            if (x1 >= 0) {
                var yMin1 = Math.max(0, otherTop - monitor.monitorHeight + 1);
                var yMax1 = otherBottom - 1;
                if (yMin1 <= yMax1) {
                    var y1 = Math.max(yMin1, Math.min(yMax1, targetY));
                    var dist = Math.abs(x1 - targetX) + Math.abs(y1 - targetY);
                    if (dist < bestDistance) {
                        bestX = x1;
                        bestY = y1;
                        bestDistance = dist;
                    }
                }
            }

            var x2 = otherLeft - monitor.monitorWidth;
            if (x2 >= 0) {
                // Find valid y range for adjacency
                var yMin2 = Math.max(0, otherTop - monitor.monitorHeight + 1);
                var yMax2 = otherBottom - 1;
                if (yMin2 <= yMax2) {
                    var y2 = Math.max(yMin2, Math.min(yMax2, targetY));
                    var dist = Math.abs(x2 - targetX) + Math.abs(y2 - targetY);
                    if (dist < bestDistance) {
                        bestX = x2;
                        bestY = y2;
                        bestDistance = dist;
                    }
                }
            }

            var y3 = otherBottom;
            if (y3 >= 0) {
                var xMin3 = Math.max(0, otherLeft - monitor.monitorWidth + 1);
                var xMax3 = otherRight - 1;
                if (xMin3 <= xMax3) {
                    var x3 = Math.max(xMin3, Math.min(xMax3, targetX));
                    var dist = Math.abs(x3 - targetX) + Math.abs(y3 - targetY);
                    if (dist < bestDistance) {
                        bestX = x3;
                        bestY = y3;
                        bestDistance = dist;
                    }
                }
            }

            var y4 = otherTop - monitor.monitorHeight;
            if (y4 >= 0) {
                var xMin4 = Math.max(0, otherLeft - monitor.monitorWidth + 1);
                var xMax4 = otherRight - 1;
                if (xMin4 <= xMax4) {
                    var x4 = Math.max(xMin4, Math.min(xMax4, targetX));
                    var dist = Math.abs(x4 - targetX) + Math.abs(y4 - targetY);
                    if (dist < bestDistance) {
                        bestX = x4;
                        bestY = y4;
                        bestDistance = dist;
                    }
                }
            }
        }

        return {
            x: bestX,
            y: bestY
        };
    }

    function normalizePositions(positions) {
        if (!monitorsModel || monitorsModel.count === 0)
            return positions;

        var minX = Infinity;
        var minY = Infinity;

        for (var i = 0; i < monitorsModel.count; i++) {
            var monitor = monitorsModel.get(i);
            var pos = positions[monitor.name];
            if (!pos) {
                pos = getEffectivePosition(monitor);
            }
            if (pos.x < minX)
                minX = pos.x;
            if (pos.y < minY)
                minY = pos.y;
        }

        if (minX !== 0 || minY !== 0) {
            var normalized = {};
            for (var i = 0; i < monitorsModel.count; i++) {
                var monitor = monitorsModel.get(i);
                var pos = positions[monitor.name];
                if (!pos) {
                    pos = getEffectivePosition(monitor);
                }
                normalized[monitor.name] = {
                    x: pos.x - minX,
                    y: pos.y - minY
                };
            }
            return normalized;
        }

        return positions;
    }

    function resetLayout() {
        if (!monitorsModel || monitorsModel.count === 0)
            return;
        var positions = {};
        var currentX = 0;

        for (var i = 0; i < monitorsModel.count; i++) {
            var monitor = monitorsModel.get(i);
            positions[monitor.name] = {
                x: currentX,
                y: 0
            };
            currentX += monitor.monitorWidth;
        }

        positionsChanged(positions);
    }

    color: Qt.darker(cSurface, 1.3)
    radius: Commons.Theme.radius
    border.color: cBorder
    border.width: 1

    property real minX: 0
    property real minY: 0

    property real maxX: {
        var max = 1920;
        if (!monitorsModel)
            return 1920;
        for (var i = 0; i < monitorsModel.count; i++) {
            var m = monitorsModel.get(i);
            var pos = getEffectivePosition(m);
            var right = pos.x + m.monitorWidth;
            if (right > max)
                max = right;
        }
        return max;
    }

    property real maxY: {
        var max = 1080;
        if (!monitorsModel)
            return 1080;
        for (var i = 0; i < monitorsModel.count; i++) {
            var m = monitorsModel.get(i);
            var pos = getEffectivePosition(m);
            var bottom = pos.y + m.monitorHeight;
            if (bottom > max)
                max = bottom;
        }
        return max;
    }

    property real totalWidth: maxX - minX
    property real totalHeight: maxY - minY

    property real padding: 24
    property real availableWidth: width - padding * 2
    property real availableHeight: height - padding * 2
    property real scaleX: totalWidth > 0 ? availableWidth / totalWidth : 1
    property real scaleY: totalHeight > 0 ? availableHeight / totalHeight : 1
    property real displayScale: Math.min(scaleX, scaleY, 0.15) // Cap at 0.15 to not make tiny monitors too big

    property real offsetX: padding + (availableWidth - totalWidth * displayScale) / 2
    property real offsetY: padding + (availableHeight - totalHeight * displayScale) / 2

    Item {
        id: monitorContainer
        anchors.fill: parent

        Repeater {
            model: monitorsModel

            delegate: Rectangle {
                id: monitorRect

                required property string name
                required property int positionX
                required property int positionY
                required property int monitorWidth
                required property int monitorHeight
                required property real monitorScale
                required property int index

                property real originalMonitorX: 0
                property real originalMonitorY: 0

                property bool isSnapping: false

                readonly property int effectivePosX: (root.pendingChanges[name] && root.pendingChanges[name].positionX !== undefined) ? root.pendingChanges[name].positionX : positionX
                readonly property int effectivePosY: (root.pendingChanges[name] && root.pendingChanges[name].positionY !== undefined) ? root.pendingChanges[name].positionY : positionY

                readonly property bool hasPendingPosition: !!(root.pendingChanges[name] && (root.pendingChanges[name].positionX !== undefined || root.pendingChanges[name].positionY !== undefined))

                property real baseX: root.offsetX + (effectivePosX - root.minX) * root.displayScale
                property real baseY: root.offsetY + (effectivePosY - root.minY) * root.displayScale

                x: baseX
                y: baseY

                function applySnapping() {
                    if (!monitorArea.drag.active || isSnapping)
                        return;
                    isSnapping = true;

                    var draggedPreviewX = x;
                    var draggedPreviewY = y;

                    var monitorPos = previewToMonitor(draggedPreviewX, draggedPreviewY);

                    var clampedX = Math.max(0, monitorPos.x);
                    var clampedY = Math.max(0, monitorPos.y);

                    var currentMonitor = {
                        name: name,
                        monitorWidth: monitorWidth,
                        monitorHeight: monitorHeight
                    };

                    var testPos = {
                        x: clampedX,
                        y: clampedY
                    };
                    var isAdjacent = false;
                    for (var i = 0; i < root.monitorsModel.count; i++) {
                        var other = root.monitorsModel.get(i);
                        if (other.name === name)
                            continue;
                        var otherPos = root.getEffectivePosition(other);
                        if (root.areMonitorsAdjacent(currentMonitor, testPos, other, otherPos)) {
                            isAdjacent = true;
                            break;
                        }
                    }

                    var finalPos = isAdjacent ? testPos : root.findNearestAdjacentPosition(currentMonitor, clampedX, clampedY);

                    var snappedMonitorX = Math.round(finalPos.x / 10) * 10;
                    var snappedMonitorY = Math.round(finalPos.y / 10) * 10;

                    snappedMonitorX = Math.max(0, snappedMonitorX);
                    snappedMonitorY = Math.max(0, snappedMonitorY);

                    var snappedPreviewX = root.offsetX + (snappedMonitorX - root.minX) * root.displayScale;
                    var snappedPreviewY = root.offsetY + (snappedMonitorY - root.minY) * root.displayScale;

                    x = snappedPreviewX;
                    y = snappedPreviewY;

                    isSnapping = false;
                }

                onXChanged: {
                    if (monitorArea.drag.active && !isSnapping) {
                        applySnapping();
                    }
                }

                onYChanged: {
                    if (monitorArea.drag.active && !isSnapping) {
                        applySnapping();
                    }
                }
                width: monitorWidth * root.displayScale
                height: monitorHeight * root.displayScale

                function previewToMonitor(previewX, previewY) {
                    return {
                        x: ((previewX - root.offsetX) / root.displayScale) + root.minX,
                        y: ((previewY - root.offsetY) / root.displayScale) + root.minY
                    };
                }

                color: monitorArea.drag.active ? Qt.lighter(root.cSurfaceContainer, 1.2) : (monitorArea.containsMouse ? Qt.lighter(root.cSurfaceContainer, 1.1) : root.cSurfaceContainer)
                border.color: hasPendingPosition ? root.cPrimary : (root.selectedMonitor === name ? root.cPrimary : root.cBorder)
                border.width: (root.selectedMonitor === name || hasPendingPosition) ? 2 : 1
                radius: Commons.Theme.radiusSm

                Behavior on color {
                    enabled: !monitorArea.drag.active
                    ColorAnimation {
                        duration: 100
                    }
                }

                Behavior on border.color {
                    enabled: !monitorArea.drag.active
                    ColorAnimation {
                        duration: 100
                    }
                }

                Behavior on x {
                    enabled: !monitorArea.drag.active
                    NumberAnimation {
                        duration: 0
                    }
                }

                Behavior on y {
                    enabled: !monitorArea.drag.active
                    NumberAnimation {
                        duration: 0
                    }
                }

                readonly property var monitorsAtThisPosition: root.getMonitorsAtPosition(effectivePosX, effectivePosY)
                readonly property bool isMirrored: monitorsAtThisPosition.length > 1

                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    visible: parent.width > 60 && parent.height > 40

                    Repeater {
                        model: monitorRect.isMirrored ? monitorRect.monitorsAtThisPosition.length : 1

                        delegate: Column {
                            required property int index
                            spacing: 1

                            Text {
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                text: {
                                    if (monitorRect.isMirrored && monitorRect.monitorsAtThisPosition && monitorRect.monitorsAtThisPosition[parent.index]) {
                                        return monitorRect.monitorsAtThisPosition[parent.index].name;
                                    }
                                    return monitorRect.name;
                                }
                                font.family: Commons.Theme.fontUI
                                font.pixelSize: {
                                    if (parent && parent.parent && parent.parent.parent) {
                                        return Math.max(9, Math.min(12, parent.parent.parent.width / (monitorRect.isMirrored ? 10 : 8)));
                                    }
                                    return 10;
                                }
                                font.weight: Font.Medium
                                color: root.cText
                                opacity: 0.9
                            }

                            Text {
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                                visible: (monitorRect.isMirrored && parent.index === 0) || !monitorRect.isMirrored
                                text: {
                                    if (monitorRect.isMirrored && monitorRect.monitorsAtThisPosition && monitorRect.monitorsAtThisPosition[parent.index]) {
                                        var m = monitorRect.monitorsAtThisPosition[parent.index];
                                        return m.monitorWidth + "x" + m.monitorHeight;
                                    } else {
                                        return monitorRect.monitorWidth + "x" + monitorRect.monitorHeight;
                                    }
                                }
                                font.family: Commons.Theme.fontUI
                                font.pixelSize: {
                                    if (parent && parent.parent && parent.parent.parent) {
                                        return Math.max(7, Math.min(9, parent.parent.parent.width / 14));
                                    }
                                    return 8;
                                }
                                color: root.cSubText
                            }
                        }
                    }
                }

                MouseArea {
                    id: monitorArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    drag.target: monitorRect
                    drag.axis: Drag.XAndYAxis

                    onPressed: function (mouse) {
                        root.selectedMonitor = monitorRect.name;
                        monitorRect.originalMonitorX = monitorRect.effectivePosX;
                        monitorRect.originalMonitorY = monitorRect.effectivePosY;
                        root.isDragging = true;
                    }

                    onReleased: function (mouse) {
                        if (!drag.active)
                            return;
                        var draggedPreviewX = monitorRect.x;
                        var draggedPreviewY = monitorRect.y;

                        var monitorPos = monitorRect.previewToMonitor(draggedPreviewX, draggedPreviewY);

                        var clampedX = Math.max(0, monitorPos.x);
                        var clampedY = Math.max(0, monitorPos.y);

                        var currentMonitor = {
                            name: monitorRect.name,
                            monitorWidth: monitorRect.monitorWidth,
                            monitorHeight: monitorRect.monitorHeight
                        };

                        var testPos = {
                            x: clampedX,
                            y: clampedY
                        };
                        var isAdjacent = false;
                        for (var i = 0; i < root.monitorsModel.count; i++) {
                            var other = root.monitorsModel.get(i);
                            if (other.name === monitorRect.name)
                                continue;
                            var otherPos = root.getEffectivePosition(other);
                            if (root.areMonitorsAdjacent(currentMonitor, testPos, other, otherPos)) {
                                isAdjacent = true;
                                break;
                            }
                        }

                        var finalPos = isAdjacent ? testPos : root.findNearestAdjacentPosition(currentMonitor, clampedX, clampedY);

                        var snappedX = Math.round(finalPos.x / 10) * 10;
                        var snappedY = Math.round(finalPos.y / 10) * 10;

                        snappedX = Math.max(0, snappedX);
                        snappedY = Math.max(0, snappedY);

                        root.isDragging = false;

                        if (snappedX !== monitorRect.originalMonitorX || snappedY !== monitorRect.originalMonitorY) {
                            var positions = {};

                            positions[monitorRect.name] = {
                                x: snappedX,
                                y: snappedY
                            };

                            for (var i = 0; i < root.monitorsModel.count; i++) {
                                var other = root.monitorsModel.get(i);
                                if (other.name !== monitorRect.name) {
                                    var otherPos = root.getEffectivePosition(other);
                                    positions[other.name] = {
                                        x: otherPos.x,
                                        y: otherPos.y
                                    };
                                }
                            }

                            var normalizedPositions = root.normalizePositions(positions);

                            root.positionsChanged(normalizedPositions);
                        }
                    }
                }
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 6
        spacing: 12
        height: 20

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: isDragging ? "Release to set position" : "Drag monitors to reposition"
            font.family: Commons.Theme.fontUI
            font.pixelSize: 10
            color: cSubText
            opacity: 0.7
        }

        Widgets.IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "󰑐"
            iconSize: 14
            iconColor: cSubText
            hoverIconColor: cText
            baseColor: "transparent"
            hoverColor: Qt.rgba(cText.r, cText.g, cText.b, 0.08)
            pressedColor: Qt.rgba(cText.r, cText.g, cText.b, 0.12)
            implicitWidth: 20
            implicitHeight: 20
            visible: monitorsModel && monitorsModel.count > 0

            onClicked: {
                root.resetLayout();
            }
        }
    }
}
