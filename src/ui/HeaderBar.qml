pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: header

    property string title: "Syncthing"
    property real fontScale: 1.0
    property color accentColor: "#1887f0"
    property color titleColor: "#0a1a3d"

    signal closeRequested()

    Layout.fillWidth: true
    radius: 22
    border.width: 2
    border.color: "#4c5878"
    color: "#eef0f4"
    implicitHeight: contentRow.implicitHeight + 32

    function fs(value) {
        return value * fontScale
    }

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.margins: 20
        spacing: 18

        Image {
            source: "qrc:/icon.png"
            Layout.preferredWidth: 60
            Layout.preferredHeight: 60
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: parent.width > 500
        }

        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true

            Text {
                text: header.title
                font.pointSize: header.fs(32)
                font.bold: true
                color: header.titleColor
                wrapMode: Text.WordWrap
            }

            Text {
                text: "Monitor Syncthing service & folders"
                font.pointSize: header.fs(18)
                color: "#1d2844"
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            id: closeButton
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            radius: 32
            color: header.accentColor
            border.width: 0
            opacity: 1

            Text {
                anchors.centerIn: parent
                text: "\u00D7"
                font.pointSize: header.fs(38)
                font.bold: true
                color: "#ffffff"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: header.closeRequested()
            }
        }
    }
}
