import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import Quickshell
import "../../Commons" as Commons
import "../../Widgets" as Widgets
import "../../Services" as Services

Widgets.PopupWindow {
    id: popupWindow

    ipcTarget: "settings"
    initialScale: 0.94
    transformOriginX: 0.5
    transformOriginY: 0.5
    closeOnClickOutside: false

    anchors {
        top: true
        left: true
    }

    margins {
        top: Quickshell.screens[0] ? (Quickshell.screens[0].height - implicitHeight) / 2 : 100
        left: Quickshell.screens[0] ? (Quickshell.screens[0].width - implicitWidth) / 2 : 100
    }

    readonly property color cSurface: Commons.Theme.background
    readonly property color cSurfaceContainer: Qt.lighter(Commons.Theme.background, 1.15)
    readonly property color cPrimary: Commons.Theme.secondary
    readonly property color cText: Commons.Theme.foreground
    readonly property color cSubText: Qt.rgba(cText.r, cText.g, cText.b, 0.6)
    readonly property color cBorder: Qt.rgba(cText.r, cText.g, cText.b, 0.08)
    readonly property color cHover: Qt.rgba(cText.r, cText.g, cText.b, 0.06)

    implicitWidth: 600
    implicitHeight: 640

    property Component moduleChipComponent: Component {
        Item {
            id: chipContainer

            property string moduleName: ""
            property bool isDraggable: true
            property string sourceSection: ""
            property int sourceIndex: -1
            property color chipColor: Qt.rgba(popupWindow.cText.r, popupWindow.cText.g, popupWindow.cText.b, 0.08)
            property color chipBorderColor: Qt.rgba(popupWindow.cText.r, popupWindow.cText.g, popupWindow.cText.b, 0.2)
            property color chipTextColor: popupWindow.cText

            implicitWidth: chipText.implicitWidth + 20
            implicitHeight: 28
            width: implicitWidth
            height: implicitHeight

            Rectangle {
                id: chip
                anchors.fill: parent
                radius: Commons.Theme.radiusSm
                color: chipContainer.chipColor
                border.color: chipContainer.chipBorderColor
                border.width: 1
                opacity: dragArea.pressed ? 0.5 : 1

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chipContainer.moduleName
                    font.family: Commons.Theme.fontMono
                    font.pixelSize: 11
                    color: chipContainer.chipTextColor
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                drag.target: chipContainer.isDraggable ? dragItem : null

                Item {
                    id: dragItem
                    visible: dragArea.drag.active

                    Drag.active: dragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.MoveAction
                    Drag.keys: ["text/plain"]
                    Drag.mimeData: {
                        "text/plain": "module:" + chipContainer.moduleName + ":" + chipContainer.sourceSection + ":" + chipContainer.sourceIndex
                    }

                    Rectangle {
                        width: chipContainer.width
                        height: chipContainer.height
                        radius: chip.radius
                        color: chipContainer.chipColor
                        border.color: chipContainer.chipBorderColor
                        border.width: 1
                        opacity: 0.8

                        Text {
                            anchors.centerIn: parent
                            text: chipContainer.moduleName
                            font.family: Commons.Theme.fontMono
                            font.pixelSize: 11
                            color: chipContainer.chipTextColor
                        }
                    }
                }
            }
        }
    }

    function addModuleToSection(moduleName, section) {
        var updatedBarModules = cloneBarModules()
        if (!updatedBarModules[section]) {
            updatedBarModules[section] = []
        }
        if (updatedBarModules[section].indexOf(moduleName) === -1) {
            updatedBarModules[section].push(moduleName)
            Services.ConfigService.setBarModules(updatedBarModules)
        }
    }

    function removeModuleFromSection(moduleName, section) {
        var updatedBarModules = cloneBarModules()
        if (updatedBarModules[section]) {
            var index = updatedBarModules[section].indexOf(moduleName)
            if (index !== -1) {
                updatedBarModules[section].splice(index, 1)
                Services.ConfigService.setBarModules(updatedBarModules)
            }
        }
    }

    function cloneBarModules() {
        var current = Services.ConfigService.barModules || {}
        return {
            "left": (current.left || []).slice(),
            "center": (current.center || []).slice(),
            "right": (current.right || []).slice()
        }
    }

    function moveModuleToSection(moduleName, sourceSection, targetSection, targetIndex) {
        var updatedBarModules = cloneBarModules()
        if (!updatedBarModules[targetSection]) {
            updatedBarModules[targetSection] = []
        }

        var sourceModules = sourceSection !== "" && updatedBarModules[sourceSection] ? updatedBarModules[sourceSection] : null
        var removeIndex = -1
        if (sourceModules) {
            removeIndex = sourceModules.indexOf(moduleName)
            if (removeIndex !== -1) {
                sourceModules.splice(removeIndex, 1)
            }
        }

        var targetModules = updatedBarModules[targetSection]
        var existingTargetIndex = targetModules.indexOf(moduleName)
        if (existingTargetIndex !== -1) {
            targetModules.splice(existingTargetIndex, 1)
        }

        var insertionIndex = typeof targetIndex === "number" ? targetIndex : targetModules.length
        if (sourceSection === targetSection && removeIndex !== -1 && removeIndex < insertionIndex) {
            insertionIndex -= 1
        }
        insertionIndex = Math.max(0, Math.min(insertionIndex, targetModules.length))
        targetModules.splice(insertionIndex, 0, moduleName)

        Services.ConfigService.setBarModules(updatedBarModules)
    }

    function getDropInsertionIndex(flowItem, dropX, dropY, fallbackIndex) {
        for (var i = 0; i < flowItem.children.length; i++) {
            var child = flowItem.children[i]
            if (child.moduleIndex === undefined || child.width <= 0 || child.height <= 0) {
                continue
            }
            if (dropY < child.y + child.height / 2) {
                return child.moduleIndex
            }
            if (dropY < child.y + child.height && dropX < child.x + child.width / 2) {
                return child.moduleIndex
            }
        }
        return fallbackIndex
    }

    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        color: Commons.Theme.background
        radius: Commons.Theme.radiusPanel
        border.color: cBorder
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.35)
            shadowBlur: 1.0
            shadowVerticalOffset: 6
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Widgets.HeaderWithIcon {
                Layout.fillWidth: true
                icon: "\uf013"
                title: "Settings"
                subtitle: "Configure basedgoose.shell"
                iconColor: cPrimary
                titleColor: cText
                subtitleColor: cSubText
            }

            Widgets.Divider {
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
radius: Commons.Theme.radius
        color: cSurfaceContainer
                clip: true

                Flickable {
                    id: settingsFlickable
                    anchors.fill: parent
                    anchors.margins: 16
                    contentWidth: width
                    contentHeight: settingsColumn.height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    ColumnLayout {
                        id: settingsColumn
                        width: settingsFlickable.width
                        spacing: 20

                        // Bar Position Section
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Widgets.SectionLabel {
                                Layout.fillWidth: true
                                text: "Bar Position"
                                color: cText
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Choose where the bar appears on your screen"
                                font.family: Commons.Theme.fontUI
                                font.pixelSize: 12
                                color: cSubText
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: [
                                        { value: "top", label: "Top" },
                                        { value: "bottom", label: "Bottom" },
                                        { value: "left", label: "Left" },
                                        { value: "right", label: "Right" }
                                    ]

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        radius: Commons.Theme.radius
                                        color: Services.ConfigService.barPosition === modelData.value ? 
                                               Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.15) : 
                                               Qt.rgba(cText.r, cText.g, cText.b, 0.03)
                                        border.color: Services.ConfigService.barPosition === modelData.value ? 
                                                     cPrimary : 
                                                     Qt.rgba(cText.r, cText.g, cText.b, 0.1)
                                        border.width: Services.ConfigService.barPosition === modelData.value ? 2 : 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            font.family: Commons.Theme.fontUI
                                            font.pixelSize: 13
                                            color: Services.ConfigService.barPosition === modelData.value ? 
                                                   cText : cSubText
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                Services.ConfigService.setBarPosition(modelData.value)
                                                Quickshell.reload(true)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Bar Modules Section
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Widgets.SectionLabel {
                                Layout.fillWidth: true
                                text: "Bar Modules"
                                color: cText
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Drag and drop modules to arrange them in the bar"
                                font.family: Commons.Theme.fontUI
                                font.pixelSize: 12
                                color: cSubText
                                wrapMode: Text.WordWrap
                            }

                            // Available modules
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: "Available Modules"
                                    font.family: Commons.Theme.fontUI
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    color: cText
                                }

                                Rectangle {
                                    id: modulePool
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: 80
                                    Layout.preferredHeight: Math.max(80, availableFlow.implicitHeight + 16)
                                    radius: Commons.Theme.radius
                                    color: Qt.rgba(Commons.Theme.primary.r, Commons.Theme.primary.g, Commons.Theme.primary.b, 0.08)
                                    border.color: Qt.rgba(Commons.Theme.primary.r, Commons.Theme.primary.g, Commons.Theme.primary.b, 0.2)
                                    border.width: 1

                                    property var availableModules: ["shellmenu", "workspaces", "mediaplayer", "systemstats", "clock", "systemtray", "volume", "network", "bluetooth", "notifications", "power"]
                                    property var usedModules: {
                                        var used = []
                                        if (Services.ConfigService.barModules.left) used = used.concat(Services.ConfigService.barModules.left)
                                        if (Services.ConfigService.barModules.center) used = used.concat(Services.ConfigService.barModules.center)
                                        if (Services.ConfigService.barModules.right) used = used.concat(Services.ConfigService.barModules.right)
                                        return used
                                    }

                                    Flow {
                                        id: availableFlow
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        Repeater {
                                            model: modulePool.availableModules.filter(function(m) {
                                                return modulePool.usedModules.indexOf(m) === -1
                                            })

                                            delegate: Loader {
                                                sourceComponent: moduleChipComponent

                                                property string moduleName: modelData
                                                property bool isDraggable: true
                                                property color chipColor: Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.15)
                                                property color chipBorderColor: cPrimary
                                                property color chipTextColor: cText

                                                onLoaded: {
                                                    item.moduleName = moduleName
                                                    item.isDraggable = isDraggable
                                                    item.sourceSection = ""
                                                    item.sourceIndex = -1
                                                    item.chipColor = chipColor
                                                    item.chipBorderColor = chipBorderColor
                                                    item.chipTextColor = chipTextColor
                                                }
                                            }
                                        }
                                    }

                                    DropArea {
                                        anchors.fill: parent
                                        keys: ["text/plain"]

                                        onDropped: function(drop) {
                                            console.log("[Drop] Pool received drop")
                                            var text = drop.getDataAsString("text/plain")
                                            console.log("[Drop] Data:", text)
                                            
                                            if (text.startsWith("module:")) {
                                                var parts = text.split(":")
                                                if (parts.length >= 3) {
                                                    var moduleName = parts[1]
                                                    var sourceSection = parts[2]
                                                    console.log("[Drop] Removing module:", moduleName, "from:", sourceSection)
                                                    if (sourceSection !== "") {
                                                        popupWindow.removeModuleFromSection(moduleName, sourceSection)
                                                    }
                                                    drop.accept()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Bar sections
                            Repeater {
                                model: ["left", "center", "right"]

                                delegate: ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    property string sectionName: modelData

                                    Text {
                                        text: modelData.charAt(0).toUpperCase() + modelData.slice(1) + ":"
                                        font.family: Commons.Theme.fontUI
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        color: cText
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.minimumHeight: 50
                                        Layout.preferredHeight: Math.max(50, moduleFlow.implicitHeight + 16)
                                        radius: Commons.Theme.radius
                                        color: dropArea.containsDrag ? 
                                               Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.15) :
                                               Qt.rgba(cText.r, cText.g, cText.b, 0.03)
                                        border.color: dropArea.containsDrag ?
                                                     cPrimary :
                                                     Qt.rgba(cText.r, cText.g, cText.b, 0.1)
                                        border.width: dropArea.containsDrag ? 2 : 1

                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.width { NumberAnimation { duration: 150 } }

                                        Flow {
                                            id: moduleFlow
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6

                                            Repeater {
                                                model: Services.ConfigService.barModules[sectionName] || []

                                                delegate: Item {
                                                    id: chipWrapper
                                                    property int moduleIndex: index
                                                    width: moduleLoader.item ? moduleLoader.item.width : 0
                                                    height: moduleLoader.item ? moduleLoader.item.height : 0

                                                    Loader {
                                                        id: moduleLoader
                                                        sourceComponent: moduleChipComponent

                                                        property string moduleName: modelData
                                                        property bool isDraggable: true
                                                        property string sourceSection: sectionName
                                                        property int sourceIndex: index
                                                        property color chipColor: Qt.rgba(cText.r, cText.g, cText.b, 0.08)
                                                        property color chipBorderColor: Qt.rgba(cText.r, cText.g, cText.b, 0.2)
                                                        property color chipTextColor: cText

                                                        onLoaded: {
                                                            item.moduleName = moduleName
                                                            item.isDraggable = isDraggable
                                                            item.sourceSection = sourceSection
                                                            item.sourceIndex = sourceIndex
                                                            item.chipColor = chipColor
                                                            item.chipBorderColor = chipBorderColor
                                                            item.chipTextColor = chipTextColor
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: (Services.ConfigService.barModules[sectionName] || []).length === 0
                                                text: "Drop modules here"
                                                font.family: Commons.Theme.fontUI
                                                font.pixelSize: 11
                                                color: cSubText
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        DropArea {
                                            id: dropArea
                                            anchors.fill: parent
                                            keys: ["text/plain"]

                                            onDropped: function(drop) {
                                                console.log("[Drop] Section", sectionName, "received drop")
                                                var text = drop.getDataAsString("text/plain")
                                                console.log("[Drop] Data:", text)
                                                
                                                if (text.startsWith("module:")) {
                                                    var parts = text.split(":")
                                                    if (parts.length >= 3) {
                                                        var moduleName = parts[1]
                                                        var sourceSection = parts[2]
                                                        var pointerX = drop.x !== undefined ? drop.x : (drop.position ? drop.position.x : 0)
                                                        var pointerY = drop.y !== undefined ? drop.y : (drop.position ? drop.position.y : 0)
                                                        var flowX = pointerX - moduleFlow.x
                                                        var flowY = pointerY - moduleFlow.y
                                                        var sectionModules = Services.ConfigService.barModules[sectionName] || []
                                                        var targetIndex = popupWindow.getDropInsertionIndex(moduleFlow, flowX, flowY, sectionModules.length)
                                                        console.log("[Drop] Moving module:", moduleName, "from:", sourceSection, "to:", sectionName)

                                                        popupWindow.moveModuleToSection(moduleName, sourceSection, sectionName, targetIndex)
                                                        drop.accept()
                                                    }
                                                }
                                            }

                                            onEntered: function(drag) {
                                                console.log("[Drop] Entered section:", sectionName)
                                            }

                                            onExited: {
                                                console.log("[Drop] Exited section:", sectionName)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Widgets.TextButton {
                    text: "Reload Shell"
                    baseColor: Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.15)
                    textColor: cText
                    hoverColor: Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.25)
                    onClicked: {
                        Quickshell.reload(true)
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Widgets.TextButton {
                    text: "Close"
                    baseColor: Qt.rgba(cText.r, cText.g, cText.b, 0.06)
                    textColor: cText
                    hoverColor: Qt.rgba(cText.r, cText.g, cText.b, 0.1)
                    onClicked: popupWindow.shouldShow = false
                }
            }
        }
    }
}
