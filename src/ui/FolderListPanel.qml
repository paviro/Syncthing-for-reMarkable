import QtQuick 2.5
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

Rectangle {
    id: foldersPanel

    property real fontScale: 1.0
    property var folders: []
    property var syncthingStatus: ({})
    property color accentColor: "#1887f0"

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 22
    border.width: 2
    border.color: "#4f5978"
    color: "#ffffff"

    function fs(value) {
        return value * fontScale
    }

    function formatBytes(value) {
        if (value === undefined || value === null)
            return "n/a"
        var size = Number(value)
        var units = ["B", "KB", "MB", "GB", "TB"]
        var unitIndex = 0
        while (size >= 1024 && unitIndex < units.length - 1) {
            size = size / 1024
            unitIndex += 1
        }
        var precision = unitIndex === 0 ? 0 : 1
        return size.toFixed(precision) + " " + units[unitIndex]
    }

    function formatPercent(value) {
        if (value === undefined || value === null)
            return "0%"
        return value.toFixed(1) + "%"
    }

    function folderSizeSummary(folder) {
        if (!folder)
            return "n/a"

        var totalText = formatBytes(folder.global_bytes)
        var stateCode = (folder.state_code || "").toString()
        var needBytes = Number(folder.need_bytes || 0)

        if (stateCode === "up_to_date" || needBytes === 0)
            return `Size ${totalText}`

        return `Need ${formatBytes(folder.need_bytes)} of ${totalText}`
    }

    function folderPeerNeedSummary(folder) {
        if (!folder || !folder.peers_need_summary)
            return ""

        var summary = folder.peers_need_summary
        var peerCount = Number(summary.peer_count || 0)
        var needBytes = Number(summary.need_bytes || 0)
        if (peerCount <= 0 || needBytes <= 0)
            return ""

        var peerLabel = peerCount === 1 ? "peer" : "peers"
        var verb = peerCount === 1 ? "needs" : "need"
        return `${peerCount} ${peerLabel} ${verb} ${formatBytes(needBytes)}`
    }

    function statusInfo(folder) {
        if (!folder)
            return ({ label: "Unknown", color: "#ffd2a0" })

        var label = (folder.state || "").toString()
        if (label.length === 0)
            label = folder.paused ? "Paused" : "Unknown"

        var code = (folder.state_code || "unknown").toString()
        switch (code) {
        case "paused":
            return ({ label: label, color: "#cfd7eb" })
        case "error":
            return ({ label: label, color: "#ffb3b3" })
        case "waiting_to_scan":
            return ({ label: label, color: "#dfeafe" })
        case "waiting_to_sync":
            return ({ label: label, color: "#ffe3a3" })
        case "scanning":
            return ({ label: label, color: "#ffe3a3" })
        case "preparing_to_sync":
            return ({ label: label, color: "#ffe3a3" })
        case "syncing":
        case "pending_changes":
            return ({ label: label, color: "#ffd2a0" })
        case "up_to_date":
            return ({ label: label, color: "#c4f485" })
        default:
        if (folder.paused)
                return ({ label: label, color: "#cfd7eb" })
            return ({ label: label || "Unknown", color: "#ffd2a0" })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
        spacing: 12

        Text {
            text: "Folders"
                font.pointSize: fs(26)
            font.bold: true
                color: "#111c34"
            }

        Rectangle {
                visible: Boolean(syncthingStatus && syncthingStatus.available)
                radius: 12
                color: "#dfeafe"
                height: 36
                width: 160

                Text {
                    anchors.centerIn: parent
                    text: `${folders.length} total`
                    font.pointSize: fs(16)
                    color: "#111c34"
                }
            }
        }

        ScrollView {
            id: folderScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: folderList
                anchors.fill: parent
                spacing: 16
                model: folders
                delegate: Rectangle {
                    required property var modelData
                    width: folderList.width
                    implicitHeight: contentColumn.implicitHeight + 32
                    radius: 20
                    border.width: 2
                    border.color: "#6c7898"
                    color: "#ffffff"

                    Column {
                        id: contentColumn
                        anchors.margins: 20
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 10

                        Row {
                            id: nameAndStatusRow
                            Layout.fillWidth: true
                            width: parent.width
                            spacing: 12

                        Text {
                                id: folderName
                                width: Math.max(0, nameAndStatusRow.width - stateBadge.width - nameAndStatusRow.spacing)
                            text: modelData.label || modelData.id
                                font.pointSize: fs(20)
                            font.bold: true
                                color: "#14203b"
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            Rectangle {
                                id: stateBadge
                                readonly property var badge: foldersPanel.statusInfo(modelData)
                                radius: 14
                                color: badge.color
                                width: Math.max(130, badgeText.implicitWidth + 24)
                                height: 38

                        Text {
                                    id: badgeText
                                    anchors.centerIn: parent
                                    text: stateBadge.badge.label
                                    font.pointSize: fs(16)
                                    color: "#1b2236"
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 14
                            radius: 8
                            color: "#cbd3e4"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                height: parent.height
                                width: parent.width * Math.min(1, (modelData.completion || 0) / 100)
                                radius: 8
                                color: accentColor
                            }
                        }

                        RowLayout {
                            id: progressRow
                            Layout.fillWidth: true
                            spacing: 12
                            property string sizeSummary: foldersPanel.folderSizeSummary(modelData)
            property string peerNeedSummary: foldersPanel.folderPeerNeedSummary(modelData)

                        Text {
                                text: `Progress ${foldersPanel.formatPercent(modelData.completion || 0)}`
                                font.pointSize: fs(16)
                                color: "#232a40"
                        }

                        Text {
                                text: "·"
                                font.pointSize: fs(16)
                                color: "#232a40"
                                visible: progressRow.sizeSummary.length > 0
                        }

                        Text {
                            text: progressRow.sizeSummary
                                font.pointSize: fs(16)
                                color: "#232a40"
                visible: progressRow.sizeSummary.length > 0
            }

            Text {
                text: "·"
                font.pointSize: fs(16)
                color: "#232a40"
                visible: progressRow.peerNeedSummary.length > 0
            }

            Text {
                text: progressRow.peerNeedSummary
                font.pointSize: fs(16)
                color: "#232a40"
                visible: progressRow.peerNeedSummary.length > 0
                            }
                        }

                        Column {
                            spacing: 4

                            Text {
                                text: "Recent changes"
                                font.pointSize: fs(16)
                                font.bold: true
                                color: "#111c34"
                            }

                            Repeater {
                                model: (modelData.last_changes || []).slice(0, 3)
                                delegate: Text {
                                    text: `${modelData.when} · ${modelData.action} · ${modelData.name}` + (modelData.origin ? ` (${modelData.origin})` : "")
                                    font.pointSize: fs(14)
                                    color: "#2b3146"
                                }
                            }

                            Text {
                                visible: (modelData.last_changes || []).length === 0
                                text: "No recent changes"
                                font.pointSize: fs(14)
                                color: "#4f566a"
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: folders.length === 0
            radius: 18
            Layout.fillWidth: true
            height: 84
            color: "#ffffff"
            border.color: "#6c7898"

            Text {
                anchors.centerIn: parent
                text: syncthingStatus.available ? "No folders are configured yet." : "Waiting for Syncthing to respond..."
                font.pointSize: fs(18)
                color: "#111c34"
            }
        }
    }
}

