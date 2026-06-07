pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Item {
    id: installerPage

    property real fontScale: 1.0
    property var installerStatus: null
    property bool dismissable: true
    property bool isInstalling: installerStatus && installerStatus.in_progress

    signal installRequested()
    signal dismissRequested()

    anchors.fill: parent

    function fs(value) {
        return value * fontScale
    }

    function installerState() {
        const status = installerStatus || {}
        const binaryReady = !!status.binary_present
        const serviceReady = !!status.service_installed
        return { binaryReady: binaryReady, serviceReady: serviceReady }
    }

    function installerPrimaryText() {
        const state = installerState()
        if (!state.binaryReady && !state.serviceReady)
            return "Syncthing is not ready yet."
        if (state.binaryReady && !state.serviceReady)
            return "systemd service is missing."
        if (!state.binaryReady && state.serviceReady)
            return "Syncthing binary is missing."
        return "Syncthing is ready."
    }

    function installerSecondaryText() {
        const state = installerState()
        if (!state.binaryReady && !state.serviceReady)
            return "We can download the latest Syncthing release from GitHub and install a systemd service for you."
        if (state.binaryReady && !state.serviceReady)
            return "We detected the Syncthing binary on disk, but the systemd service was removed—perhaps by an OS update. Do you want to install the systemd service?"
        if (!state.binaryReady && state.serviceReady)
            return "The systemd service is still configured, but the Syncthing binary is missing — maybe due to an app update. Do you want to reinstall Syncthing?"
        return ""
    }

    function progressMessage() {
        return (installerStatus && installerStatus.progress_message) || ""
    }

    function errorMessage() {
        return (installerStatus && installerStatus.error) || ""
    }

    Rectangle {
        id: backgroundRect
        anchors.fill: parent
        anchors.margins: -32
        color: Theme.background
    }

    Rectangle {
        id: card
        property int cardPadding: 34
        width: Math.min(parent.width - 32, 1024)
        height: cardContent.implicitHeight + card.cardPadding * 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(16, (parent.height - height) / 2)
        radius: 16
        border.width: 1
        border.color: Theme.border
        color: Theme.surface

        Column {
            id: cardContent
            anchors.fill: parent
            anchors.margins: card.cardPadding
            spacing: 24

            RowLayout {
                id: heroRow
                width: parent.width
                spacing: 28
                visible: card.width >= 640

                Image {
                    id: heroIconWide
                    source: "qrc:/icon.png"
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 110
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    Layout.alignment: Qt.AlignTop
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Install Syncthing"
                        font.pointSize: installerPage.fs(36)
                        font.bold: true
                        wrapMode: Text.WordWrap
                        width: parent.width
                        color: Theme.text
                    }

                    Text {
                        text: "Syncthing and systemd service installer"
                        font.pointSize: installerPage.fs(18)
                        color: Theme.textMuted
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }

            Column {
                id: heroStack
                width: parent.width
                spacing: 16
                visible: !heroRow.visible

                Image {
                    source: "qrc:/icon.png"
                    width: 110
                    height: 110
                    anchors.horizontalCenter: parent.horizontalCenter
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    text: "Install Syncthing"
                    font.pointSize: installerPage.fs(36)
                    font.bold: true
                    wrapMode: Text.WordWrap
                    width: parent.width
                    color: Theme.text
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    text: "Download the latest Syncthing build and configure the background service in one tap."
                    font.pointSize: installerPage.fs(18)
                    color: Theme.textMuted
                    wrapMode: Text.WordWrap
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                width: parent.width
                height: statusContainer.height + 48
                radius: 12
                color: Theme.surfaceMuted
                border.color: Theme.borderSoft
                border.width: 1

                Column {
                    id: statusContainer
                    width: parent.width - 48
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 18

                    Text {
                        text: "Current status"
                        font.pointSize: installerPage.fs(20)
                        font.bold: true
                        color: Theme.text
                        width: parent.width
                    }

                    Column {
                        id: statusColumn
                        width: parent.width
                        spacing: 12

                        Rectangle {
                            id: binaryCard
                            width: parent.width
                            height: binaryContent.implicitHeight + 36
                            radius: 12
                            color: installerPage.installerState().binaryReady ? Theme.successBg : Theme.warningBg
                            border.color: installerPage.installerState().binaryReady ? Theme.successBorder : Theme.warningBorder
                            border.width: 1

                            Column {
                                id: binaryContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 18
                                spacing: 4

                                Text {
                                    text: installerPage.installerState().binaryReady ? "Binary ready" : "Binary missing"
                                    font.pointSize: installerPage.fs(18)
                                    font.bold: true
                                    color: Theme.text
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Text {
                                    text: installerPage.installerState().binaryReady ? "Syncthing executable found on the device." : "We will download the latest Syncthing binary."
                                    font.pointSize: installerPage.fs(16)
                                    color: Theme.textMuted
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                        }

                        Rectangle {
                            id: serviceCard
                            width: parent.width
                            height: serviceContent.implicitHeight + 36
                            radius: 12
                            color: installerPage.installerState().serviceReady ? Theme.successBg : Theme.errorBg
                            border.color: installerPage.installerState().serviceReady ? Theme.successBorder : Theme.errorBorder
                            border.width: 1

                            Column {
                                id: serviceContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 18
                                spacing: 4

                                Text {
                                    text: installerPage.installerState().serviceReady ? "Service configured" : "Service missing"
                                    font.pointSize: installerPage.fs(18)
                                    font.bold: true
                                    color: Theme.text
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Text {
                                    text: installerPage.installerState().serviceReady ? "systemd service is active." : "We will create and enable the Syncthing systemd service."
                                    font.pointSize: installerPage.fs(16)
                                    color: Theme.textMuted
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8

                Text {
                    text: installerPage.installerPrimaryText()
                    font.pointSize: installerPage.fs(20)
                    font.bold: true
                    wrapMode: Text.WordWrap
                    width: parent.width
                    color: Theme.text
                }

                Text {
                    text: installerPage.installerSecondaryText()
                    visible: installerPage.installerSecondaryText().length > 0
                    font.pointSize: installerPage.fs(18)
                    color: Theme.textMuted
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            Row {
                width: parent.width
                spacing: 20
                anchors.horizontalCenter: parent.horizontalCenter

                AppButton {
                    width: Math.max(220, Math.min(card.width * 0.45, 420))
                    height: 72
                    text: installerPage.isInstalling ? "Installing..." : "Install now"
                    fontScale: installerPage.fontScale
                    fillColor: Theme.accent
                    pressedColor: Theme.accentPressed
                    disabledFillColor: Theme.mutedBg
                    buttonRadius: 10
                    enabled: !installerPage.isInstalling
                    onClicked: installerPage.installRequested()
                }

                AppButton {
                    width: Math.max(220, Math.min(card.width * 0.45, 420))
                    height: 72
                    text: "Not now"
                    fontScale: installerPage.fontScale
                    fillColor: Theme.errorBorder
                    pressedColor: Theme.errorPressed
                    buttonRadius: 10
                    visible: installerPage.dismissable
                    onClicked: installerPage.dismissRequested()
                }
            }
        }
    }

    Rectangle {
        id: progressBox
        visible: installerPage.progressMessage().length > 0
        width: Math.min(parent.width - 32, 1024)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: card.bottom
        anchors.topMargin: 16
        radius: 12
        color: Theme.accentSoft
        border.color: Theme.borderSoft
        border.width: 1
        height: progressText.implicitHeight + 36

        Text {
            id: progressText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            text: installerPage.progressMessage()
            font.pointSize: installerPage.fs(16)
            color: Theme.text
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        visible: installerPage.errorMessage().length > 0
        width: Math.min(parent.width - 32, 1024)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: progressBox.visible ? progressBox.bottom : card.bottom
        anchors.topMargin: 16
        radius: 12
        color: Theme.errorBg
        border.color: Theme.errorBorder
        border.width: 1
        height: errorText.implicitHeight + 36

        Text {
            id: errorText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            text: installerPage.errorMessage()
            font.pointSize: installerPage.fs(16)
            color: Theme.text
            wrapMode: Text.WordWrap
        }
    }
}
