pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    property real fontScale: 1.0
    property var serviceStatus: ({})
    property var syncthingStatus: ({})
    property bool controlBusy: false
    property var installerStatus: null
    property bool installerAttentionRequired: false
    property color accentColor: "#1887f0"

    signal controlRequested(string action)
    signal settingsRequested()

    Layout.fillWidth: true
    Layout.preferredHeight: contentColumn.implicitHeight + 40
    radius: 20
    border.width: 2
    border.color: "#4f5978"
    color: "#ffffff"

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
            const version = syncthingStatus.version
            return version ? `Connected (${version})` : "Connected"
        }
        return "Offline"
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.bottomMargin: 28
        anchors.topMargin: 18
        spacing: 18

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
                    color: "#1a1e2d"
                }

                Rectangle {
                    radius: 18
                    Layout.preferredHeight: 96
                    color: card.serviceHealthy() ? "#c2ddff" : "#ffd4b8"
                    border.width: 0
                    Layout.fillWidth: true

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 36
                        text: card.friendlyServiceState()
                        font.pointSize: card.fs(18)
                        font.bold: true
                        color: "#112233"
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
                    color: "#1a1e2d"
                }

                Rectangle {
                    radius: 18
                    Layout.preferredHeight: 96
                    color: card.syncthingStatus.available ? "#c4f485" : "#f53636"
                    border.width: 0
                    Layout.fillWidth: true

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 36
                        text: card.friendlySyncthingState()
                        font.pointSize: card.fs(18)
                        font.bold: true
                        color: "#112233"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Divider {
            Layout.fillWidth: true
            dividerColor: "#6a738d"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Repeater {
                model: [
                    { label: "Start", action: "start" },
                    { label: "Stop", action: "stop" },
                    { label: "Restart", action: "restart" }
                ]

                delegate: AppButton {
                    required property var modelData
                    text: modelData.label
                    fontScale: card.fontScale
                    fillColor: card.accentColor
                    disabledFillColor: "#cfd7eb"
                    enabled: !card.controlBusy
                    buttonRadius: 18
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
                disabledFillColor: "#cfd7eb"
                enabled: !card.controlBusy
                buttonRadius: 18
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
            color: "#8a2e00"
        }
    }
}
