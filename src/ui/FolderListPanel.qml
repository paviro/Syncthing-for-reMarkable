pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Format
import "Theme.js" as Theme

Item {
    id: foldersPanel

    property real fontScale: 1.0
    property var folders: []
    property var syncthingStatus: ({})
    property color accentColor: Theme.folderAccent
    property string expandedFolderKey: ""

    Layout.fillWidth: true
    Layout.fillHeight: true

    function fs(value) {
        return value * fontScale
    }

    function folderKey(folder) {
        if (!folder)
            return ""
        return folder.id || folder.label || ""
    }

    function isFolderExpanded(folder) {
        var key = folderKey(folder)
        return key !== "" && key === expandedFolderKey
    }

    function toggleFolder(folder) {
        var key = folderKey(folder)
        if (!key)
            return
        expandedFolderKey = expandedFolderKey === key ? "" : key
    }

    function folderSizeSummary(folder) {
        if (!folder)
            return "n/a"

        var totalText = Format.formatBytes(folder.global_bytes)
        var stateCode = (folder.state_code || "").toString()
        var needBytes = Number(folder.need_bytes || 0)

        if (stateCode === "up_to_date" || needBytes === 0)
            return `Size ${totalText}`

        return `Need ${Format.formatBytes(folder.need_bytes)} of ${totalText}`
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
        return `${peerCount} ${peerLabel} ${verb} ${Format.formatBytes(needBytes)}`
    }

    function statusInfo(folder) {
        if (!folder)
            return ({ label: "Unknown", color: Theme.warningBg, outline: Theme.warningBorder })

        var label = (folder.state || "").toString()
        if (label.length === 0)
            label = folder.paused ? "Paused" : "Unknown"

        var code = (folder.state_code || "unknown").toString()
        switch (code) {
        case "paused":
            return ({ label: label, color: Theme.mutedBg, outline: Theme.mutedBorder })
        case "error":
            return ({ label: label, color: Theme.errorBg, outline: Theme.errorBorder })
        case "waiting_to_scan":
            return ({ label: label, color: Theme.accentSoft, outline: Theme.borderSoft })
        case "waiting_to_sync":
            return ({ label: label, color: Theme.warningBg, outline: Theme.warningBorder })
        case "scanning":
            return ({ label: label, color: Theme.warningBg, outline: Theme.warningBorder })
        case "preparing_to_sync":
            return ({ label: label, color: Theme.warningBg, outline: Theme.warningBorder })
        case "syncing":
        case "pending_changes":
            return ({ label: label, color: Theme.warningBg, outline: Theme.warningBorder })
        case "up_to_date":
            return ({ label: label, color: Theme.successBg, outline: Theme.successBorder })
        default:
            if (folder.paused)
                return ({ label: label, color: Theme.mutedBg, outline: Theme.mutedBorder })
            return ({ label: label || "Unknown", color: Theme.warningBg, outline: Theme.warningBorder })
        }
    }

    function progressColor(folder) {
        if (!folder)
            return Theme.warningBorder

        var completion = Number(folder.completion || 0)
        var stateCode = (folder.state_code || "").toString()
        if (stateCode === "up_to_date" || completion >= 100)
            return Theme.successProgress

        return Theme.peerAccent
    }

    function progressOutlineColor(folder) {
        if (!folder)
            return "transparent"

        var completion = Number(folder.completion || 0)
        var stateCode = (folder.state_code || "").toString()
        if (stateCode === "up_to_date" || completion >= 100)
            return Theme.successBorder

        return Theme.warningBorder
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 18

        ScrollView {
            id: folderScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: folderList
                anchors.fill: parent
                spacing: 14
                model: foldersPanel.folders
                delegate: Rectangle {
                    id: folderCard
                    required property var modelData
                    required property int index
                    width: folderList.width
                    implicitHeight: contentColumn.implicitHeight + 32
                    radius: 12
                    border.width: 1
                    border.color: folderCard.expanded ? foldersPanel.accentColor : Theme.borderSoft
                    color: folderTap.pressed ? Theme.surfacePressed : Theme.listSurface
                    readonly property bool expanded: foldersPanel.isFolderExpanded(modelData)
                    readonly property var badgeInfo: foldersPanel.statusInfo(modelData)

                    Rectangle {
                        width: 16
                        radius: 8
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        color: Theme.itemColorForKey(foldersPanel.folderKey(folderCard.modelData), "folder")
                    }

                    Column {
                        id: contentColumn
                        anchors.margins: 20
                        anchors.leftMargin: 40
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 14

                        Row {
                            id: nameAndStatusRow
                            width: parent.width
                            spacing: 12

                            Text {
                                id: folderName
                                width: Math.max(0, nameAndStatusRow.width - stateBadge.width - expandCue.width - nameAndStatusRow.spacing * 2)
                                text: folderCard.modelData.label || folderCard.modelData.id
                                font.pointSize: foldersPanel.fs(20)
                                font.bold: true
                                color: Theme.text
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            StatusBadge {
                                id: stateBadge
                                text: folderCard.badgeInfo.label
                                fontScale: foldersPanel.fontScale
                                color: folderCard.badgeInfo.color
                                outlineColor: folderCard.badgeInfo.outline
                            }

                            Text {
                                id: expandCue
                                width: 30
                                text: folderCard.expanded ? "−" : "+"
                                font.pointSize: foldersPanel.fs(22)
                                font.bold: true
                                color: foldersPanel.accentColor
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        SyncProgressBar {
                            width: parent.width
                            value: folderCard.modelData.completion || 0
                            fillColor: foldersPanel.progressColor(folderCard.modelData)
                            fillBorderColor: foldersPanel.progressOutlineColor(folderCard.modelData)
                            fillBorderWidth: 1
                        }

                        RowLayout {
                            id: progressRow
                            Layout.fillWidth: true
                            spacing: 12
                            property string sizeSummary: foldersPanel.folderSizeSummary(folderCard.modelData)
                            property string peerNeedSummary: foldersPanel.folderPeerNeedSummary(folderCard.modelData)

                            Text {
                                text: `Progress ${Format.formatPercent(folderCard.modelData.completion || 0)}`
                                font.pointSize: foldersPanel.fs(16)
                                color: Theme.textMuted
                            }

                            Text {
                                text: "·"
                                font.pointSize: foldersPanel.fs(16)
                                color: Theme.textSubtle
                                visible: progressRow.sizeSummary.length > 0
                            }

                            Text {
                                text: progressRow.sizeSummary
                                font.pointSize: foldersPanel.fs(16)
                                color: Theme.textMuted
                                visible: progressRow.sizeSummary.length > 0
                            }

                            Text {
                                text: "·"
                                font.pointSize: foldersPanel.fs(16)
                                color: Theme.textSubtle
                                visible: progressRow.peerNeedSummary.length > 0
                            }

                            Text {
                                text: progressRow.peerNeedSummary
                                font.pointSize: foldersPanel.fs(16)
                                color: Theme.textMuted
                                visible: progressRow.peerNeedSummary.length > 0
                            }
                        }

                        Item {
                            width: parent.width
                            height: folderCard.expanded ? 0 : 0.5
                        }

                        Rectangle {
                            width: parent.width
                            height: folderCard.expanded ? 2 : 0
                            color: Theme.borderSoft
                            visible: folderCard.expanded
                        }

                        Column {
                            id: folderDetails
                            spacing: 4
                            visible: folderCard.expanded

                            Text {
                                text: "Recent changes"
                                font.pointSize: foldersPanel.fs(16)
                                font.bold: true
                                color: Theme.text
                            }

                            Repeater {
                                model: (folderCard.modelData.last_changes || []).slice(0, 3)
                                delegate: Text {
                                    required property var modelData
                                    text: `${modelData.when} · ${modelData.action} · ${modelData.name}` + (modelData.origin ? ` (${modelData.origin})` : "")
                                    font.pointSize: foldersPanel.fs(14)
                                    color: Theme.textMuted
                                    width: folderDetails.width
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                visible: (folderCard.modelData.last_changes || []).length === 0
                                text: "No recent changes"
                                font.pointSize: foldersPanel.fs(14)
                                color: Theme.textSubtle
                            }

                            Item {
                                width: parent.width
                                height: folderCard.expanded ? 8 : 0
                            }
                        }
                    }

                    MouseArea {
                        id: folderTap
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: foldersPanel.toggleFolder(folderCard.modelData)
                    }
                }
            }
        }

        Rectangle {
            visible: foldersPanel.folders.length === 0
            radius: 12
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            color: Theme.listSurface
            border.color: Theme.borderSoft
            border.width: 1

            Text {
                anchors.centerIn: parent
                width: parent.width - 32
                text: foldersPanel.syncthingStatus.available ? "No folders are configured yet." : "Waiting for Syncthing to respond..."
                font.pointSize: foldersPanel.fs(18)
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
