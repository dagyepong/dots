import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import "../../Services" as Services
import "../../Commons" as Commons

Rectangle {
    id: root
    
    property var mediaPopup
    property var barWindow
    property bool isVertical: false
    
    readonly property var player: Services.Players.active
    readonly property bool hasPlayer: !!player
    readonly property bool isPlaying: player?.isPlaying ?? false
    
    implicitWidth: isVertical ? Commons.Config.barWidth - Commons.Config.barPadding * 2 - 4 : (hasPlayer ? Math.max(0, mediaPlayerContent.implicitWidth + 16) : 0)
    implicitHeight: isVertical ? verticalContent.implicitHeight + 12 : Commons.Config.componentHeight
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight
    visible: hasPlayer
    
    Component.onCompleted: {
        if (Services.Players) {
            Services.Players.updateActivePlayer()
        }
    }
    
    radius: Commons.Theme.radius
    color: Commons.Theme.surfaceBase
    border.width: 1
    border.color: Commons.Theme.surfaceBorder
    clip: true
    
    Behavior on implicitWidth {
        NumberAnimation { 
            duration: 400
            easing.bezierCurve: [0.34, 1.56, 0.64, 1]
        }
    }
    
    onIsPlayingChanged: {
        if (!isPlaying && !isVertical) {
            marqueeAnim.stop()
            titleRow.x = titleRow.needsScroll ? 0 : (titleContainer.width - titleRow.implicitWidth) / 2
        }
    }
    
    // Horizontal layout
    Item {
        id: mediaPlayerContent
        anchors.centerIn: parent
        implicitWidth: hasPlayer ? contentRow.implicitWidth : 0
        implicitHeight: 22
        visible: !isVertical
    
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 6
            visible: hasPlayer
            
            Item {
                id: titleContainer
                Layout.preferredWidth: Math.max(80, Math.min(200, titleRow.implicitWidth + 8))
                Layout.preferredHeight: parent.height
                clip: true
                
                Row {
                    id: titleRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    
                    readonly property bool needsScroll: implicitWidth > titleContainer.width
                    x: needsScroll ? 0 : (titleContainer.width - implicitWidth) / 2
                    
                    Text {
                        id: artistText
                        text: {
                            var artist = root.player?.trackArtist ?? ""
                            return artist && artist.trim() !== "" ? artist + " - " : ""
                        }
                        color: Commons.Theme.surfaceTextVariant
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        visible: text !== ""
                    }
                    
                    Text {
                        id: trackText
                        text: root.player?.trackTitle ?? "Unknown"
                        color: Commons.Theme.foreground
                        font.family: Commons.Theme.fontUI
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }
                    
                    SequentialAnimation {
                        id: marqueeAnim
                        running: titleRow.needsScroll && root.isPlaying && !root.isVertical
                        loops: Animation.Infinite
                        
                        PauseAnimation { duration: 2000 }
                        NumberAnimation {
                            target: titleRow
                            property: "x"
                            to: titleContainer.width - titleRow.implicitWidth
                            duration: Math.abs(titleContainer.width - titleRow.implicitWidth) * 20
                            easing.type: Easing.Linear
                        }
                        PauseAnimation { duration: 2000 }
                        NumberAnimation {
                            target: titleRow
                            property: "x"
                            to: 0
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.mediaPopup && root.barWindow) {
                            if (!root.mediaPopup.shouldShow) {
                                root.mediaPopup.positionNear(root, root.barWindow)
                            }
                            root.mediaPopup.shouldShow = !root.mediaPopup.shouldShow
                        }
                    }
                }
            }
            
            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 12
                radius: Commons.Theme.radiusSm
                color: Commons.Theme.surfaceBorder
            }
            
            RowLayout {
                spacing: 2
                
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: Commons.Theme.radius
                    color: prevArea.containsMouse ? Commons.Theme.surfaceAccent : "transparent"
                    
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    scale: prevArea.pressed ? 0.9 : 1.0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: Commons.Theme.fontIcon
                        font.pixelSize: 13
                        color: Commons.Theme.foreground
                    }
                    
                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.player && root.player.canGoPrevious) {
                                root.player.previous()
                            }
                        }
                    }
                }
                
                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: Commons.Theme.radius
                    color: playArea.containsMouse ? Qt.lighter(Commons.Theme.secondary, 1.2) : Commons.Theme.secondary
                    
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    scale: playArea.pressed ? 0.85 : (playArea.containsMouse ? 1.05 : 1.0)
                    
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: root.isPlaying ? 0 : 1
                        text: root.isPlaying ? "󰏤" : "󰐊"
                        font.family: Commons.Theme.fontIcon
                        font.pixelSize: 14
                        color: Commons.Theme.background
                    }
                    
                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.player && root.player.canTogglePlaying) {
                                root.player.togglePlaying()
                            }
                        }
                    }
                }
                
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: Commons.Theme.radius
                    color: nextArea.containsMouse ? Commons.Theme.surfaceAccent : "transparent"
                    
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 80 } }
                    scale: nextArea.pressed ? 0.9 : 1.0
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: Commons.Theme.fontIcon
                        font.pixelSize: 13
                        color: Commons.Theme.foreground
                    }
                    
                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.player && root.player.canGoNext) {
                                root.player.next()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Vertical layout
    Column {
        id: verticalContent
        anchors.centerIn: parent
        spacing: 6
        visible: isVertical
        
        // Play/Pause button
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 28
            height: 28
            radius: Commons.Theme.radiusLg
            color: playAreaV.containsMouse ? Qt.lighter(Commons.Theme.secondary, 1.2) : Commons.Theme.secondary
            
            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on scale { NumberAnimation { duration: 80 } }
            scale: playAreaV.pressed ? 0.85 : (playAreaV.containsMouse ? 1.05 : 1.0)
            
            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: root.isPlaying ? 0 : 1
                text: root.isPlaying ? "󰏤" : "󰐊"
                font.family: Commons.Theme.fontIcon
                font.pixelSize: 16
                color: Commons.Theme.background
            }
            
            MouseArea {
                id: playAreaV
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.player && root.player.canTogglePlaying) {
                        root.player.togglePlaying()
                    }
                }
            }
        }
        
        // Prev/Next row
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            
            Rectangle {
                width: 18
                height: 18
                radius: Commons.Theme.radiusSm
                color: prevAreaV.containsMouse ? Commons.Theme.surfaceAccent : "transparent"
                
                Behavior on color { ColorAnimation { duration: 100 } }
                
                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.family: Commons.Theme.fontIcon
                    font.pixelSize: 11
                    color: Commons.Theme.foreground
                }
                
                MouseArea {
                    id: prevAreaV
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.player && root.player.canGoPrevious) {
                            root.player.previous()
                        }
                    }
                }
            }
            
            Rectangle {
                width: 18
                height: 18
                radius: Commons.Theme.radiusSm
                color: nextAreaV.containsMouse ? Commons.Theme.surfaceAccent : "transparent"
                
                Behavior on color { ColorAnimation { duration: 100 } }
                
                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.family: Commons.Theme.fontIcon
                    font.pixelSize: 11
                    color: Commons.Theme.foreground
                }
                
                MouseArea {
                    id: nextAreaV
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.player && root.player.canGoNext) {
                            root.player.next()
                        }
                    }
                }
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        visible: isVertical
        acceptedButtons: Qt.LeftButton
        z: -1
        onClicked: {
            if (root.mediaPopup && root.barWindow) {
                if (!root.mediaPopup.shouldShow) {
                    root.mediaPopup.positionNear(root, root.barWindow)
                }
                root.mediaPopup.shouldShow = !root.mediaPopup.shouldShow
            }
        }
    }
}
