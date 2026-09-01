import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick.VectorImage
import Quickshell.Services.Mpris

Item {


    id: root

    property string preferredPlayer: ""

    property var player: {
        const list = Mpris.players.values;
        if (list.length === 0) return null;

        if (preferredPlayer.length > 0) {
            const match = list.find(p => p.identity && p.identity.toLowerCase().includes(preferredPlayer.toLowerCase()));
            if (match) return match;
        }

        const playing = list.find(p => p.playbackState === MprisPlaybackState.Playing);
        return playing || list[0];
    }

    implicitWidth: 436
    implicitHeight: 120

    property real displayPosition: player ? player.position : 0

    Timer {
        interval: 1000
        running: root.player !== null && root.player.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: root.displayPosition = root.player.position
    }

    Connections {
        target: root.player
        function onPositionChanged() {
            root.displayPosition = root.player.position;
        }
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0 || isNaN(seconds)) return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: "#000000"
        visible: root.player !== null

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                radius: 10
                color: "#ffffff"
                clip: true
                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    clip:true
                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        antialiasing: true
                        asynchronous: true
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: albumArt.status !== Image.Ready
                    text: "♪"
                    color: "#ffffff"
                    font.pixelSize: 36
                    font.family: "SF Mono"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                Layout.leftMargin: 16

                Text {
                    Layout.fillWidth: true
                    text: root.player && root.player.trackTitle ? root.player.trackTitle : "No track"
                    color: "#ffffff"
                    font.pixelSize: 17
                    font.family: "SF Mono"
                    font.weight: 700
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player && root.player.trackArtists ? root.player.trackArtists : ""
                    color: "#888888"

                    font.pixelSize: 15
                    font.family: "SF Mono"
                    font.weight: 600
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }

                Slider {
                    id: seekSlider
                    Layout.fillWidth: true
                    to: root.player && root.player.length > 0 ? root.player.length : 1
                    enabled: !!root.player && root.player.canSeek

                    Binding {
                        target: seekSlider
                        property: "value"
                        value: root.displayPosition
                        when: !seekSlider.pressed
                    }

                    onMoved: {
                            if (root.player && root.player.canSeek)
                                root.player.position = value
                        }

                    background: ClippingRectangle {
                        x: seekSlider.leftPadding
                        y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                        width: seekSlider.availableWidth
                        height: 10
                        radius: 4
                        color: "#333333"
                        Rectangle {
                            width: seekSlider.visualPosition * parent.width
                            height: parent.height
                            radius: 8
                            color: "#ffffff"
                            Behavior on width {
                                NumberAnimation{duration: 500; easing.type: Easing.OutCubic}
                            }
                        }
                    }
                    handle: null
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: root.formatTime(root.displayPosition)
                        color: "#ffffff"
                        font.family: "SF Mono"
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 8


                        Rectangle{
                            id: previous_button
                            Layout.fillWidth: true
                            Layout.preferredHeight: 23
                            Layout.preferredWidth: 20
                            radius: 20
                            color : "#000000"
                            border.color: "#333333"
                            border.width: 1
                            VectorImage {
                                id: previous_icon
                                opacity: root.player && root.player.canGoPrevious ? 1 : 0
                                anchors.centerIn: parent
                                source: "previous.svg"
                                width: 20
                                height: 20
                                fillMode: VectorImage.PreserveAspectFit
                                preferredRendererType: VectorImage.CurveRenderer
                            }
                            TapHandler {
                                onTapped: root.player.previous()
                            }
                            HoverHandler {
                                onHoveredChanged: {
                                    previous_button.color = hovered ? "#333333" : "#000000"
                                }
                            }
                            Behavior on color {
                                ColorAnimation{duration: 300; easing.type: Easing.OutCubic}
                            }
                        }


                        Rectangle{
                            id: pause_button
                            Layout.fillWidth: true
                            Layout.preferredHeight: 23
                            Layout.preferredWidth: 20
                            radius: 20
                            color : "#000000"
                            border.color: "#333333"
                            border.width: 1
                            VectorImage {
                                id: pause_icon
                                opacity: root.player && root.player.canGoNext ? 1 : 0
                                anchors.centerIn: parent
                                source: root.player && root.player.playbackState === MprisPlaybackState.Playing
                                            ? "pause.svg"
                                            : "play.svg"
                                width: 20
                                height: 20
                                fillMode: VectorImage.PreserveAspectFit
                                preferredRendererType: VectorImage.CurveRenderer
                            }
                            TapHandler {
                                onTapped: {
                                    if (root.player.playbackState === MprisPlaybackState.Playing)
                                        root.player.pause();
                                    else
                                        root.player.play();
                                }
                            }
                            HoverHandler {
                                onHoveredChanged: {
                                    pause_button.color = hovered ? "#333333" : "#000000"
                                }
                            }
                            Behavior on color {
                                ColorAnimation{duration: 300; easing.type: Easing.OutCubic}
                            }
                        }


                        Rectangle{
                            id: next_button
                            Layout.fillWidth: true
                            Layout.preferredHeight: 23
                            radius: 20
                            Layout.preferredWidth: 20
                            color : "#000000"
                            border.color: "#333333"
                            border.width: 1
                            VectorImage {
                                id: next_icon
                                anchors.centerIn: parent
                                opacity: root.player && root.player.canGoPrevious ? 1 : 0
                                source: "next.svg"
                                width: 20
                                height: 20
                                preferredRendererType: VectorImage.CurveRenderer
                            }
                            TapHandler {
                                onTapped: root.player.next()
                            }
                            HoverHandler {
                                onHoveredChanged: {
                                    next_button.color = hovered ? "#333333" : "#000000"
                                }
                            }
                            Behavior on color {
                                ColorAnimation{duration: 300; easing.type: Easing.OutCubic}
                            }
                        }
                    }


                    Text {
                        text: root.formatTime(root.player ? root.player.length : 0)
                        color: "#ffffff"
                        font.family: "SF Mono"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 15
        radius: 14
        color: "#000000"
        visible: root.player === null

        Text {
            anchors.centerIn: parent
            text: "Play music"
            color: "#333333"
            font.pixelSize: 17
            font.family: "SF Mono"
            font.weight: 600
        }
    }
}
