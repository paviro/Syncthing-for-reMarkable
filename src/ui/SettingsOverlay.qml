import QtQuick 2.5
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3

Rectangle {
    id: overlay
    anchors.fill: parent
    color: visible ? Qt.rgba(0, 0, 0, 0.2) : "transparent"
    visible: false
    z: 1000

    property real fontScale: 1.0
    property var serviceStatus: ({})
    property bool controlBusy: false
    property string guiAddress: ""
    property var updateCheckResult: null
    property var updateStatus: null
    property int updateRestartCountdown: 0

    signal closeRequested()
    signal autostartToggleRequested(bool enable)
    signal guiAddressToggleRequested(string address)
    signal checkForUpdatesRequested()
    signal downloadUpdateRequested()
    signal restartRequested()

    function fs(value) {
        return value * fontScale
    }

    function isAutostartEnabled() {
        const state = serviceStatus.unit_file_state || ""
        return state === "enabled" || state === "enabled-runtime"
    }

    function isGuiAddressOpen() {
        return guiAddress.startsWith("0.0.0.0:")
    }

    function getCurrentVersion() {
        if (updateCheckResult && updateCheckResult.current_version) {
            return updateCheckResult.current_version
        }
        return "1.0.0"
    }

    function isRestartPending() {
        return updateStatus && updateStatus.pending_restart
    }

    function getUpdateStatusText() {
        if (isRestartPending()) {
            return "Update installed. Close this app, then press Reload in AppLoad (top-right) to load the new version."
        }
        if (updateStatus && updateStatus.error) {
            return updateStatus.error
        }
        if (updateStatus && updateStatus.progress_message) {
            return updateStatus.progress_message
        }
        if (updateCheckResult) {
            if (updateCheckResult.update_available) {
                return `Current: ${updateCheckResult.current_version} → Available: ${updateCheckResult.latest_version}`
            } else {
                return "Your app is up to date"
            }
        }
        return "Checks the version of the AppLoad app"
    }

    function isUpdateInProgress() {
        return updateStatus && updateStatus.in_progress
    }

    function isUpdateAvailable() {
        return updateCheckResult && updateCheckResult.update_available
    }
    
    function getUpdateButtonLabel() {
        if (isRestartPending()) {
            const secs = Math.max(0, updateRestartCountdown || 0)
            return secs > 0 ? `Close (${secs})` : "Closing..."
        }
        if (isUpdateAvailable()) {
            return "Install"
        }
        return "Check"
    }

    function isUpdateButtonEnabled() {
        if (isRestartPending()) {
            return true
        }
        return !isUpdateInProgress()
    }

    function handleUpdateButtonClick() {
        if (isRestartPending()) {
            overlay.restartRequested()
        } else if (isUpdateAvailable()) {
            overlay.downloadUpdateRequested()
        } else {
            overlay.checkForUpdatesRequested()
        }
    }

    function canCloseOverlay() {
        return !isUpdateInProgress() && !isRestartPending()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (overlay.canCloseOverlay()) {
                overlay.closeRequested()
            }
        }
    }

    Rectangle {
        id: settingsCard
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 800)
        height: Math.min(parent.height * 0.9, contentColumn.implicitHeight + 80)
        color: "white"
        radius: 8
        border.color: "#000000"
        border.width: 3

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Prevent clicks from propagating
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 40
            anchors.bottomMargin: 25
            spacing: 28

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Settings"
                    font.pointSize: fs(36)
                    font.bold: true
                    color: "#000000"
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    text: "Close"
                    font.pointSize: fs(26)
                    flat: true
                    visible: overlay.canCloseOverlay()
                    onClicked: {
                        if (overlay.canCloseOverlay()) {
                            overlay.closeRequested()
                        }
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: "#000000"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    background: Rectangle {
                        color: "transparent"
                        radius: 4
                        border.color: "#000000"
                        border.width: 2
                        implicitWidth: 140
                        implicitHeight: 60
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 2
                color: "#000000"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 0
                    Layout.rightMargin: 0
                    spacing: 30

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Autostart Syncthing"
                            font.pointSize: fs(24)
                            font.bold: true
                            color: "#000000"
                        }

                        Text {
                            text: isAutostartEnabled() 
                                ? "Syncthing will start automatically when the device boots"
                                : "Syncthing must be started manually"
                            font.pointSize: fs(18)
                            color: "#333333"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    Switch {
                        id: autostartSwitch
                        checked: isAutostartEnabled()
                        enabled: !controlBusy
                        scale: 3.0
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 30
                        
                        onToggled: {
                            overlay.autostartToggleRequested(checked)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    height: 1
                    color: "#cccccc"
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 0
                    Layout.rightMargin: 0
                    spacing: 30

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Text {
                            text: "Network Access"
                            font.pointSize: fs(24)
                            font.bold: true
                            color: "#000000"
                        }

                        Text {
                            text: isGuiAddressOpen() 
                                ? "Syncthing web UI is accessible from other devices on the network"
                                : "Syncthing web UI is only accessible from this device"
                            font.pointSize: fs(18)
                            color: "#333333"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                    }

                    Switch {
                        id: networkAccessSwitch
                        checked: isGuiAddressOpen()
                        enabled: !controlBusy && guiAddress !== ""
                        scale: 3.0
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 30
                        
                        onToggled: {
                            const newAddress = checked ? "0.0.0.0:8384" : "127.0.0.1:8384"
                            overlay.guiAddressToggleRequested(newAddress)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    height: 1
                    color: "#cccccc"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 0
                    Layout.rightMargin: 0
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 30

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: "Update"
                                font.pointSize: fs(24)
                                font.bold: true
                                color: "#000000"
                            }

                            Text {
                                text: getUpdateStatusText()
                                font.pointSize: fs(18)
                                color: (updateStatus && updateStatus.error) ? "#cc0000" : "#333333"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        Button {
                            text: getUpdateButtonLabel()
                            font.pointSize: fs(22)
                            enabled: isUpdateButtonEnabled()
                            Layout.alignment: Qt.AlignVCenter
                            
                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: "#000000"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            background: Rectangle {
                                color: {
                                    if (!parent.enabled) return "#f5f5f5"
                                    if (isRestartPending()) {
                                        return "transparent"
                                    }
                                    if (isUpdateAvailable()) {
                                        return parent.pressed ? "#A1BA46" : '#c6f02c'
                                    }
                                    return parent.pressed ? "#e0e0e0" : "white"
                                }
                                radius: 4
                                border.color: "#000000"
                                border.width: 2
                                implicitWidth: 140
                                implicitHeight: 60
                            }

                            onClicked: handleUpdateButtonClick()
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    function show() {
        visible = true
    }

    function hide() {
        if (canCloseOverlay()) {
        visible = false
        }
    }
}

