pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Format
import "Theme.js" as Theme

Item {
    id: peersPanel

    property real fontScale: 1.0
    property var peers: []
    property var syncthingStatus: ({})
    property color accentColor: Theme.peerAccent
    property string expandedPeerKey: ""

    Layout.fillWidth: true
    Layout.fillHeight: true

    function fs(value) {
        return value * fontScale
    }

    function peerStatusInfo(peer) {
        if (!peer)
            return ({ label: "Unknown", color: Theme.warningBg, outline: Theme.warningBorder })
        if (peer.paused)
            return ({ label: "Paused", color: Theme.mutedBg, outline: Theme.mutedBorder })
        var needBytes = Number(peer.need_bytes || 0)
        if (!peer.connected)
            return ({ label: "Offline", color: Theme.errorBg, outline: Theme.errorBorder })
        if (needBytes > 0)
            return ({ label: "Syncing", color: Theme.warningBg, outline: Theme.warningBorder })
        return ({ label: "Up to date", color: Theme.successBg, outline: Theme.successBorder })
    }

    function peerProgressColor(peer) {
        if (!peer)
            return Theme.warningBorder
        if (peer.paused)
            return Theme.mutedBorder
        if (!peer.connected)
            return Theme.errorBorder

        var needBytes = Number(peer.need_bytes || 0)
        var completion = Number(peer.completion || 0)
        if (needBytes <= 0 || completion >= 100)
            return Theme.successProgress

        return Theme.peerAccent
    }

    function peerProgressOutlineColor(peer) {
        if (!peer)
            return Theme.warningBorder
        if (peer.paused)
            return Theme.mutedBorder
        if (!peer.connected)
            return Theme.errorBorder

        var needBytes = Number(peer.need_bytes || 0)
        var completion = Number(peer.completion || 0)
        if (needBytes <= 0 || completion >= 100)
            return Theme.successBorder

        return Theme.warningBorder
    }

    function peerKey(peer) {
        if (!peer)
            return ""
        return peer.id || peer.device_id || peer.name || ""
    }

    function isPeerExpanded(peer) {
        var key = peerKey(peer)
        return key !== "" && key === expandedPeerKey
    }

    function togglePeer(peer) {
        var key = peerKey(peer)
        if (!key)
            return
        expandedPeerKey = expandedPeerKey === key ? "" : key
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 18

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: peerList
                anchors.fill: parent
                spacing: 14
                model: peersPanel.peers
                delegate: Rectangle {
                    id: peerCard
                    required property var modelData
                    required property int index
                    width: peerList.width
                    implicitHeight: peerContent.implicitHeight + 32
                    radius: 12
                    border.width: 1
                    border.color: peerCard.expanded ? peersPanel.accentColor : Theme.borderSoft
                    color: peerTap.pressed ? Theme.surfacePressed : Theme.listSurface
                    readonly property bool expanded: peersPanel.isPeerExpanded(modelData)
                    readonly property var badgeInfo: peersPanel.peerStatusInfo(modelData)

                    Rectangle {
                        width: 14
                        radius: 7
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        color: Theme.itemColorForKey(peersPanel.peerKey(peerCard.modelData), "peer")
                    }

                    Column {
                        id: peerContent
                        anchors.margins: 20
                        anchors.leftMargin: 34
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 14

                        Row {
                            id: peerHeader
                            width: parent.width
                            spacing: 12

                            Text {
                                width: Math.max(0, peerHeader.width - peerStatusBadge.width - peerExpandCue.width - peerHeader.spacing * 2)
                                text: peerCard.modelData.name || peerCard.modelData.id
                                font.pointSize: peersPanel.fs(20)
                                font.bold: true
                                color: Theme.text
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            StatusBadge {
                                id: peerStatusBadge
                                text: peerCard.badgeInfo.label
                                fontScale: peersPanel.fontScale
                                color: peerCard.badgeInfo.color
                                outlineColor: peerCard.badgeInfo.outline
                            }

                            Text {
                                id: peerExpandCue
                                width: 30
                                text: peerCard.expanded ? "−" : "+"
                                font.pointSize: peersPanel.fs(22)
                                font.bold: true
                                color: peersPanel.accentColor
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        SyncProgressBar {
                            width: parent.width
                            value: peerCard.modelData.completion || 0
                            fillColor: peersPanel.peerProgressColor(peerCard.modelData)
                            fillBorderColor: peersPanel.peerProgressOutlineColor(peerCard.modelData)
                            fillBorderWidth: 1
                            fillOpacity: (peerCard.modelData.connected && !peerCard.modelData.paused) ? 1.0 : 0.35
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: `Progress ${peerCard.modelData.completion !== undefined ? Format.formatPercent(peerCard.modelData.completion || 0) : "n/a"}`
                                font.pointSize: peersPanel.fs(16)
                                color: Theme.textMuted
                            }

                            Text {
                                text: "·"
                                font.pointSize: peersPanel.fs(16)
                                color: Theme.textSubtle
                                visible: peerCard.modelData.need_bytes !== undefined
                            }

                            Text {
                                text: peerCard.modelData.need_bytes !== undefined ? `Pending ${Format.formatBytes(peerCard.modelData.need_bytes)}` : ""
                                font.pointSize: peersPanel.fs(16)
                                color: Theme.textMuted
                                visible: peerCard.modelData.need_bytes !== undefined
                            }
                        }

                        Item {
                            width: parent.width
                            height: peerCard.expanded ? 0 : 0.5
                        }

                        Rectangle {
                            width: parent.width
                            height: peerCard.expanded ? 2 : 0
                            color: Theme.borderSoft
                            visible: peerCard.expanded
                        }

                        Column {
                            id: peerDetails
                            spacing: 12
                            visible: peerCard.expanded

                            Column {
                                spacing: 4

                                Text {
                                    text: peerCard.modelData.address ? `Address ${peerCard.modelData.address}` : (peerCard.modelData.connected ? "" : `Last seen ${Format.formatTimeAgo(peerCard.modelData.last_seen)}`)
                                    font.pointSize: peersPanel.fs(14)
                                    color: Theme.textMuted
                                    visible: !!peerCard.modelData.address || !peerCard.modelData.connected
                                    width: peerDetails.width
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: peerCard.modelData.client_version ? `Client ${peerCard.modelData.client_version}` : ""
                                    font.pointSize: peersPanel.fs(14)
                                    color: Theme.textMuted
                                    visible: !!peerCard.modelData.client_version
                                    width: peerDetails.width
                                    elide: Text.ElideRight
                                }
                            }

                            Column {
                                spacing: 4
                                visible: (peerCard.modelData.folders || []).length > 0

                                Text {
                                    text: "Folder progress"
                                    font.pointSize: peersPanel.fs(16)
                                    font.bold: true
                                    color: Theme.text
                                }

                                Repeater {
                                    model: (peerCard.modelData.folders || []).slice(0, 4)
                                    delegate: Text {
                                        required property var modelData
                                        text: `${modelData.folder_label}: ${modelData.completion !== undefined ? Format.formatPercent(modelData.completion || 0) : (modelData.need_bytes !== undefined ? Format.formatBytes(modelData.need_bytes) + " pending" : "n/a")}`
                                        font.pointSize: peersPanel.fs(14)
                                        color: Theme.textMuted
                                        width: peerDetails.width
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: peerCard.expanded ? 8 : 0
                            }
                        }
                    }

                    MouseArea {
                        id: peerTap
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: peersPanel.togglePeer(peerCard.modelData)
                    }
                }
            }
        }

        Rectangle {
            visible: peersPanel.peers.length === 0
            radius: 12
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            color: Theme.listSurface
            border.color: Theme.borderSoft
            border.width: 1

            Text {
                anchors.centerIn: parent
                width: parent.width - 32
                text: peersPanel.syncthingStatus.available ? "No peers have connected yet." : "Waiting for Syncthing to respond..."
                font.pointSize: peersPanel.fs(18)
                color: Theme.textMuted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
