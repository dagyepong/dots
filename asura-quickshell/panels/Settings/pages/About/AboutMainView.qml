import "../../../../core"
import "../../../../services"
import "../../../../widgets"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

ColumnLayout {
    property string version: ""
    signal pushView(string viewName)

            spacing: 32 * Appearance.effectiveScale

            // ── Top Branding & Distro Cards (50:50) ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 20 * Appearance.effectiveScale

                BrandingCard {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    title: "Shell"
                    name: "Asura Shell"
                    subText: "Version " + version
                    accentColor: Appearance.colors.colPrimary
                    icon: "verified_user"
                    // Use local SVG but with better scaling
                    logoSource: "../../../../assets/icons/asura-shell.svg"
                }

                BrandingCard {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    title: "Distro"
                    name: SystemInfo.distroName
                    subText: "Kernel " + SystemInfo.kernel
                    accentColor: Appearance.m3colors.m3tertiary
                    icon: "terminal"
                    // Use system logo name from os-release
                    logoSource: SystemInfo.logo
                    isSystemIcon: true
                }
            }

            // ── Local checks ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12 * Appearance.effectiveScale

                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52 * Appearance.effectiveScale
                    buttonRadius: 16 * Appearance.effectiveScale
                    colBackground: Appearance.m3colors.m3surfaceContainerHigh
                    onClicked: pushView( "dependency")
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20 * Appearance.effectiveScale
                        anchors.rightMargin: 16 * Appearance.effectiveScale
                        spacing: 16 * Appearance.effectiveScale
                        MaterialSymbol {
                            text: "verified"
                            iconSize: 22 * Appearance.effectiveScale
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Dependency Check"
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }

                        // Notification Badge
                        Rectangle {
                            visible: SysCheckService.missingCount > 0
                            width: 8 * Appearance.effectiveScale
                            height: 8 * Appearance.effectiveScale
                            radius: 4 * Appearance.effectiveScale
                            color: Appearance.colors.colError
                            Layout.alignment: Qt.AlignVCenter
                        }

                        MaterialSymbol {
                            text: "chevron_right"
                            iconSize: 20 * Appearance.effectiveScale
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            // ── System Information ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * Appearance.effectiveScale
                
                SearchHandler { 
                    searchString: "System Information"
                    aliases: ["OS", "Distro", "Kernel", "Hostname"]
                }

                RowLayout {
                    spacing: 12 * Appearance.effectiveScale
                    Layout.bottomMargin: 8 * Appearance.effectiveScale
                    MaterialSymbol {
                        text: "info"
                        iconSize: 24 * Appearance.effectiveScale
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        text: "System Information"
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4 * Appearance.effectiveScale

                    InfoRow { label: "Distro"; value: SystemInfo.distroName }
                    InfoRow { label: "Username"; value: SystemInfo.username }
                    InfoRow { label: "Host"; value: SystemInfo.hostname }
                    InfoRow { label: "Kernel"; value: SystemInfo.kernel }
                    InfoRow { label: "Shell"; value: "asura-shell" }
                }
            }

            // ── Hardware Information ──
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4 * Appearance.effectiveScale
                
                SearchHandler { 
                    searchString: "Hardware"
                    aliases: ["CPU", "GPU", "Memory", "RAM", "Specs"]
                }

                RowLayout {
                    spacing: 12 * Appearance.effectiveScale
                    Layout.bottomMargin: 8 * Appearance.effectiveScale
                    MaterialSymbol {
                        text: "memory"
                        iconSize: 24 * Appearance.effectiveScale
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        text: "Hardware"
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4 * Appearance.effectiveScale

                    InfoRow { label: "Processor"; value: SystemInfo.cpu }
                    InfoRow { label: "GPU"; value: SystemInfo.gpu }
                    InfoRow { label: "Memory"; value: SystemInfo.memory }
                    InfoRow { label: "Storage"; value: SystemInfo.storage }
                    InfoRow { label: "Displays"; value: HyprlandData.monitors.length + " connected" }
                }
            }

    }
