// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   G I T H U B   M O D U L E                                              │
// │   github · yearly count, contribution graph when open                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts

import "../../theme"
import "../../services"
import "../../components"

// Yearly count, streak, yesterday and the contribution grid. Desktop only
// (`bar: false` in the catalogue). Shows the reading's age, since it comes
// from the network.
Item {
    id: root

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Component.onCompleted: GithubService.subscribe()
    Component.onDestruction: GithubService.release()

    Loader {
        id: holder
        anchors.fill: parent
        sourceComponent: detail
    }

    Component {
        id: detail

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 13

                Text {
                    text: "󰊤"
                    font.family: Theme.fontMono
                    font.pixelSize: 28
                    color: Theme.indicator
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            Layout.fillWidth: true
                            text: GithubService.user !== ""
                                ? GithubService.user : "GitHub"
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            text: `${GithubService.totalLabel}`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            const parts = ["contributions this year"]
                            if (GithubService.streak > 0)
                                parts.push(`${GithubService.streak}-day streak`)
                            if (GithubService.age !== "")
                                parts.push(GithubService.age)
                            return parts.join(" · ")
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }
            }

            ContributionGrid {
                Layout.fillWidth: true
                Layout.fillHeight: true
                weeks: GithubService.weeks
                // As many recent weeks as fit the island; the full year is the
                // widget's.
                maxWeeks: 30
                spacing: 3
            }
        }
    }
}
