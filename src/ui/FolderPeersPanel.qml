pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: panel

    property real fontScale: 1.0
    property var folders: []
    property var peers: []
    property var syncthingStatus: ({})
    property color accentColor: Theme.accent
    property bool showPeers: false

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 14
    border.width: 1
    border.color: Theme.border
    color: Theme.surface

    function fs(value) {
        return value * fontScale
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                radius: 8
                color: panel.showPeers ? Theme.peerAccent : Theme.folderAccent
                Layout.preferredHeight: 34
                Layout.preferredWidth: 18
            }

            Text {
                text: panel.showPeers ? "Peers" : "Folders"
                font.pointSize: panel.fs(24)
                font.bold: true
                color: Theme.text
            }

            Rectangle {
                visible: Boolean(panel.syncthingStatus && panel.syncthingStatus.available)
                radius: 10
                color: panel.showPeers ? Theme.peerAccent : Theme.folderAccent
                border.width: 1
                border.color: panel.showPeers ? Theme.peerAccentPressed : Theme.folderAccentPressed
                Layout.preferredHeight: 36
                Layout.preferredWidth: 128

                Text {
                    anchors.centerIn: parent
                    text: `${panel.showPeers ? panel.peers.length : panel.folders.length} total`
                    font.pointSize: panel.fs(16)
                    font.bold: true
                    color: Theme.onAccent
                }
            }

            Item {
                Layout.fillWidth: true
            }

            AppButton {
                text: panel.showPeers ? "Folders" : "Peers"
                fontScale: panel.fontScale
                fillColor: panel.showPeers ? Theme.folderAccent : Theme.peerAccent
                pressedColor: panel.showPeers ? Theme.folderAccentPressed : Theme.peerAccentPressed
                Layout.preferredWidth: 150
                Layout.preferredHeight: 64
                Layout.alignment: Qt.AlignRight
                onClicked: panel.showPeers = !panel.showPeers
            }
        }

        Loader {
            id: contentLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: panel.showPeers ? peersComponent : foldersComponent
        }
    }

    Component {
        id: foldersComponent

        FolderListPanel {
            anchors.fill: parent
            fontScale: panel.fontScale
            folders: panel.folders
            syncthingStatus: panel.syncthingStatus
            accentColor: Theme.folderAccent
        }
    }

    Component {
        id: peersComponent

        PeerListPanel {
            anchors.fill: parent
            fontScale: panel.fontScale
            peers: panel.peers
            syncthingStatus: panel.syncthingStatus
            accentColor: Theme.peerAccent
        }
    }
}
