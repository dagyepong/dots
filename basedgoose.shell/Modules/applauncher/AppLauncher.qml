import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "../../Commons" as Commons
import "../../Widgets" as Widgets

Widgets.PopupWindow {
    id: appLauncher

    ipcTarget: "launcher"
    initialScale: 0.94
    transformOriginX: 0.5
    transformOriginY: 0.5
    closeOnClickOutside: true

    onShouldShowChanged: if (shouldShow) searchInput.text = ""

    anchors {
        top: true
        left: true
    }

    margins {
        top: Quickshell.screens[0] ? (Quickshell.screens[0].height - implicitHeight) / 2 : 100
        left: Quickshell.screens[0] ? (Quickshell.screens[0].width - implicitWidth) / 2 : 100
    }
    
    readonly property color cSurface: Commons.Theme.surfaceBase
    readonly property color cSurfaceContainer: Commons.Theme.surfaceContainer
    readonly property color cText: Commons.Theme.foreground
    readonly property color cSubText: Qt.rgba(cText.r, cText.g, cText.b, 0.6)
    readonly property color cBorder: Commons.Theme.surfaceBorder
    readonly property color cHover: Qt.rgba(cText.r, cText.g, cText.b, 0.06)
    readonly property color cPrimary: Commons.Theme.secondary
    
    readonly property int launcherWidth: 420
    readonly property int launcherHeight: 500
    
    implicitWidth: launcherWidth
    implicitHeight: launcherHeight
    
    Rectangle {
        anchors.fill: backgroundRect
        anchors.margins: -6
        radius: backgroundRect.radius + 3
        color: "transparent"
        
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.35)
            shadowBlur: 0.8
            shadowVerticalOffset: 8
        }
    }
    
    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        color: Commons.Theme.surfaceBase
        radius: Commons.Theme.radiusPanel
        
        border.color: Commons.Theme.border
        border.width: 1
        
        ListModel {
            id: appModel
        }
        
        ListModel {
            id: filteredModel
        }
        
        Process {
            id: appListProc
            running: true
            command: ["sh", "-c", "find /usr/share/applications ~/.local/share/applications -name '*.desktop' 2>/dev/null | while read f; do exec_line=$(grep '^Exec=' \"$f\" | cut -d'=' -f2- | head -1 | sed 's/%[uUfF]//g' | sed 's/  */ /g'); exec_name=$(echo \"$exec_line\" | awk '{print $1}' | xargs basename); desktop_id=$(basename \"$f\"); echo \"$(grep '^Name=' \"$f\" | cut -d'=' -f2 | head -1)|||$exec_line|||$(grep '^Icon=' \"$f\" | cut -d'=' -f2 | head -1)|||$exec_name|||$desktop_id\"; done"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var output = text.trim();
                    var lines = output.split('\n');
                    appModel.clear();
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].split('|||');
                        if (parts.length >= 2 && parts[0] && parts[1]) {
                            var name = parts[0].trim();
                            var execStr = parts[1].trim();
                            var iconStr = parts.length >= 3 ? parts[2].trim() : "";
                            var execName = parts.length >= 4 ? parts[3].trim() : "";
                            var desktopId = parts.length >= 5 ? parts[4].trim() : "";
                            if (execStr.length > 0) {
                                appModel.append({
                                    name: name,
                                    exec: execStr,
                                    icon: iconStr,
                                    execName: execName,
                                    id: desktopId
                                });
                            }
                        }
                    }
                    filterApps();
                }
            }
        }
        
        function launchApp(item) {
            if (!item)
                return;
            var entry = typeof DesktopEntries !== "undefined" ? DesktopEntries.byId(item.id) : null;
            if (entry && typeof entry.execute === "function") {
                entry.execute();
                return;
            }
            var command = (item.exec || "").trim().split(/\s+/).filter(function(c) { return c.length > 0; });
            if (command.length === 0)
                return;
            var proc = processComponent.createObject(appLauncher, { cmd: ["sh", "-c", "nohup " + command.join(" ") + " </dev/null >/dev/null 2>&1 &"] });
        }
        
        Component {
            id: processComponent
            Process {
                property var cmd: []
                running: true
                command: cmd
            }
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Commons.Config.popupContentPadding
            spacing: Commons.Theme.spacingLg
            
            Text {
                text: "Applications"
                font.pixelSize: Commons.Theme.fontSizeHeading
                font.weight: Font.Bold
                font.family: Commons.Theme.fontUI
                color: cText
                Layout.fillWidth: true
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: searchInput.activeFocus ? cSurfaceContainer : cSurfaceContainer
                radius: Commons.Theme.radiusLg
                border.color: searchInput.activeFocus ? Commons.Theme.borderFocused : cBorder
                border.width: 1
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Commons.Theme.spacingMd
                    spacing: Commons.Theme.spacingMd
                    
                    Text {
                        text: "󰍉"
                        font.family: Commons.Theme.fontIcon
                        font.pixelSize: 18
                        color: cSubText
                    }
                    
                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: cText
                        font { family: Commons.Theme.fontUI; pixelSize: 13; weight: Font.Medium }
                        selectByMouse: true
                        focus: true
                        activeFocusOnPress: true
                        onTextChanged: {
                            filterApps();
                        }
                        Keys.onEscapePressed: {
                            appLauncher.shouldShow = false;
                        }
                        Keys.onReturnPressed: {
                            if (appList.currentIndex >= 0) {
                                var item = filteredModel.get(appList.currentIndex);
                                if (item) {
                                    appLauncher.shouldShow = false;
                                    backgroundRect.launchApp(item);
                                }
                            }
                        }
                        Keys.onDownPressed: {
                            appList.incrementCurrentIndex();
                        }
                        Keys.onUpPressed: {
                            appList.decrementCurrentIndex();
                        }
                        
                        Text {
                            anchors.fill: parent
                            text: "Search applications..."
                            color: cSubText
                            font: searchInput.font
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: cBorder
            }
            
            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: filteredModel
                spacing: 8
                currentIndex: 0
                clip: true
                
                onCurrentIndexChanged: {
                    if (currentIndex >= 0) {
                        positionViewAtIndex(currentIndex, ListView.Contain);
                    }
                }
                
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
                
                Item {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 200
                    visible: appList.count === 0
                    
                    Widgets.EmptyState {
                        anchors.centerIn: parent
                        icon: "󰍉"
                        iconSize: 64
                        title: "No applications found"
                        subtitle: searchInput.text ? "Try a different search term" : "Start typing to search"
                    }
                }
                
                delegate: Rectangle {
                    required property string name
                    required property string exec
                    required property string icon
                    required property string execName
                    required property string id
                    required property int index
                    
                    width: appList.width
                    height: 48
                    radius: Commons.Theme.radius
                    color: (appMa.containsMouse || appList.currentIndex === index) ? 
                           (appList.currentIndex === index ? Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.12) : cHover) : 
                           "transparent"
                    border.width: 1
                    border.color: appList.currentIndex === index ? Qt.rgba(cPrimary.r, cPrimary.g, cPrimary.b, 0.3) : cBorder
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12
                        
                        Widgets.AppIcon {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            size: 28
                            iconSize: 18
                            iconSource: icon || ""
                            fallbackIcon: "󰀻"
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            Text {
                                text: name
                                color: cText
                                font { family: Commons.Theme.fontUI; pixelSize: 13; weight: Font.Medium }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: execName
                                color: cSubText
                                font { family: Commons.Theme.fontUI; pixelSize: 11 }
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                visible: execName !== ""
                            }
                        }
                    }
                    
                    MouseArea {
                        id: appMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            appLauncher.shouldShow = false;
                            var item = filteredModel.get(index);
                            if (item)
                                backgroundRect.launchApp(item);
                        }
                    }
                }
            }
        }
    }
    
    function filterApps() {
        var searchText = searchInput.text.toLowerCase();
        var matches = [];
        
        // Collect all matches with priority scoring
        for (var i = 0; i < appModel.count; i++) {
            var item = appModel.get(i);
            var nameLower = item.name.toLowerCase();
            var execNameLower = item.execName.toLowerCase();
            var priority = -1;
            
            if (searchText === "") {
                priority = 100;
            } else {
                if (execNameLower === searchText) {
                    priority = 1;
                }
                else if (execNameLower.indexOf(searchText) === 0) {
                    priority = 2;
                }
                else if (execNameLower.includes(searchText)) {
                    priority = 3;
                }
                else if (nameLower.indexOf(searchText) === 0) {
                    priority = 4;
                }
                else if (nameLower.includes(searchText)) {
                    priority = 5;
                }
            }
            
            if (priority > 0) {
                matches.push({
                    priority: priority,
                    name: item.name,
                    exec: item.exec,
                    icon: item.icon,
                    execName: item.execName,
                    id: item.id
                });
            }
        }
        
        matches.sort(function(a, b) {
            if (a.priority !== b.priority) {
                return a.priority - b.priority;
            }
            var aSort = a.execName || a.name;
            var bSort = b.execName || b.name;
            return aSort.toLowerCase().localeCompare(bSort.toLowerCase());
        });
        
        filteredModel.clear();
        for (var i = 0; i < matches.length; i++) {
            filteredModel.append(matches[i]);
        }
        
        if (filteredModel.count > 0) {
            appList.currentIndex = 0;
        } else {
            appList.currentIndex = -1;
        }
    }
    
}
