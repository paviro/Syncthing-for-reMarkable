pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: panel

    property real fontScale: 1.0
    property var folders: []
    property var peers: []
    property var syncthingStatus: ({})
    property color accentColor: "#1887f0"
    property bool showPeers: false

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 22
    border.width: 2
    border.color: "#4f5978"
    color: "#ffffff"

    function fs(value) {
        return value * fontScale
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: panel.showPeers ? "Peers" : "Folders"
                font.pointSize: panel.fs(26)
                font.bold: true
                color: "#111c34"
            }

            Rectangle {
                visible: Boolean(panel.syncthingStatus && panel.syncthingStatus.available)
                radius: 12
                color: "#dfeafe"
                Layout.preferredHeight: 36
                Layout.preferredWidth: 180

                Text {
                    anchors.centerIn: parent
                    text: `${panel.showPeers ? panel.peers.length : panel.folders.length} total`
                    font.pointSize: panel.fs(16)
                    color: "#111c34"
                }
            }

            Item {
                Layout.fillWidth: true
            }

            AppButton {
                text: panel.showPeers ? "Folders" : "Peers"
                fontScale: panel.fontScale
                fillColor: panel.accentColor
                pressedColor: "#0f6cca"
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
            accentColor: panel.accentColor
        }
    }

    Component {
        id: peersComponent

        PeerListPanel {
            anchors.fill: parent
            fontScale: panel.fontScale
            peers: panel.peers
            syncthingStatus: panel.syncthingStatus
            accentColor: panel.accentColor
        }
    }
}
