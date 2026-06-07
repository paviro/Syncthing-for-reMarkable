pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: card

    property real fontScale: 1.0
    property var serviceStatus: ({})
    property var syncthingStatus: ({})
    property bool controlBusy: false
    property var installerStatus: null
    property bool installerAttentionRequired: false
    property color accentColor: Theme.accent

    signal controlRequested(string action)
    signal settingsRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: contentColumn.implicitHeight + 40
    radius: 14
    border.width: 1
    border.color: Theme.border
    color: Theme.dashboardSurface

    function fs(value) {
        return value * fontScale
    }

    function serviceHealthy() {
        const state = (serviceStatus.active_state || "").toLowerCase()
        return state === "active"
    }

    function capitalize(text) {
        if (!text || text.length === 0)
            return ""
        return text.charAt(0).toUpperCase() + text.slice(1)
    }

    function friendlyServiceState() {
        const active = (serviceStatus.active_state || "").toLowerCase()
        const sub = (serviceStatus.sub_state || "").toLowerCase()
        const primary = active ? capitalize(active) : "Unknown"
        if (sub && sub !== active && sub.length > 0) {
            return `${primary} (${capitalize(sub)})`
        }
        return primary
    }

    function friendlySyncthingState() {
        if (syncthingStatus.available) {
            return "Connected"
        }
        return "Offline"
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.bottomMargin: 28
        anchors.topMargin: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 24

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Service status"
                    font.pointSize: card.fs(18)
                    font.bold: true
                    color: Theme.text
                }

                Rectangle {
                    radius: 12
                    Layout.preferredHeight: 90
                    color: card.serviceHealthy() ? Theme.successBg : Theme.warningBg
                    border.width: 1
                    border.color: card.serviceHealthy() ? Theme.successBorder : Theme.warningBorder
                    Layout.fillWidth: true

                    Rectangle {
                        width: 10
                        radius: 5
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        color: card.serviceHealthy() ? Theme.successBorder : Theme.warningBorder
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 54
                        text: card.friendlyServiceState()
                        font.pointSize: card.fs(18)
                        font.bold: true
                        color: Theme.text
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Syncthing API"
                    font.pointSize: card.fs(18)
                    font.bold: true
                    color: Theme.text
                }

                Rectangle {
                    radius: 12
                    Layout.preferredHeight: 90
                    color: card.syncthingStatus.available ? Theme.successBg : Theme.errorBg
                    border.width: 1
                    border.color: card.syncthingStatus.available ? Theme.successBorder : Theme.errorBorder
                    Layout.fillWidth: true

                    Rectangle {
                        width: 10
                        radius: 5
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        color: card.syncthingStatus.available ? Theme.successBorder : Theme.errorBorder
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 54
                        text: card.friendlySyncthingState()
                        font.pointSize: card.fs(18)
                        font.bold: true
                        color: Theme.text
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Divider {
            Layout.fillWidth: true
            dividerColor: Theme.borderSoft
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Repeater {
                model: [
                    { label: "Start", action: "start", fill: Theme.successBorder, pressed: Theme.successPressed },
                    { label: "Stop", action: "stop", fill: Theme.errorBorder, pressed: Theme.errorPressed },
                    { label: "Restart", action: "restart", fill: Theme.warningBorder, pressed: Theme.warningPressed }
                ]

                delegate: AppButton {
                    required property var modelData
                    text: modelData.label
                    fontScale: card.fontScale
                    fillColor: modelData.fill
                    pressedColor: modelData.pressed
                    outlineColor: modelData.fill
                    disabledFillColor: Theme.mutedBg
                    enabled: !card.controlBusy
                    buttonRadius: 10
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 64
                    onClicked: card.controlRequested(modelData.action)
                }
            }

            Item { Layout.fillWidth: true }

            AppButton {
                text: "Settings"
                fontScale: card.fontScale
                fillColor: card.accentColor
                pressedColor: Theme.accentPressed
                disabledFillColor: Theme.mutedBg
                enabled: !card.controlBusy
                buttonRadius: 10
                Layout.preferredWidth: 150
                Layout.preferredHeight: 64
                onClicked: card.settingsRequested()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: (card.installerStatus && card.installerStatus.installer_disabled) && card.installerAttentionRequired
            text: "Syncthing installer disabled in config. Please install manually."
            font.pointSize: card.fs(16)
            color: Theme.warningBorder
        }
    }
}
