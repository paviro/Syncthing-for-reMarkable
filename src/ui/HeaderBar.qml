pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "Theme.js" as Theme

Rectangle {
    id: header

    property string title: "Syncthing"
    property string version: ""
    property real fontScale: 1.0
    property color accentColor: Theme.accent
    property color titleColor: Theme.text

    signal closeRequested()

    Layout.fillWidth: true
    radius: 14
    border.width: 1
    border.color: Theme.border
    color: Theme.headerSurface
    implicitHeight: contentRow.implicitHeight + 62

    function fs(value) {
        return value * fontScale
    }

    function displayVersion() {
        if (!version || version.length === 0)
            return ""
        return version.charAt(0).toLowerCase() === "v" ? version : `v${version}`
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.margins: 34
        spacing: 24

        Image {
            source: "qrc:/icon.png"
            Layout.preferredWidth: 112
            Layout.preferredHeight: 112
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: parent.width > 500
        }

        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Text {
                    text: header.title
                    font.pointSize: header.fs(30)
                    font.bold: true
                    color: Theme.text
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                Rectangle {
                    visible: header.displayVersion().length > 0
                    Layout.preferredWidth: versionText.implicitWidth + 24
                    Layout.preferredHeight: 38
                    Layout.alignment: Qt.AlignVCenter
                    Layout.topMargin: 6
                    radius: 10
                    color: Theme.mutedBg
                    border.width: 1
                    border.color: Theme.mutedBorder

                    Text {
                        id: versionText
                        anchors.centerIn: parent
                        text: header.displayVersion()
                        font.pointSize: header.fs(15)
                        font.bold: true
                        color: Theme.textMuted
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                text: "Monitor Syncthing service & folders"
                font.pointSize: header.fs(18)
                color: Theme.text
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            id: closeButton
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            radius: 12
            color: closeTap.pressed ? Theme.accentPressed : header.accentColor
            border.width: 1
            border.color: header.accentColor
            opacity: 1

            Text {
                anchors.centerIn: parent
                text: "\u00D7"
                font.pointSize: header.fs(38)
                font.bold: true
                color: Theme.onAccent
            }

            MouseArea {
                id: closeTap
                anchors.fill: parent
                onClicked: header.closeRequested()
            }
        }
    }
}
