pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Format

Item {
    id: peersPanel

    property real fontScale: 1.0
    property var peers: []
    property var syncthingStatus: ({})
    property color accentColor: "#1887f0"
    property string expandedPeerKey: ""

    Layout.fillWidth: true
    Layout.fillHeight: true

    function fs(value) {
        return value * fontScale
    }

    function peerStatusInfo(peer) {
        if (!peer)
            return ({ label: "Unknown", color: "#ffd2a0" })
        if (peer.paused)
            return ({ label: "Paused", color: "#cfd7eb" })
        var needBytes = Number(peer.need_bytes || 0)
        if (!peer.connected)
            return ({ label: "Offline", color: "#f76060" })
        if (needBytes > 0)
            return ({ label: "Syncing", color: "#ffd2a0" })
        return ({ label: "Up to date", color: "#c4f485" })
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
                spacing: 16
                model: peersPanel.peers
                delegate: Rectangle {
                    id: peerCard
                    required property var modelData
                    width: peerList.width
                    implicitHeight: peerContent.implicitHeight + 32
                    radius: 20
                    border.width: 2
                    border.color: "#6c7898"
                    color: "#ffffff"
                    readonly property bool expanded: peersPanel.isPeerExpanded(modelData)

                    Column {
                        id: peerContent
                        anchors.margins: 20
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 16

                        Row {
                            id: peerHeader
                            width: parent.width
                            spacing: 12

                            Text {
                                width: Math.max(0, peerHeader.width - peerStatusBadge.width - peerHeader.spacing)
                                text: peerCard.modelData.name || peerCard.modelData.id
                                font.pointSize: peersPanel.fs(20)
                                font.bold: true
                                color: "#14203b"
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }

                            StatusBadge {
                                id: peerStatusBadge
                                readonly property var badge: peersPanel.peerStatusInfo(peerCard.modelData)
                                text: peerStatusBadge.badge.label
                                fontScale: peersPanel.fontScale
                                color: peerStatusBadge.badge.color
                            }
                        }

                        SyncProgressBar {
                            width: parent.width
                            value: peerCard.modelData.completion || 0
                            fillColor: peersPanel.accentColor
                            fillOpacity: (peerCard.modelData.connected && !peerCard.modelData.paused) ? 1.0 : 0.35
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: `Progress ${peerCard.modelData.completion !== undefined ? Format.formatPercent(peerCard.modelData.completion || 0) : "n/a"}`
                                font.pointSize: peersPanel.fs(16)
                                color: "#232a40"
                            }

                            Text {
                                text: "·"
                                font.pointSize: peersPanel.fs(16)
                                color: "#232a40"
                                visible: peerCard.modelData.need_bytes !== undefined
                            }

                            Text {
                                text: peerCard.modelData.need_bytes !== undefined ? `Pending ${Format.formatBytes(peerCard.modelData.need_bytes)}` : ""
                                font.pointSize: peersPanel.fs(16)
                                color: "#232a40"
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
                            color: "#aeb8cf"
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
                                    color: "#2b3146"
                                    visible: !!peerCard.modelData.address || !peerCard.modelData.connected
                                }

                                Text {
                                    text: peerCard.modelData.client_version ? `Client ${peerCard.modelData.client_version}` : ""
                                    font.pointSize: peersPanel.fs(14)
                                    color: "#2b3146"
                                    visible: !!peerCard.modelData.client_version
                                }
                            }

                            Column {
                                spacing: 4
                                visible: (peerCard.modelData.folders || []).length > 0

                                Text {
                                    text: "Folder progress"
                                    font.pointSize: peersPanel.fs(16)
                                    font.bold: true
                                    color: "#111c34"
                                }

                                Repeater {
                                    model: (peerCard.modelData.folders || []).slice(0, 4)
                                    delegate: Text {
                                        required property var modelData
                                        text: `${modelData.folder_label}: ${modelData.completion !== undefined ? Format.formatPercent(modelData.completion || 0) : (modelData.need_bytes !== undefined ? Format.formatBytes(modelData.need_bytes) + " pending" : "n/a")}`
                                        font.pointSize: peersPanel.fs(14)
                                        color: "#2b3146"
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
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: peersPanel.togglePeer(peerCard.modelData)
                    }
                }
            }
        }

        Rectangle {
            visible: peersPanel.peers.length === 0
            radius: 18
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            color: "#ffffff"
            border.color: "#6c7898"

            Text {
                anchors.centerIn: parent
                text: peersPanel.syncthingStatus.available ? "No peers have connected yet." : "Waiting for Syncthing to respond..."
                font.pointSize: peersPanel.fs(18)
                color: "#111c34"
            }
        }
    }
}
