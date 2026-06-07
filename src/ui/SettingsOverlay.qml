pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: overlay
    anchors.fill: parent
    color: visible ? Theme.overlay : "transparent"
    visible: false
    z: 1000

    property real fontScale: 1.0
    property var serviceStatus: ({})
    property bool controlBusy: false
    property string guiAddress: ""
    property var updateCheckResult: null
    property var updateStatus: null
    property int updateRestartCountdown: 0
    property var syncthingUpdateCheckResult: null
    property var syncthingUpdateStatus: null
    property color accentColor: Theme.accent

    signal closeRequested()
    signal autostartToggleRequested(bool enable)
    signal guiAddressToggleRequested(string address)
    signal checkForUpdatesRequested()
    signal downloadUpdateRequested()
    signal restartRequested()
    signal checkSyncthingUpdateRequested()
    signal installSyncthingUpdateRequested()

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
        return !isUpdateInProgress() && !isSyncthingUpdateInProgress()
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
        return !isUpdateInProgress() && !isRestartPending() && !isSyncthingUpdateInProgress()
    }

    function getSyncthingUpdateStatusText() {
        if (syncthingUpdateStatus && syncthingUpdateStatus.error) {
            return syncthingUpdateStatus.error
        }
        if (syncthingUpdateStatus && syncthingUpdateStatus.progress_message) {
            return syncthingUpdateStatus.progress_message
        }
        if (syncthingUpdateCheckResult) {
            const running = syncthingUpdateCheckResult.running || "unknown"
            const latest = syncthingUpdateCheckResult.latest || "unknown"
            if (syncthingUpdateCheckResult.newer) {
                return `Current: ${running} → Available: ${latest}`
            }
            return `Syncthing is up to date (${running})`
        }
        return "Checks the installed Syncthing version"
    }

    function isSyncthingUpdateInProgress() {
        return syncthingUpdateStatus && syncthingUpdateStatus.in_progress
    }

    function isSyncthingUpdateAvailable() {
        return syncthingUpdateCheckResult && syncthingUpdateCheckResult.newer
    }

    function getSyncthingUpdateButtonLabel() {
        if (isSyncthingUpdateAvailable()) {
            return "Install"
        }
        return "Check"
    }

    function handleSyncthingUpdateButtonClick() {
        if (isSyncthingUpdateAvailable()) {
            overlay.installSyncthingUpdateRequested()
        } else {
            overlay.checkSyncthingUpdateRequested()
        }
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
        width: Math.min(parent.width - 48, 860)
        height: Math.min(parent.height - 48, contentColumn.implicitHeight + 56)
        color: Theme.surface
        radius: 14
        border.color: Theme.border
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: {} // Prevent clicks from propagating
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    radius: 8
                    color: overlay.accentColor
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: 18
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Settings"
                    font.pointSize: overlay.fs(26)
                    font.bold: true
                    color: Theme.text
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    id: closeButton
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    radius: 12
                    color: overlay.canCloseOverlay() ? (closeTap.pressed ? Theme.accentPressed : overlay.accentColor) : Theme.mutedBg
                    opacity: overlay.canCloseOverlay() ? 1 : 0.82
                    border.width: 1
                    border.color: overlay.canCloseOverlay() ? overlay.accentColor : Theme.borderSoft

                    Text {
                        anchors.centerIn: parent
                        text: "\u00D7"
                        font.pointSize: overlay.fs(38)
                        font.bold: true
                        color: Theme.onAccent
                    }

                    MouseArea {
                        id: closeTap
                        anchors.fill: parent
                        enabled: overlay.canCloseOverlay()
                        onClicked: overlay.closeRequested()
                    }
                }
            }

            Divider {
                Layout.fillWidth: true
                dividerColor: Theme.borderSoft
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: autostartRow.implicitHeight + 32
                    radius: 12
                    color: autostartTap.pressed ? Theme.surfacePressed : Theme.listSurface
                    border.width: 1
                    border.color: Theme.borderSoft

                    Rectangle {
                        width: 12
                        radius: 6
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        color: overlay.isAutostartEnabled() ? Theme.successBorder : Theme.mutedBorder
                    }

                    RowLayout {
                        id: autostartRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 34
                        anchors.rightMargin: 20
                        spacing: 20

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: "Autostart Syncthing"
                                    font.pointSize: overlay.fs(20)
                                    font.bold: true
                                    color: Theme.text
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                StatusBadge {
                                    text: overlay.isAutostartEnabled() ? "On" : "Off"
                                    fontScale: overlay.fontScale
                                    color: overlay.isAutostartEnabled() ? Theme.successBg : Theme.mutedBg
                                    outlineColor: overlay.isAutostartEnabled() ? Theme.successBorder : Theme.mutedBorder
                                }
                            }

                            Text {
                                text: overlay.isAutostartEnabled()
                                    ? "Syncthing will start automatically when the device boots"
                                    : "Syncthing must be started manually"
                                font.pointSize: overlay.fs(15)
                                color: Theme.textMuted
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            id: autostartSwitch
                            readonly property bool checked: overlay.isAutostartEnabled()
                            enabled: !overlay.controlBusy
                            Layout.preferredWidth: 104
                            Layout.preferredHeight: 54
                            Layout.alignment: Qt.AlignVCenter
                            radius: 27
                            color: checked ? Theme.successBorder : Theme.mutedBg
                            border.width: 1
                            border.color: checked ? Theme.successPressed : Theme.mutedBorder
                            opacity: enabled ? 1 : 0.55

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                x: autostartSwitch.checked ? autostartSwitch.width - width - 7 : 7
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.surface
                                border.width: 1
                                border.color: autostartSwitch.checked ? Theme.successPressed : Theme.borderSoft
                            }
                        }
                    }

                    MouseArea {
                        id: autostartTap
                        anchors.fill: parent
                        enabled: autostartSwitch.enabled
                        onClicked: overlay.autostartToggleRequested(!autostartSwitch.checked)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: networkRow.implicitHeight + 32
                    radius: 12
                    color: networkTap.pressed ? Theme.surfacePressed : Theme.listSurface
                    border.width: 1
                    border.color: Theme.borderSoft

                    Rectangle {
                        width: 12
                        radius: 6
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        color: overlay.isGuiAddressOpen() ? Theme.warningBorder : Theme.accent
                    }

                    RowLayout {
                        id: networkRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 34
                        anchors.rightMargin: 20
                        spacing: 20

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: "Network Access"
                                    font.pointSize: overlay.fs(20)
                                    font.bold: true
                                    color: Theme.text
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                StatusBadge {
                                    text: overlay.isGuiAddressOpen() ? "LAN" : "Local"
                                    fontScale: overlay.fontScale
                                    color: overlay.isGuiAddressOpen() ? Theme.warningBg : Theme.accentSoft
                                    outlineColor: overlay.isGuiAddressOpen() ? Theme.warningBorder : Theme.borderSoft
                                }
                            }

                            Text {
                                text: overlay.isGuiAddressOpen()
                                    ? "Syncthing web UI is accessible from other devices on the network"
                                    : "Syncthing web UI is only accessible from this device"
                                font.pointSize: overlay.fs(15)
                                color: Theme.textMuted
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        Rectangle {
                            id: networkAccessSwitch
                            readonly property bool checked: overlay.isGuiAddressOpen()
                            enabled: !overlay.controlBusy && overlay.guiAddress !== ""
                            Layout.preferredWidth: 104
                            Layout.preferredHeight: 54
                            Layout.alignment: Qt.AlignVCenter
                            radius: 27
                            color: checked ? Theme.warningBorder : Theme.mutedBg
                            border.width: 1
                            border.color: checked ? Theme.warningPressed : Theme.mutedBorder
                            opacity: enabled ? 1 : 0.55

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                x: networkAccessSwitch.checked ? networkAccessSwitch.width - width - 7 : 7
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.surface
                                border.width: 1
                                border.color: networkAccessSwitch.checked ? Theme.warningPressed : Theme.borderSoft
                            }
                        }
                    }

                    MouseArea {
                        id: networkTap
                        anchors.fill: parent
                        enabled: networkAccessSwitch.enabled
                        onClicked: {
                            const newAddress = networkAccessSwitch.checked ? "127.0.0.1:8384" : "0.0.0.0:8384"
                            overlay.guiAddressToggleRequested(newAddress)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: updateUiRow.implicitHeight + 32
                    radius: 12
                    color: Theme.listSurface
                    border.width: 1
                    border.color: overlay.isUpdateAvailable() ? Theme.successBorder : Theme.borderSoft

                    Rectangle {
                        width: 12
                        radius: 6
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        color: overlay.isUpdateAvailable() ? Theme.successBorder : overlay.accentColor
                    }

                    RowLayout {
                        id: updateUiRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 34
                        anchors.rightMargin: 20
                        spacing: 20

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Update UI"
                                font.pointSize: overlay.fs(20)
                                font.bold: true
                                color: Theme.text
                            }

                            Text {
                                text: overlay.getUpdateStatusText()
                                font.pointSize: overlay.fs(15)
                                color: (overlay.updateStatus && overlay.updateStatus.error) ? Theme.errorBorder : Theme.textMuted
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        AppButton {
                            text: overlay.getUpdateButtonLabel()
                            fontScale: overlay.fontScale
                            fillColor: overlay.isRestartPending() ? Theme.accentSoft : (overlay.isUpdateAvailable() ? Theme.successBorder : overlay.accentColor)
                            pressedColor: overlay.isRestartPending() ? Theme.surfacePressed : (overlay.isUpdateAvailable() ? Theme.successPressed : Theme.accentPressed)
                            textColor: overlay.isRestartPending() ? overlay.accentColor : Theme.onAccent
                            disabledFillColor: Theme.mutedBg
                            disabledTextColor: Theme.textSubtle
                            enabled: overlay.isUpdateButtonEnabled()
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 60
                            outlineColor: enabled ? (overlay.isUpdateAvailable() ? Theme.successBorder : overlay.accentColor) : Theme.borderSoft
                            border.width: 2
                            onClicked: overlay.handleUpdateButtonClick()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: updateSyncthingRow.implicitHeight + 32
                    radius: 12
                    color: Theme.listSurface
                    border.width: 1
                    border.color: overlay.isSyncthingUpdateAvailable() ? Theme.successBorder : Theme.borderSoft

                    Rectangle {
                        width: 12
                        radius: 6
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        color: overlay.isSyncthingUpdateAvailable() ? Theme.successBorder : Theme.peerAccent
                    }

                    RowLayout {
                        id: updateSyncthingRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 34
                        anchors.rightMargin: 20
                        spacing: 20

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Update Syncthing"
                                font.pointSize: overlay.fs(20)
                                font.bold: true
                                color: Theme.text
                            }

                            Text {
                                text: overlay.getSyncthingUpdateStatusText()
                                font.pointSize: overlay.fs(15)
                                color: (overlay.syncthingUpdateStatus && overlay.syncthingUpdateStatus.error) ? Theme.errorBorder : Theme.textMuted
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        AppButton {
                            text: overlay.getSyncthingUpdateButtonLabel()
                            fontScale: overlay.fontScale
                            fillColor: overlay.isSyncthingUpdateAvailable() ? Theme.successBorder : overlay.accentColor
                            pressedColor: overlay.isSyncthingUpdateAvailable() ? Theme.successPressed : Theme.accentPressed
                            disabledFillColor: Theme.mutedBg
                            disabledTextColor: Theme.textSubtle
                            enabled: !overlay.isSyncthingUpdateInProgress() && !overlay.isUpdateInProgress() && !overlay.isRestartPending()
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 60
                            outlineColor: enabled ? (overlay.isSyncthingUpdateAvailable() ? Theme.successBorder : overlay.accentColor) : Theme.borderSoft
                            border.width: 2
                            onClicked: overlay.handleSyncthingUpdateButtonClick()
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
