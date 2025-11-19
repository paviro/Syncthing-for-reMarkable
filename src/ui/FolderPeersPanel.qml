import QtQuick 2.5
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

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
                font.pointSize: fs(26)
                font.bold: true
                color: "#111c34"
            }

            Rectangle {
                visible: Boolean(syncthingStatus && syncthingStatus.available)
                radius: 12
                color: "#dfeafe"
                height: 36
                width: 180

                Text {
                    anchors.centerIn: parent
                    text: `${panel.showPeers ? peers.length : folders.length} total`
                    font.pointSize: fs(16)
                    color: "#111c34"
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                id: peersToggleButton
                text: panel.showPeers ? "Folders" : "Peers"
                checkable: true
                checked: panel.showPeers
                Layout.preferredHeight: 64
                Layout.minimumWidth: 150
                Layout.preferredWidth: 150
                Layout.alignment: Qt.AlignRight
                font.pointSize: fs(18)
                padding: 0
                onClicked: panel.showPeers = !panel.showPeers

                contentItem: Text {
                    text: peersToggleButton.text
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "#ffffff"
                    font.pointSize: fs(18)
                    font.bold: true
                }

                background: Rectangle {
                    radius: 18
                    color: panel.accentColor
                    border.color: panel.accentColor
                    border.width: 0
                }
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

