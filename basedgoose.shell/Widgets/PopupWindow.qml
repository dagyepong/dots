import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../Commons" as Commons

PanelWindow {
    id: root
    
    property bool shouldShow: false
    property string ipcTarget: ""
    property bool closeOnClickOutside: true
    property real initialScale: 0.94
    property real transformOriginX: 0.5
    property real transformOriginY: 0.0
    property int closeDelay: 400
    
    property int openDuration: 180
    property int closeDuration: 120
    property real scaleOvershoot: 1.3
    
    property string barPosition: "top"  // Can be "top", "bottom", "left", "right"
    
    property real relativeX: -1
    property real relativeY: -1
    
    readonly property bool isBarHorizontal: barPosition === "top" || barPosition === "bottom"
    readonly property int barOffset: isBarHorizontal 
        ? (Commons.Config.barHeight + Commons.Config.barMargin * 2 + Commons.Config.popupMargin)
        : (Commons.Config.barWidth + Commons.Config.barMargin * 2 + Commons.Config.popupMargin)
    
    property bool autoTransformOrigin: true
    
    Component.onCompleted: {
        if (autoTransformOrigin) {
            updateTransformOrigin()
        }
    }
    
    onBarPositionChanged: {
        if (autoTransformOrigin) {
            updateTransformOrigin()
        }
    }
    
    function updateTransformOrigin() {
        switch (barPosition) {
            case "top":
                transformOriginY = 0.0
                break
            case "bottom":
                transformOriginY = 1.0
                break
            case "left":
                transformOriginX = 0.0
                break
            case "right":
                transformOriginX = 1.0
                break
        }
    }
    
    function positionNear(moduleItem, barWindow) {
        if (!moduleItem || !barWindow) {
            console.log("[PopupWindow] positionNear called with invalid parameters")
            return
        }
        
        const screen = root.screen || Quickshell.screens[0]
        if (!screen) {
            console.log("[PopupWindow] No screen available")
            return
        }
        
        const screenWidth = screen.width
        const screenHeight = screen.height
        const popupWidth = root.implicitWidth || 320
        const popupHeight = root.implicitHeight || 400
        
        const moduleWidth = moduleItem.width || 30
        const moduleHeight = moduleItem.height || 30
        
        if (typeof moduleItem.mapToGlobal !== 'function') {
            console.error("[PopupWindow] mapToGlobal not available")
            return
        }
        
        const globalPos = moduleItem.mapToGlobal(0, 0)
        const moduleScreenX = globalPos.x
        const moduleScreenY = globalPos.y
        
        console.log("[PopupWindow] barPosition:", barPosition, "moduleScreenPos:", moduleScreenX, moduleScreenY, "screenSize:", screenWidth, screenHeight)
        
        var targetX = 0
        var targetY = 0
        
        if (barPosition === "top" || barPosition === "bottom") {
            targetX = moduleScreenX + moduleWidth / 2 - popupWidth / 2
            targetX = Math.max(Commons.Config.popupMargin, Math.min(screenWidth - popupWidth - Commons.Config.popupMargin, targetX))
            
            if (barPosition === "top") {
                targetY = barOffset
            } else {
                targetY = screenHeight - popupHeight - barOffset
            }
            console.log("[PopupWindow] Horizontal bar - targetX:", targetX, "targetY:", targetY)
        } else {
            targetY = moduleScreenY + moduleHeight / 2 - popupHeight / 2
            console.log("[PopupWindow] Vertical bar - before clamp targetY:", targetY)
            targetY = Math.max(Commons.Config.popupMargin, Math.min(screenHeight - popupHeight - Commons.Config.popupMargin, targetY))
            console.log("[PopupWindow] Vertical bar - after clamp targetY:", targetY)
            
            if (barPosition === "left") {
                targetX = barOffset
            } else {
                targetX = screenWidth - popupWidth - barOffset
            }
            console.log("[PopupWindow] Vertical bar - targetX:", targetX, "targetY:", targetY)
        }
        
        relativeX = targetX
        relativeY = targetY
        console.log("[PopupWindow] Final relativeX:", relativeX, "relativeY:", relativeY)
    }
    
    default property alias content: contentContainer.children
    
    screen: Quickshell.screens[0]
    visible: shouldShow || container.opacity > 0
    color: "transparent"
    
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: shouldShow ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    
    anchors {
        top: barPosition === "top" || barPosition === "left" || barPosition === "right"
        bottom: barPosition === "bottom"
        left: barPosition === "left" || barPosition === "top" || barPosition === "bottom"
        right: barPosition === "right"
    }
    
    margins {
        top: {
            var result = 0
            if (barPosition === "top") {
                result = barOffset
            } else if (relativeY >= 0) {
                result = relativeY
            } else if (barPosition === "left" || barPosition === "right") {
                result = Commons.Config.popupMargin
            } else {
                result = Commons.Config.popupMargin
            }
            console.log("[PopupWindow] margins.top:", result, "barPosition:", barPosition, "relativeY:", relativeY)
            return result
        }
        bottom: {
            var result = 0
            if (barPosition === "bottom") {
                result = barOffset
            } else if (barPosition === "left" || barPosition === "right") {
                result = 0
            } else if (relativeY >= 0) {
                var screenHeight = root.screen ? root.screen.height : 1080
                result = screenHeight - relativeY - (root.implicitHeight || 400)
            } else {
                result = Commons.Config.popupMargin
            }
            console.log("[PopupWindow] margins.bottom:", result)
            return result
        }
        left: {
            var result = 0
            if (relativeX >= 0) {
                result = relativeX
            } else if (barPosition === "left") {
                result = barOffset
            } else if (barPosition === "right") {
                result = 0
            } else {
                result = Commons.Config.popupMargin
            }
            console.log("[PopupWindow] margins.left:", result, "relativeX:", relativeX)
            return result
        }
        right: {
            var result = 0
            if (barPosition === "right") {
                result = barOffset
            } else if (barPosition === "left") {
                result = 0
            } else if (relativeX >= 0 && (barPosition === "top" || barPosition === "bottom")) {
                var screenWidth = root.screen ? root.screen.width : 1920
                result = screenWidth - relativeX - (root.implicitWidth || 320)
            } else {
                result = 0
            }
            console.log("[PopupWindow] margins.right:", result)
            return result
        }
    }
    
    IpcHandler {
        id: ipcHandler
        target: root.ipcTarget
        
        function toggle(): void {
            root.shouldShow = !root.shouldShow
        }
        
        function open(): void {
            root.shouldShow = true
        }
        
        function close(): void {
            root.shouldShow = false
        }
    }
    
    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        propagateComposedEvents: true
        onClicked: mouse => {
            if (root.closeOnClickOutside && root.shouldShow) {
                var containerPos = container.mapFromItem(root, mouse.x, mouse.y)
                var containerRect = Qt.rect(0, 0, container.width, container.height)
                if (!containerRect.contains(containerPos.x, containerPos.y)) {
                    root.shouldShow = false
                    mouse.accepted = true
                } else {
                    mouse.accepted = false
                }
            }
        }
    }
    
    FocusScope {
        id: container
        anchors.fill: parent
        scale: root.initialScale
        opacity: 0
        focus: true
        
        property int transformOriginValue: {
            var xPercent = root.transformOriginX
            var yPercent = root.transformOriginY
            if (xPercent === 0.0) {
                if (yPercent === 0.0) return Item.TopLeft
                else if (yPercent === 0.5) return Item.Left
                else return Item.BottomLeft
            } else if (xPercent === 0.5) {
                if (yPercent === 0.0) return Item.Top
                else if (yPercent === 0.5) return Item.Center
                else return Item.Bottom
            } else {
                if (yPercent === 0.0) return Item.TopRight
                else if (yPercent === 0.5) return Item.Right
                else return Item.BottomRight
            }
        }
        
        transformOrigin: transformOriginValue
        
        Keys.onEscapePressed: root.shouldShow = false
        
        property bool mouseHasEntered: false
        property bool mouseInside: hoverHandler.hovered
        
        Connections {
            target: root
            function onShouldShowChanged() {
                if (root.shouldShow) {
                    container.mouseHasEntered = false
                    closeTimer.stop()
                }
            }
        }
        
        Timer {
            id: closeTimer
            interval: root.closeDelay
            onTriggered: {
                if (!container.mouseInside && container.mouseHasEntered && root.shouldShow && root.closeOnClickOutside) {
                    root.shouldShow = false
                }
            }
        }
        
        HoverHandler {
            id: hoverHandler
            onHoveredChanged: {
                if (hovered) {
                    container.mouseHasEntered = true
                    closeTimer.stop()
                } else if (container.mouseHasEntered && root.shouldShow) {
                    if (root.closeOnClickOutside) {
                        closeTimer.restart()
                    }
                }
            }
        }
        
        states: State {
            name: "visible"
            when: root.shouldShow
            PropertyChanges { target: container; opacity: 1; scale: 1.0 }
        }
        
        transitions: [
            Transition {
                to: "visible"
                ParallelAnimation {
                    NumberAnimation { 
                        property: "opacity"
                        duration: root.openDuration
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation { 
                        property: "scale"
                        duration: root.openDuration * 1.4
                        easing.type: Easing.OutBack
                        easing.overshoot: root.scaleOvershoot
                    }
                }
            },
            Transition {
                from: "visible"
                ParallelAnimation {
                    NumberAnimation { 
                        property: "opacity"
                        duration: root.closeDuration
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation { 
                        property: "scale"
                        to: root.initialScale
                        duration: root.closeDuration
                    }
                }
            }
        ]
        
        Item {
            id: contentContainer
            anchors.fill: parent
            z: 1
        }
    }
    
    function toggle() {
        shouldShow = !shouldShow
    }
    
    function open() {
        shouldShow = true
    }
    
    function close() {
        shouldShow = false
    }
}
